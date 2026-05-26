#include "il2cpp_dump.h"
#include "UnityInline.h"
#include "Includes/obfuscate.h"
#include "Includes/Logger.h"

#include <string>
#include <fstream>
#include <sstream>
#include <cinttypes>
#include <cstring>
#include <cstdlib>
#include <vector>
#include <algorithm>
#include <unordered_map>

// ─── Structs không có trong UnityInline.h ───────────────────────────────────

struct Il2CppPropertyDefinition {
    uint32_t nameIndex;
    int32_t  getIndex;
    int32_t  setIndex;
    uint32_t token;
};

struct Il2CppParameterDefinition {
    uint32_t nameIndex;
    uint32_t token;
    int32_t  typeIndex;
};

// Runtime Il2CppType layout trong binary ARM64 (16 bytes)
struct Il2CppTypeRT {
    uint64_t data;      // data union – lower 32 bits = TypeDefIndex for CLASS/VALUETYPE
    uint32_t attrs;
    uint8_t  type_enum;
    uint8_t  byref;
    uint8_t  pinned;
    uint8_t  _pad;
};

enum Il2CppTypeEnum : uint8_t {
    TYPE_END        = 0x00,
    TYPE_VOID       = 0x01,
    TYPE_BOOLEAN    = 0x02,
    TYPE_CHAR       = 0x03,
    TYPE_I1         = 0x04,
    TYPE_U1         = 0x05,
    TYPE_I2         = 0x06,
    TYPE_U2         = 0x07,
    TYPE_I4         = 0x08,
    TYPE_U4         = 0x09,
    TYPE_I8         = 0x0a,
    TYPE_U8         = 0x0b,
    TYPE_R4         = 0x0c,
    TYPE_R8         = 0x0d,
    TYPE_STRING     = 0x0e,
    TYPE_PTR        = 0x0f,
    TYPE_BYREF      = 0x10,
    TYPE_VALUETYPE  = 0x11,
    TYPE_CLASS      = 0x12,
    TYPE_VAR        = 0x13,
    TYPE_ARRAY      = 0x14,
    TYPE_GENERICINST= 0x15,
    TYPE_TYPEDBYREF = 0x16,
    TYPE_I          = 0x18,
    TYPE_U          = 0x19,
    TYPE_FNPTR      = 0x1b,
    TYPE_OBJECT     = 0x1c,
    TYPE_SZARRAY    = 0x1d,
    TYPE_MVAR       = 0x1e,
};

// Method attribute flags
#define METHOD_ATTR_STATIC   0x0010
#define METHOD_ATTR_VIRTUAL  0x0040
#define METHOD_ATTR_ABSTRACT 0x0400

// ─── Globals dùng trong quá trình dump ──────────────────────────────────────

static std::unordered_map<int32_t, std::string> g_typeCache;
static std::unordered_map<int32_t, int>          g_byvalToTypeDef; // byvalTypeIndex → typeDefIndex

// Progress – expose qua header
volatile int  g_dump_cur     = 0;
volatile int  g_dump_total   = 0;
volatile int  g_dump_methods = 0;
volatile int  g_dump_fields  = 0;
char          g_dump_class[256] = {};

// ─── Helpers ────────────────────────────────────────────────────────────────

static std::string GetPackageNamez() {
    std::ifstream cmdline("/proc/self/cmdline");
    std::string pkg;
    if (cmdline.good()) {
        std::getline(cmdline, pkg, '\0');
        size_t pos = pkg.find_first_of(":\0");
        if (pos != std::string::npos) pkg.resize(pos);
    }
    return pkg.empty() ? "com.unknown.game" : pkg;
}

// Đọc Il2CppTypeRT từ binary theo typeIndex trong metaReg.types[]
static const Il2CppTypeRT* ReadRTType(const Unity::unity_cache_t* cache,
                                       const Unity::Il2CppMetadataRegistration* metaReg,
                                       int32_t typeIndex) {
    if (!metaReg || typeIndex < 0 || typeIndex >= (int32_t)metaReg->typesCount) return nullptr;

    uint64_t arrOff = 0;
    if (!Unity::va_to_off_any(&cache->data_secs, &cache->exec_secs, metaReg->types, &arrOff)) return nullptr;

    uint64_t need = (uint64_t)(typeIndex + 1) * sizeof(uint64_t);
    if (arrOff + need > cache->unity.size) return nullptr;

    uint64_t typeVA = *(const uint64_t*)(cache->unity.data + arrOff + (uint64_t)typeIndex * sizeof(uint64_t));
    if (typeVA == 0) return nullptr;

    uint64_t typeOff = 0;
    if (!Unity::va_to_off_any(&cache->data_secs, &cache->exec_secs, typeVA, &typeOff)) return nullptr;
    if (typeOff + sizeof(Il2CppTypeRT) > cache->unity.size) return nullptr;

    return (const Il2CppTypeRT*)(cache->unity.data + typeOff);
}

// Lấy tên type từ runtime Il2CppTypeRT
static std::string TypeRTToName(const Unity::unity_cache_t* cache,
                                 const Unity::Il2CppMetadataRegistration* metaReg,
                                 const Unity::Il2CppTypeDefinition* typeDefs,
                                 int typeTotal,
                                 const Il2CppTypeRT* rt,
                                 int depth);

static std::string GetTypeName(const Unity::unity_cache_t* cache,
                                const Unity::Il2CppMetadataRegistration* metaReg,
                                const Unity::Il2CppTypeDefinition* typeDefs,
                                int typeTotal,
                                int32_t typeIndex,
                                int depth = 0);

static std::string TypeRTToName(const Unity::unity_cache_t* cache,
                                 const Unity::Il2CppMetadataRegistration* metaReg,
                                 const Unity::Il2CppTypeDefinition* typeDefs,
                                 int typeTotal,
                                 const Il2CppTypeRT* rt,
                                 int depth) {
    if (!rt || depth > 3) return "object";

    switch ((Il2CppTypeEnum)rt->type_enum) {
        case TYPE_VOID:        return "void";
        case TYPE_BOOLEAN:     return "bool";
        case TYPE_CHAR:        return "char";
        case TYPE_I1:          return "sbyte";
        case TYPE_U1:          return "byte";
        case TYPE_I2:          return "short";
        case TYPE_U2:          return "ushort";
        case TYPE_I4:          return "int";
        case TYPE_U4:          return "uint";
        case TYPE_I8:          return "long";
        case TYPE_U8:          return "ulong";
        case TYPE_R4:          return "float";
        case TYPE_R8:          return "double";
        case TYPE_STRING:      return "string";
        case TYPE_I:           return "IntPtr";
        case TYPE_U:           return "UIntPtr";
        case TYPE_OBJECT:      return "object";
        case TYPE_TYPEDBYREF:  return "TypedReference";
        case TYPE_VAR:         return "T";
        case TYPE_MVAR:        return "T";

        case TYPE_VALUETYPE:
        case TYPE_CLASS: {
            // lower 32 bits của data = TypeDefinitionIndex
            int32_t defIdx = (int32_t)(rt->data & 0xFFFFFFFFu);
            if (defIdx >= 0 && defIdx < typeTotal) {
                const char* nm = Unity::metadata_string(&cache->meta, cache->hdr, typeDefs[defIdx].nameIndex);
                if (nm && nm[0] != '\0') {
                    // friendly rename cho System primitives
                    const char* ns = Unity::metadata_string(&cache->meta, cache->hdr, typeDefs[defIdx].namespaceIndex);
                    if (ns && strcmp(ns, "System") == 0) {
                        if (!strcmp(nm, "String"))  return "string";
                        if (!strcmp(nm, "Object"))  return "object";
                        if (!strcmp(nm, "Boolean")) return "bool";
                        if (!strcmp(nm, "Byte"))    return "byte";
                        if (!strcmp(nm, "SByte"))   return "sbyte";
                        if (!strcmp(nm, "Int16"))   return "short";
                        if (!strcmp(nm, "UInt16"))  return "ushort";
                        if (!strcmp(nm, "Int32"))   return "int";
                        if (!strcmp(nm, "UInt32"))  return "uint";
                        if (!strcmp(nm, "Int64"))   return "long";
                        if (!strcmp(nm, "UInt64"))  return "ulong";
                        if (!strcmp(nm, "Single"))  return "float";
                        if (!strcmp(nm, "Double"))  return "double";
                        if (!strcmp(nm, "Char"))    return "char";
                        if (!strcmp(nm, "IntPtr"))  return "IntPtr";
                        if (!strcmp(nm, "UIntPtr")) return "UIntPtr";
                        if (!strcmp(nm, "Void"))    return "void";
                    }
                    return std::string(nm);
                }
            }
            // fallback: dùng byvalToTypeDef map
            auto it = g_byvalToTypeDef.find((int32_t)(rt->data & 0xFFFFFFFFu));
            if (it != g_byvalToTypeDef.end()) {
                const char* nm = Unity::metadata_string(&cache->meta, cache->hdr, typeDefs[it->second].nameIndex);
                if (nm) return std::string(nm);
            }
            return "object";
        }

        case TYPE_SZARRAY: {
            if (rt->data == 0) return "object[]";
            const Il2CppTypeRT* elem = ReadRTType(cache, metaReg, (int32_t)(rt->data & 0xFFFFFFFFu));
            if (!elem) {
                // data là VA trỏ đến Il2CppType element
                uint64_t elemOff = 0;
                if (!Unity::va_to_off_any(&cache->data_secs, &cache->exec_secs, rt->data, &elemOff)) return "object[]";
                if (elemOff + sizeof(Il2CppTypeRT) > cache->unity.size) return "object[]";
                elem = (const Il2CppTypeRT*)(cache->unity.data + elemOff);
            }
            return TypeRTToName(cache, metaReg, typeDefs, typeTotal, elem, depth + 1) + "[]";
        }

        case TYPE_PTR: {
            if (rt->data == 0) return "void*";
            uint64_t innerOff = 0;
            if (!Unity::va_to_off_any(&cache->data_secs, &cache->exec_secs, rt->data, &innerOff)) return "void*";
            if (innerOff + sizeof(Il2CppTypeRT) > cache->unity.size) return "void*";
            const Il2CppTypeRT* inner = (const Il2CppTypeRT*)(cache->unity.data + innerOff);
            return TypeRTToName(cache, metaReg, typeDefs, typeTotal, inner, depth + 1) + "*";
        }

        case TYPE_GENERICINST: return "object"; // quá phức tạp để resolve

        default: return "object";
    }
}

static std::string GetTypeName(const Unity::unity_cache_t* cache,
                                const Unity::Il2CppMetadataRegistration* metaReg,
                                const Unity::Il2CppTypeDefinition* typeDefs,
                                int typeTotal,
                                int32_t typeIndex,
                                int depth) {
    if (typeIndex < 0) return "void";

    auto it = g_typeCache.find(typeIndex);
    if (it != g_typeCache.end()) return it->second;

    // Thử byvalToTypeDef trước (không cần đọc binary)
    auto byvalIt = g_byvalToTypeDef.find(typeIndex);
    if (byvalIt != g_byvalToTypeDef.end()) {
        int defIdx = byvalIt->second;
        const char* nm = Unity::metadata_string(&cache->meta, cache->hdr, typeDefs[defIdx].nameIndex);
        if (nm && nm[0] != '\0') {
            const char* ns = Unity::metadata_string(&cache->meta, cache->hdr, typeDefs[defIdx].namespaceIndex);
            std::string result;
            if (ns && strcmp(ns, "System") == 0) {
                if (!strcmp(nm, "String"))  result = "string";
                else if (!strcmp(nm, "Object"))  result = "object";
                else if (!strcmp(nm, "Boolean")) result = "bool";
                else if (!strcmp(nm, "Byte"))    result = "byte";
                else if (!strcmp(nm, "SByte"))   result = "sbyte";
                else if (!strcmp(nm, "Int16"))   result = "short";
                else if (!strcmp(nm, "UInt16"))  result = "ushort";
                else if (!strcmp(nm, "Int32"))   result = "int";
                else if (!strcmp(nm, "UInt32"))  result = "uint";
                else if (!strcmp(nm, "Int64"))   result = "long";
                else if (!strcmp(nm, "UInt64"))  result = "ulong";
                else if (!strcmp(nm, "Single"))  result = "float";
                else if (!strcmp(nm, "Double"))  result = "double";
                else if (!strcmp(nm, "Char"))    result = "char";
                else if (!strcmp(nm, "IntPtr"))  result = "IntPtr";
                else if (!strcmp(nm, "UIntPtr")) result = "UIntPtr";
                else if (!strcmp(nm, "Void"))    result = "void";
                else result = std::string(nm);
            } else {
                result = std::string(nm);
            }
            g_typeCache[typeIndex] = result;
            return result;
        }
    }

    // Fallback: đọc Il2CppType từ binary
    if (metaReg) {
        const Il2CppTypeRT* rt = ReadRTType(cache, metaReg, typeIndex);
        if (rt) {
            std::string result = TypeRTToName(cache, metaReg, typeDefs, typeTotal, rt, depth);
            if (rt->byref && result.back() != '&') result += "&";
            g_typeCache[typeIndex] = result;
            return result;
        }
    }

    g_typeCache[typeIndex] = "object";
    return "object";
}

// ─── Entry point ─────────────────────────────────────────────────────────────

void il2cpp_dump(void *handle)
{
    (void)handle;
    g_typeCache.clear();
    g_byvalToTypeDef.clear();
    g_dump_cur = 0; g_dump_total = 0;
    g_dump_methods = 0; g_dump_fields = 0;
    g_dump_class[0] = '\0';

    LOGI("=== BẮT ĐẦU DUMP IL2CPP ===");

    Unity::unity_cache_t *cache = Unity::get_cached_unity();
    if (!cache || !cache->hdr) {
        LOGE("Cache hoặc header metadata không hợp lệ!");
        return;
    }

    const uint32_t *hdr = cache->hdr;
    std::string packageName = GetPackageNamez();

    std::string dumpPath;
#if defined(__aarch64__)
    dumpPath = "/storage/emulated/0/Android/data/" + packageName + "/" + packageName + " [ARM64].cs";
#else
    dumpPath = "/storage/emulated/0/Android/data/" + packageName + "/" + packageName + " [ARM32].cs";
#endif

    LOGI("Đang ghi file: %s", dumpPath.c_str());
    std::ofstream out(dumpPath);
    if (!out.is_open()) {
        LOGE("Không thể tạo file dump!");
        return;
    }

    // ─── Đọc các bảng metadata ───────────────────────────────────────────────
    uint32_t imagesOff   = hdr[42], imagesSize   = hdr[43];
    uint32_t typesOff    = hdr[40], typesSize     = hdr[41];
    uint32_t methodsOff  = hdr[12], methodsSize   = hdr[13];
    uint32_t fieldsOff   = hdr[24], fieldsSize    = hdr[25];
    uint32_t paramsOff   = hdr[22], paramsSize    = hdr[23];

    // Properties: thử index 28/29 trước, fallback 26/27
    uint32_t propsOff = 0, propsSize = 0;
    if (hdr[28] && hdr[29]) { propsOff = hdr[28]; propsSize = hdr[29]; }
    else if (hdr[26] && hdr[27]) { propsOff = hdr[26]; propsSize = hdr[27]; }

    const Unity::Il2CppImageDefinition*  images  = (const Unity::Il2CppImageDefinition* )(cache->meta.data + imagesOff);
    const Unity::Il2CppTypeDefinition*   types   = (const Unity::Il2CppTypeDefinition*  )(cache->meta.data + typesOff);
    const Unity::Il2CppMethodDefinition* methods = (const Unity::Il2CppMethodDefinition*)(cache->meta.data + methodsOff);
    const Unity::Il2CppFieldDefinition*  fields  = (const Unity::Il2CppFieldDefinition* )(cache->meta.data + fieldsOff);
    const Il2CppParameterDefinition*     params  = (const Il2CppParameterDefinition*    )(cache->meta.data + paramsOff);
    const Il2CppPropertyDefinition*      props   = propsOff ? (const Il2CppPropertyDefinition*)(cache->meta.data + propsOff) : nullptr;

    int imageCount  = (int)(imagesSize  / sizeof(Unity::Il2CppImageDefinition));
    int typeTotal   = (int)(typesSize   / sizeof(Unity::Il2CppTypeDefinition));
    int methodTotal = (int)(methodsSize / sizeof(Unity::Il2CppMethodDefinition));
    int fieldTotal  = (int)(fieldsSize  / sizeof(Unity::Il2CppFieldDefinition));
    int paramTotal  = (int)(paramsSize  / sizeof(Il2CppParameterDefinition));
    int propTotal   = propsSize ? (int)(propsSize / sizeof(Il2CppPropertyDefinition)) : 0;

    // ─── Lấy Il2CppMetadataRegistration ─────────────────────────────────────
    const Unity::Il2CppMetadataRegistration* metaReg = nullptr;
    {
        uint64_t regOff = 0;
        if (Unity::va_to_off_any(&cache->data_secs, &cache->exec_secs, cache->meta_reg_va, &regOff) &&
            regOff + sizeof(Unity::Il2CppMetadataRegistration) <= cache->unity.size) {
            metaReg = (const Unity::Il2CppMetadataRegistration*)(cache->unity.data + regOff);
        }
    }

    // ─── Xây bảng byvalTypeIndex → typeDefIndex ──────────────────────────────
    // Dùng để tra tên type mà không cần đọc binary runtime
    for (int t = 0; t < typeTotal; ++t) {
        int32_t bvIdx = types[t].byvalTypeIndex;
        if (bvIdx >= 0) {
            g_byvalToTypeDef.emplace(bvIdx, t);
        }
    }

    // ─── Header file ─────────────────────────────────────────────────────────
    out << "// ==================== IL2CPP DUMP ====================\n";
    out << "// Generated: " << __DATE__ << " " << __TIME__ << "\n";
    out << "// Package: " << packageName << "\n";
    out << "// ======================================================\n\n";

    for (int i = 0; i < imageCount; i++) {
        const char* img = Unity::metadata_string(&cache->meta, hdr, images[i].nameIndex);
        out << "// Image " << i << ": " << (img ? img : "?")
            << " (TypeStart: " << images[i].typeStart
            << ", Count: " << images[i].typeCount << ")\n";
    }
    out << "\n";

    // ─── Tính tổng type để hiển thị tiến độ ────────────────────────────────
    {
        int total = 0;
        for (int i = 0; i < imageCount; ++i) total += (int)images[i].typeCount;
        g_dump_total = total;
        g_dump_cur   = 0;
    }

    // ─── Vòng lặp chính: từng image → từng type ──────────────────────────────
    for (int i = 0; i < imageCount; ++i) {
        const char* imgName = Unity::metadata_string(&cache->meta, hdr, images[i].nameIndex);
        if (!imgName || imgName[0] == '\0') continue;

        int tStart = images[i].typeStart;
        int tCount = images[i].typeCount;

        for (int t = tStart; t < tStart + tCount && t < typeTotal; ++t) {
            const char* ns       = Unity::metadata_string(&cache->meta, hdr, types[t].namespaceIndex);
            const char* typeName = Unity::metadata_string(&cache->meta, hdr, types[t].nameIndex);
            if (!typeName) continue;

            bool isValueType = (types[t].bitfield & 0x1) != 0;

            // Cập nhật tiến độ
            g_dump_cur++;
            strncpy(g_dump_class, typeName, sizeof(g_dump_class) - 1);
            g_dump_class[sizeof(g_dump_class) - 1] = '\0';

            // Namespace + class header
            out << "\n// Namespace: " << (ns && ns[0] ? ns : "<global>") << "\n";
            out << "public class " << typeName;

            int parentIdx = types[t].parentIndex;
            if (parentIdx >= 0 && parentIdx < typeTotal) {
                const char* pName = Unity::metadata_string(&cache->meta, hdr, types[parentIdx].nameIndex);
                if (pName && pName[0]) out << " : " << pName;
            }
            out << " // TypeDefIndex: " << t << "\n{\n";

            // ── Fields ───────────────────────────────────────────────────────
            int fStart = types[t].fieldStart;
            int fCount = types[t].field_count;
            if (fCount > 0) {
                out << "    // Fields\n";
                for (int f = fStart; f < fStart + fCount && f < fieldTotal; ++f) {
                    const char* fName = Unity::metadata_string(&cache->meta, hdr, fields[f].nameIndex);
                    if (!fName) continue;

                    int fieldIdxInType = f - fStart;
                    int rawOffset = 0;
                    bool hasOff = Unity::get_field_off(
                        &cache->unity, &cache->data_secs, &cache->exec_secs,
                        cache->meta_reg_va, t, fieldIdxInType, isValueType, &rawOffset);

                    std::string fType = GetTypeName(cache, metaReg, types, typeTotal, fields[f].typeIndex);

                    if (!hasOff || rawOffset <= 0) {
                        out << "    public static " << fType << " " << fName << ";\n";
                    } else {
                        out << "    public " << fType << " " << fName
                            << "; // 0x" << std::hex << rawOffset << std::dec << "\n";
                    }
                    g_dump_fields++;
                }
                out << "\n";
            }

            // ── Properties ───────────────────────────────────────────────────
            int pStart = types[t].propertyStart;
            int pCount = types[t].property_count;
            if (props && pCount > 0) {
                out << "    // Properties\n";
                for (int p = pStart; p < pStart + pCount && p < propTotal; ++p) {
                    const char* pName = Unity::metadata_string(&cache->meta, hdr, props[p].nameIndex);
                    if (!pName) continue;
                    std::string get = (props[p].getIndex >= 0) ? "get; " : "";
                    std::string set = (props[p].setIndex >= 0) ? "set; " : "";
                    out << "    public object " << pName << " { " << get << set << "}\n";
                }
                out << "\n";
            }

            // ── Methods ──────────────────────────────────────────────────────
            int mStart = types[t].methodStart;
            int mCount = types[t].method_count;
            if (mCount > 0) {
                out << "    // Methods\n";
                for (int m = mStart; m < mStart + mCount && m < methodTotal; ++m) {
                    const char* mName = Unity::metadata_string(&cache->meta, hdr, methods[m].nameIndex);
                    if (!mName) continue;

                    uint16_t mFlags  = methods[m].flags;
                    uint16_t slot    = methods[m].slot;
                    int      pcnt    = methods[m].parameterCount;
                    int      pstart  = methods[m].parameterStart;
                    int32_t  retType = methods[m].returnType;

                    // RVA / Offset
                    uint64_t rva = Unity::FindMethodOffset(imgName, ns, typeName, mName, pcnt);
                    if (rva) {
                        out << "    // RVA: 0x" << std::hex << rva
                            << " Offset: 0x" << rva
                            << " VA: 0x" << (cache->image_base + rva) << std::dec;
                    } else {
                        out << "    // RVA: -1 Offset: -1";
                    }
                    if (slot != 0xFFFF) out << " Slot: " << slot;
                    out << "\n";

                    // Signature
                    out << "    public ";
                    if (mFlags & METHOD_ATTR_STATIC)   out << "static ";
                    if (mFlags & METHOD_ATTR_ABSTRACT)  out << "abstract ";
                    else if (!(mFlags & METHOD_ATTR_STATIC) && slot != 0xFFFF) out << "override ";

                    std::string retName = GetTypeName(cache, metaReg, types, typeTotal, retType);
                    out << retName << " " << mName << "(";

                    for (int pi = 0; pi < pcnt; ++pi) {
                        if (pi > 0) out << ", ";
                        int pidx = pstart + pi;
                        if (pidx >= 0 && pidx < paramTotal) {
                            std::string pTypeName = GetTypeName(cache, metaReg, types, typeTotal, params[pidx].typeIndex);
                            const char* paramName = Unity::metadata_string(&cache->meta, hdr, params[pidx].nameIndex);
                            out << pTypeName << " " << (paramName ? paramName : ("p" + std::to_string(pi)).c_str());
                        } else {
                            out << "object p" << pi;
                        }
                    }
                    out << ") { }\n\n";
                    g_dump_methods++;
                }
            }

            out << "}\n";
        }
    }

    out.close();
    LOGI("=== DUMP IL2CPP HOÀN TẤT: %s ===", dumpPath.c_str());
}
