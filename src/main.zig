const std = @import("std");
const Io = std.Io;

const zig_sb_sv = @import("zig_sb_sv");
const token_helper = @import("token_helper");
const log_helper = @import("log_helper");
const Log = log_helper.Log;


const StringView = zig_sb_sv.View(u8);
var alloca = std.heap.DebugAllocator(.{}){};
const StringBuilder = zig_sb_sv.Builder(u8, alloca.allocator());


pub fn main(init: std.process.Init) !void {
    const arena: std.mem.Allocator = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);
    if (args.len < 3) {
      //  Log.debug("usage: {s} <input file> <output file>", .{args[0]});
        return;
    }
    //for (args) |arg| {
    //    Log.debug("{s}", .{arg});
    //}

    const io = init.io;
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    var log:Log = .from(&stdout_file_writer.interface);
    var sb: StringBuilder = .empty;
    sb.push_file(args[1], io);
    sb.push_elem('\n');

    const source: StringView = .from(sb.items());
    var tb = token_helper.Token.tokenize(source);

    token_helper.filter_out_by_ttype(&tb, &.{"whitespace", "comment"});
    var i:usize = 0;
    for (tb.items()) |token| {
        i +=1;
        //Log.dbg(token);
        if (token.ttype.view.is_equal( .from("UNKNOWN") )) {
          log.go_to(args[1], source,token);
          return;
        }
        //log.push(" ");
        //log.add(token.content);
    }
    const tree = token_helper.nooo_i_dont_want_to_be_a_tree(tb.view);
    const tree_evaled = tree.eval();

    log.tree(tree_evaled,  0);
    //Log.dbg(tree_evaled);
    log.flush();

}

