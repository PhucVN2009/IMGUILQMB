#pragma once

#ifdef __cplusplus
extern "C" {
#endif

void il2cpp_dump(void *handle);

// Tiến độ dump – cập nhật từ thread dump, đọc từ UI thread
extern volatile int  g_dump_cur;        // type hiện tại
extern volatile int  g_dump_total;      // tổng số type
extern volatile int  g_dump_methods;    // tổng method đã ghi
extern volatile int  g_dump_fields;     // tổng field đã ghi
extern char          g_dump_class[256]; // tên class đang xử lý

#ifdef __cplusplus
}
#endif
