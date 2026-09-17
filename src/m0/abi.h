#ifndef KAY_M0_ABI_H
#define KAY_M0_ABI_H

#include <stddef.h>
#include <stdint.h>

struct kay_packet {
    uint64_t tag;
    uint64_t value;
};

_Static_assert(sizeof(struct kay_packet) == 16, "kay_packet size");
_Static_assert(_Alignof(struct kay_packet) == 8, "kay_packet alignment");
_Static_assert(offsetof(struct kay_packet, tag) == 0, "kay_packet.tag offset");
_Static_assert(offsetof(struct kay_packet, value) == 8, "kay_packet.value offset");

uint64_t kay_zig_callback(const struct kay_packet *packet);
uint64_t kay_c_accumulate(const struct kay_packet *packets, size_t count);

#endif
