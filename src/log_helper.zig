
const zig_sb_sv = @import("zig_sb_sv");
const std = @import("std");
const token_helper = @import("token_helper");
const StringView = zig_sb_sv.View(u8);
var alloca = std.heap.DebugAllocator(.{}){};
const StringBuilder = zig_sb_sv.Builder(u8, alloca.allocator());


pub const Log = struct {
    pub const info = std.log.info;
    pub const warn = std.log.warn;
    pub const err  = std.log.err;
    pub const debug  = std.log.debug;
    log_builder:StringBuilder,
    out : *std.Io.Writer,

    const Self = @This();
    pub const empty: Self = .{.log_builder=.empty, .out=undefined};
    pub fn from(out : *std.Io.Writer) Self {
        return .{.log_builder=.empty, .out=out};
    }
    pub fn add(self:*Self, sv_:StringView) void {
        self.log_builder.push_sv(sv_);
    }
    pub fn push(self:*Self, str:[]const u8) void {
        self.log_builder.push(str);
    }
    pub fn push_fmt(self:*Self, comptime fmt:[]const u8, args:anytype) void {
        self.log_builder.push_fmt(fmt, args);
    }
    pub fn flush(self:*Self) void {
        self.printf("{s}", .{self.log_builder.items()});
        self.log_builder.empty_out();
    }
    pub fn dbg(arg:anytype) void {
        Self.debug("{any} <{}>", .{arg, @TypeOf(arg)});
    }
    pub fn dbgs(arg:anytype) void {
        Self.debug("{s} <{}>", .{arg, @TypeOf(arg)});
    }
    pub fn sv(sv_ : StringView) void {
        Self.debug("{s}  <start: {d} count: {d} len: {d}>", .{sv_.items(), sv_.start, sv_.count, sv_.source.len});
    }
    pub fn sb(sb_ : StringBuilder) void {
        const sv_ = sb_.view;
        Self.debug("{s}  <start: {d} count: {d} len: {d}>", .{sv_.items(), sv_.start, sv_.count, sv_.source.len});
    }




     pub fn printf(self:Self,comptime fmt:[]const u8, args:anytype) void {
          self.out.print(fmt, args)catch{};
          self.out.flush()catch{};
     }
     pub fn printlnf(self:Self, comptime fmt:[]const u8, args:anytype) void {
          self.out.print(fmt, args)catch{};
          self.out.print("\n", .{})catch{};
          self.out.flush()catch{};
     }
     pub fn go_to(self:Self,file:[]const u8, src:StringView, token:token_helper.Token) void {
         const line = token.position_to_line(src);
         const row = token.position_to_row(src);
         self.printf("{s}:{d}:{d}: [{s}]<{s}> {d},{d}\n", .{file,line , row, token.content.items(),token.ttype.items(), line, row});
     }
     pub fn tree(self:Self, tr:token_helper.Tree,  pad:usize) void {
         var tmp_sb:StringBuilder = .empty;
         for (0..pad) |_| {
             tmp_sb.push(" ");
         }
         self.printf("result: {s}\n", .{tr.token.content.items()});
         for ( tr.func.items() ) |funcs| {
           self.printf("fn",.{});
           self.tree(funcs, pad+2);
         }

     }



};
