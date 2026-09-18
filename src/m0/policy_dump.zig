const std = @import("std");
const contracts = @import("contracts.zig");

pub fn main() void {
    const operations = [_]contracts.Operation{ .console_read, .console_write, .clock_now, .clock_wait_until };
    for (operations) |operation| {
        const contract = contracts.operationContract(operation);
        std.debug.print(
            "operation\t{s}\t{d}\t{s}\t{s}\t{s}\t{s}\t{d}\n",
            .{
                @tagName(contract.operation),
                contract.endpoint,
                @tagName(contract.required_grant),
                @tagName(contract.payer),
                @tagName(contract.owner),
                @tagName(contract.response),
                contract.maximum_transfer,
            },
        );
    }
    const results = [_]contracts.ResultCode{ .ok, .denied, .invalid_endpoint, .invalid_length, .deadline_in_past };
    for (results) |result| std.debug.print("result\t{s}\t{d}\n", .{ @tagName(result), @intFromEnum(result) });
}
