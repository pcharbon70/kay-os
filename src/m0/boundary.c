#include "abi.h"

uint64_t kay_c_accumulate(const struct kay_packet *packets, size_t count)
{
    uint64_t result = 0;

    for (size_t index = 0; index < count; ++index) {
        result += kay_zig_callback(&packets[index]);
    }

    return result;
}
