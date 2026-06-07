//! By convention, root.zig is the root source file when making a package.
const std = @import("std");
const Io = std.Io;

pub fn View(T:type) type {

return struct {
    const Self = @This();
    source:[]const T,
    start:usize,
    count:usize,

    // factories
    pub fn from_slice(src_slice : []const T) Self {
        return .{.source=src_slice, .start=0, .count=src_slice.len};
    }
    pub fn from_view(other:Self) Self {
        return .{.source=other.source, .start=other.start, .count=other.count};
    }
    pub fn from(src_slice : []const T) Self {
        return Self.from_slice(src_slice);
    }

    // IDK how to summarise this part. But its conviniency i guess?
    pub const empty : Self = .from(&[_]T{});
    pub fn clone(self:Self) Self {
        return Self.from_view(self);
    }
    pub fn copy(self:*Self, other:Self) void {
        self.source = other.source;
        self.start = other.start;
        self.count = other.count;
    }
    pub fn copy_from_end(self:Self, count:usize) Self {
        return .from(self.slice_from_end(count));
    }
    pub fn copy_from_start(self:Self, count:usize) Self {
        return .from(self.slice_from_start(count));
    }

    // slicing
    pub fn safe_slice_source(self:Self, start:usize, count:usize) error{OutOfBounds}![]const T {
        //std.log.debug("[{d} {d}] ={d}=",.{ start, count, self.source.len});
        //
        if (start+count > self.source.len) {
            return error.OutOfBounds;
        }
        return self.source[start..start+count];
    }
    pub fn slice_source(self:Self, start:usize, count:usize) []const T {
        return self.safe_slice(start, count)catch{return Self.empty.source;};
    }
    pub fn safe_slice(self:Self, start:usize, count:usize) error{OutOfBounds}![]const T {
        return try self.safe_slice_source(self.start+start, count-start);
    }
    pub fn slice(self:Self, start:usize, count:usize) []const T {
        return self.safe_slice(start, count)catch{std.debug.print("FAILED",.{});return Self.empty.source;};
    }
    pub fn slice_sv(self:Self, start:usize, count:usize) Self {
        return .from(self.slice(start, count));
    }
    pub fn safe_items(self:Self) error{OutOfBounds}![]const T {
        return try self.safe_slice_source(self.start, self.count);
    }
    pub fn items(self:Self) []const T {
        return self.safe_items()catch{return Self.empty.source;};
    }
    pub fn slice_from_end(self:Self, count:usize) []const T {
        return self.slice(self.count - count, count);
    }
    pub fn slice_from_start(self:Self, count:usize) []const T {
        return self.slice(0, count);
    }
    // indexing
    pub fn safe_at(self:Self, at_index:usize) error{OutOfBounds}!T {
        if (self.start + at_index >= self.source.len) {
            return error.OutOfBounds;
        }
        return self.source[self.start + at_index];
    }
    pub fn at(self:Self, at_index:usize) T {
        return self.safe_at(at_index)catch{return undefined;};
    }
    pub fn first(self:Self) T {
        return self.safe_at(0)catch{return undefined;};
    }
    pub fn last(self:Self) T {
        return self.safe_at(self.count-1)catch{return 0;};
    }

    // setters
    pub fn set_count(self:*Self, new_count : usize) error{OutOfBounds}!void {
        if (self.start + new_count > self.source.len) {
            return error.OutOfBounds;
        }
        self.count = new_count;
    }
    pub fn set_start(self:*Self, new_start : usize) error{OutOfBounds}!void {
        if (new_start + self.count > self.source.len) {
            return error.OutOfBounds;
        }
        self.start = new_start;
    }

    // bumping
    pub fn safe_bumped_start(self:Self, bump_by : usize) error{OutOfBounds}!Self {
        if (self.count < bump_by) {
            return error.OutOfBounds;
        }
        var new_self = self.clone();
        new_self.start += bump_by;
        new_self.count -= bump_by;
        std.debug.assert(new_self.start+new_self.count <= new_self.source.len);
        return new_self;
    }
    pub fn bumped_start(self:Self, bump_by : usize) Self {
        return self.safe_bumped_start(bump_by)catch{return .empty;};
    }
    pub fn safe_bump_start(self:*Self, bump_by : usize) error{OutOfBounds}!void {
        self.copy(try self.safe_bumped_start(bump_by) );
    }
    pub fn bump_start(self:*Self, bump_by : usize) void {
        self.safe_bump_start(bump_by)catch{};
    }
    pub fn safe_bumped_end(self:Self, bump_by : usize) error{OutOfBounds}!Self {
        if (self.count < bump_by) {
            return error.OutOfBounds;
        }
        var new_self = self.clone();
        new_self.count -= bump_by;
        std.debug.assert(new_self.start+new_self.count <= new_self.source.len);
        return new_self;
    }
    pub fn bumped_end(self:Self, bump_by : usize) Self {
        return self.safe_bumped_end(bump_by)catch{return .empty;};
    }
    pub fn safe_bump_end(self:*Self, bump_by : usize) error{OutOfBounds}!void {
        self.copy( try self.safe_bumped_end(bump_by) );
    }
    pub fn bump_end(self:*Self, bump_by : usize) void {
        self.safe_bump_end(bump_by)catch{};
    }



    // comparisons
    pub fn is_equal(self:Self, other:Self) bool {
        return std.mem.eql(T, self.items(), other.items());
    }
    pub fn is_empty(self:Self) bool {
        return self.count == 0;
    }
    pub fn starts_with(self:Self, other:Self) bool {
        if (other.count > self.count) {
            return false;
        }
        return std.mem.eql(T, self.slice(0, other.count ), other.items());
    }
    pub fn ends_with(self:Self, other:Self) bool {
        if (other.count > self.count) {
            return false;
        }
        return std.mem.eql(T, self.slice(self.count - other.count, other.count ), other.items());
    }

    // miscalenious
    pub fn count_specific(self:Self, c:T) usize {
        var counter : usize = 0;
        for (self.items() ) |item| {
            if (item == c) {
                counter +=1;
            }
        }
        return counter;
    }
    pub fn find_left_of(self: Self, position_i: usize, c:T) usize {
        var it = std.mem.reverseIterator(self.items()[0..position_i]);
        var i = position_i;
        while (true) {
          const el = it.next();
          if (el == c) {
              return i;
          } else {
              if (i > 1) {
                i-=1;
              } else {
                  return 0;
              }
          }
        }
        unreachable;
    }

    // peeking and chopping
    // The default peek is left.
    // peek_fn should return peeked lenght.
    // If lenght is 0, it is considered to be not peeked, and this function returns everything until peeked.
    // This makes tokenizing easy - define
    // ```zig
    // fn peek_fn_left(v : View(u8)) usize {
    //   if (v.first() == ' ') {
    //     return 1;
    //   }
    //   return 0;
    // }
    // ```
    // and now you can peek by words. It will either peek a word, or a single space character.
    //
    //
    pub const peek = Self.peek_left;
    pub const chop = Self.chop_left;
    pub fn peek_left(self : Self, peek_fn:fn(Self)usize) Self {
        var work_self = self.clone();
        var ret_count :usize = 0;
        while (work_self.count > 0) {
            const step = peek_fn(work_self);
            if (step > 0) {
                if (ret_count > 0) {
                    return self.copy_from_start(ret_count);
                } else {
                    return work_self.copy_from_start(step);
                }
            } else {
              work_self.bump_start(1);
              ret_count+=1;
            }
        }
        return self.copy_from_start(ret_count);
    }
    pub fn chop_left(self : *Self, peek_fn:fn(Self)usize) Self {
        const chopped = self.peek_left(peek_fn);
        self.bump_start(chopped.count);
        return chopped;
    }
    pub fn peek_right(self : Self, peek_fn:fn(Self)usize) Self {
        var work_self = self.clone();
        var ret_count :usize= 0;
        while (work_self.count > 0) {
            const step = peek_fn(work_self);
            if (step > 0) {
                if (ret_count > 0) {
                    return self.copy_from_end(ret_count);
                } else {
                    return work_self.copy_from_end(step);
                }
            } else {
              work_self.bump_end(1);
              ret_count+=1;
            }
        }
        return self.copy_from_end(ret_count);
    }
    pub fn chop_right(self : *Self, peek_fn:fn(Self)usize) Self {
        const chopped = self.peek_right(peek_fn);
        self.bump_end(chopped.count);
        return chopped;
    }
    pub fn log(sv_ : Self) void {
        std.log.debug("{s}  <start: {d} count: {d} len: {d}>", .{sv_.items(), sv_.start, sv_.count, sv_.source.len});
    }
};

}

pub fn Builder(T:type, gpa: std.mem.Allocator) type {

return struct {
    const Self = @This();
    const BuilderView = View(T);
    const initial_capacity = 1;
    view : BuilderView,
    pub const empty :Self= .{.view=.empty};


    pub fn items(self:Self) []const T {
        return self.view.items();
    }

    pub fn safe_from(slice:[]const T) !Self {
        var ret : Self = .empty;
        ret.push(slice);
        return ret;
    }
    pub fn from(slice:[]const T) Self {
        return Self.safe_from(slice)catch{return .empty;};
    }
    pub fn safe_init(self:*Self) !void {
        if  ( self.view.source.len == 0 ) {
          try self.reserve(initial_capacity);
        }
    }
    pub fn init(self:*Self) void {
        self.safe_init()catch{};
    }
    pub fn safe_ensure_free_space(self:*Self, needed_free:usize) !void {
        try self.safe_init();
        const have_free = self.view.source.len - (self.view.start + self.view.count);
        const needed_total = self.view.source.len - have_free + needed_free;
        if ( have_free < needed_free )  {
            var new_capacity = self.view.source.len;

            while (new_capacity < needed_total) {
              new_capacity *= 2;
            }
            try self.reserve(new_capacity);
        }
    }
    pub fn ensure_free_space(self:*Self, needed:usize) void {
        self.safe_ensure_free_space(needed)catch{};
    }
    pub fn safe_push(self:*Self, slice:[]const T) !void {
        try self.safe_ensure_free_space(slice.len);
        const last_elem_pos =  self.view.start+self.view.count;
        const new_last_elem_pos =  self.view.start+self.view.count + slice.len;
        @memmove(@constCast(self.view.source)[last_elem_pos..new_last_elem_pos], slice[0..slice.len]);
        self.view.count += slice.len;
    }
    pub fn set_at(self:*Self, idx:usize, new_val:T) void {
        @constCast(self.items())[idx] = new_val;
    }
    pub fn push(self:*Self, slice:[]const T) void {
        self.safe_push(slice)catch{};
    }
    pub fn safe_push_fmt(self:*Self, comptime fmt:[]const T, args:anytype) !void {
        const tmp = try std.fmt.allocPrint(gpa, fmt, args);
        try self.safe_push(tmp);
    }
    pub fn push_fmt(self:*Self, comptime fmt:[]const T, args:anytype) void {
        self.safe_push_fmt(fmt, args)catch{};
    }
    pub fn safe_push_sv(self:*Self, sv:BuilderView) !void {
        try self.safe_push(sv.items());
    }
    pub fn push_sv(self:*Self, sv:BuilderView) void {
        self.safe_push_sv(sv)catch{};
    }
    pub fn safe_push_elem(self:*Self, elem: T) !void {
        const slice:[1] T = .{elem} ;
        try self.safe_push(&slice);
    }
    pub fn push_elem(self:*Self, elem: T) void {
        self.safe_push_elem(elem)catch{};
    }
    pub fn safe_push_file(self:*Self, filename: []const u8, io:std.Io) !void {
        // TODO: refactor to not use ArrayList.
      const file = try std.Io.Dir.cwd().openFile(io,filename, .{});
      var buf:[1024]T = undefined;
      var r = file.readerStreaming(io, &buf);
      var tmp :std.ArrayList(T) = .empty;
      try r.interface.appendRemaining(gpa, &tmp, .unlimited);
      self.push(try tmp.toOwnedSlice(gpa));
      defer file.close(io);
    }
    pub fn push_file(self:*Self, filename: []const u8, io:std.Io) void {
        self.safe_push_file(filename, io)catch{};
    }

    pub fn is_empty(self : Self) bool {
        return self.view.is_empty();
    }
    pub fn empty_out(self : *Self) void {
      self.view.start = 0;
      self.view.count = 0;
    }

    pub fn capacity(self:Self) usize {
      return self.view.source.len;
    }
    pub fn reserve(self : *Self, new_capacity: usize) !void {
      self.view.source = try gpa.realloc(self.view.source, new_capacity );
    }
    pub fn double(self : *Self) !void {
        try self.reserve(self.view.source.len * 2);
    }
    pub fn free(self : *Self) !void {
        try self.reserve(0);
    }
//#define da_init(da) do { if ((da)->capacity==0) { (da)->count=0; da_reserve((da), 10); } } while (0)

//#define da_double(da) da_reserve(da, 2 * (da)->capacity)

};

}
