pub const protocol_base_revision: u64 = 6;
pub const request_start_values = [4]u64{
    0xf6b8f4b39de7d1ae,
    0xfab91a6940fcb9cf,
    0x785c6ed015d3e316,
    0x181e920a7852b9d9,
};
pub const base_revision_values = [3]u64{
    0xf9562b2d5c95a6c8,
    0x6a7b384944536bdc,
    protocol_base_revision,
};
pub const request_end_values = [2]u64{ 0xadc0e0531bb10d03, 0x9572709f31764c62 };

// These values and section names are the Limine protocol's discovery ABI.
// Export plus linker KEEP prevents dead-code removal from deleting the tags.
pub export var kay_limine_requests_start: [4]u64 linksection(".limine_requests_start") = request_start_values;

pub export var kay_limine_base_revision: [3]u64 linksection(".limine_requests") = base_revision_values;

pub export var kay_limine_requests_end: [2]u64 linksection(".limine_requests_end") = request_end_values;
