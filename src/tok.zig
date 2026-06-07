const zig_sb_sv = @import("zig_sb_sv");
const std = @import("std");

const StringView = zig_sb_sv.View(u8);
var alloca = std.heap.DebugAllocator(.{}){};
const StringBuilder = zig_sb_sv.Builder(u8, alloca.allocator());



pub fn literal_len(sv:StringView, literal_start:StringView, literal_skip:StringView, literal_end:StringView) usize {
    var work_sv = sv.clone();
    if (!work_sv.starts_with(literal_start)) {
        return 0;
    }
    work_sv.bump_start(literal_start.count);
    var skip : bool= false;
    while (work_sv.count > 0) {
        if (skip) {
            skip = false;
        } else {
            if ( (literal_skip.count > 0) and work_sv.starts_with(literal_skip) ) {
                work_sv.bump_start(literal_skip.count);
                skip = true;
                continue;
            }
            if ( work_sv.starts_with(literal_end) ) {
                work_sv.bump_start(literal_end.count);
                return sv.count - work_sv.count;
            }
        }
        work_sv.bump_start(1);
    }
    return 0;
}





pub const Token  = struct {
    const Self= @This();
    content : StringView,
    ttype: StringBuilder, // if we will not free source, its fine to do View, but forn flexibility I use Builder
    position : usize,
    const empty :Self = .{.content=.empty, .ttype=.empty,.position=0};
    pub fn tok(content:StringView, ttype:StringBuilder) Token {
        return .{.content=content,.ttype=ttype,.position=0};
    }
    pub fn id(content:StringView) Token {
        return .tok(content, .from("id"));
    }
    pub fn expr() Token {
        return .tok(.empty, .from("expr"));
    }
    pub fn position_to_line(self:Self, src:StringView) usize {
        const before = src.copy_from_start(self.position);
        const num_of_newlines = before.count_specific('\n');
        return num_of_newlines+1;
    }
    pub fn position_to_row(self:Self, src:StringView) usize {
        const newline_pos = src.find_left_of(self.position,'\n');
        return self.position - newline_pos + 1;
    }

    pub fn tokenize(source_sv:StringView) TokenBuilder{
      var sv = source_sv.clone();
      var global_position :usize= 0;
      var tb :TokenBuilder=.empty;
      while (sv.count > 0) {
          const word = sv.chop_left(peek_fn_left);
          var token = get_token(word);
          if (token.content.is_empty()) {
              token = .id(word);
          }
          token.position = global_position;
          global_position += word.count;
          tb.push_elem(token);
      }
      return tb;
    }
};
const TokenBuilder = zig_sb_sv.Builder(Token, alloca.allocator());

const CompoundLiteralRule = struct {
    start:StringBuilder,
    skip:StringBuilder,
    end:StringBuilder,
    ttype:StringBuilder,
    pub fn from( start:[]const u8, skip:[]const u8, end:[]const u8, ttype:[]const u8) CompoundLiteralRule {
        return .{.start=.from(start), .skip=.from(skip), .end =.from(end), .ttype=.from(ttype)};
    }
};
var compound_literal_rules : zig_sb_sv.Builder(CompoundLiteralRule, alloca.allocator()) = .empty;
const SimpleLiteralRule = struct {
    keyword:StringBuilder,
    ttype:StringBuilder,
    pub fn from( keyword:[]const u8, ttype:[]const u8) SimpleLiteralRule {
        return .{.keyword=.from(keyword), .ttype=.from(ttype)};
    }
};
var simple_literal_rules : zig_sb_sv.Builder(SimpleLiteralRule, alloca.allocator()) = .empty;

fn iclr( start:[]const u8, skip:[]const u8, end:[]const u8, ttype:[]const u8) void {
    compound_literal_rules.push_elem(.from(start,skip,end,ttype) );
}
fn init_compount_literal_rules() void {
    iclr("\"","\\","\"","string");
    iclr("//","","\n","comment");
    iclr("/*","","*/","comment");
}
fn islr ( keyword:[]const u8, ttype:[]const u8) void {
    simple_literal_rules.push_elem(.from(keyword,ttype) );
}
fn islrm ( keywords:[]const []const u8, ttype:[]const u8) void {
    for (keywords) |k| {
      islr(k, ttype);
    }
}

fn init_simple_literal_rules() void {
    islrm( &.{ " ", "\n", "\t", "\r" }, "whitespace");
    islrm( &.{ "++","-=","+=","+","-", ":", "*", "=", "{", "}", "<", ">",";", "." } , "operator");
    islrm( &.{ "(" }, "open brace");
    islrm( &.{ ")" }, "close brace");
}

fn is_alphanumeric(c:u8) bool {
    const lower   = c>='a' and c<='z';
    const upper   = c>='A' and c<='Z';
    const number  = c>='0' and c<='9';
    const special = c=='_';
    return lower or upper or number or special;
}
fn is_delim(c:u8) bool {
    return !is_alphanumeric(c);
}

fn get_token(sv:StringView) Token {
    if ( compound_literal_rules.is_empty()  ) {
      init_compount_literal_rules();
    }
    if ( simple_literal_rules.is_empty()  ) {
      init_simple_literal_rules();
    }
    for (compound_literal_rules.items()) |rule| {
        const lit_len = literal_len(sv, rule.start.view, rule.skip.view, rule.end.view);
        if (lit_len > 0) {
            return .tok(sv.copy_from_start(lit_len), rule.ttype);
        }
    }
    for (simple_literal_rules.items()) |rule| {
      if ( sv.starts_with(rule.keyword.view) ) {
          return .tok(sv.copy_from_start(rule.keyword.view.count), rule.ttype );
      }
    }

    if (is_delim(sv.first())) {
        return .tok(sv.copy_from_start(1), .from("UNKNOWN") );
    }
    return .empty;
}

fn peek_fn_left(sv : StringView) usize {
    const token = get_token(sv);
    if (token.content.count > 0) {
        return token.content.count;
    }
    return 0;
}
pub fn is_in(sv:StringView, strs:[]const[]const u8) bool {
    for (strs) |str| {
        if (sv.is_equal( .from(str) )) {
            return true;
        }
    }
    return false;
}
pub fn filter_out_by_ttype(tb:*TokenBuilder, blacklisted_ttypes:[]const[]const u8) void {
    var i :usize= 0;
    for ( tb.items() ) |token| {
        tb.set_at(i, token);
        if (is_in(token.ttype.view, blacklisted_ttypes)) {
        } else {
            i += 1;
        }
    }
    tb.view.count = i;
}

const TokenView = zig_sb_sv.View(Token);
pub fn match_token_by_ttype(tv:TokenView, open_ttype: StringView, close_ttype:StringView) TokenView {
    if (tv.is_empty() ) {
        return .empty;
    }
    if (!tv.first().ttype.view.is_equal(open_ttype)) {
        return .empty;
    }
    var polarity :usize= 1;

    for (tv.items()[1..], 1..) |token, i| {
        if (token.ttype.view.is_equal(open_ttype)) {
            polarity += 1;
        }
        if (token.ttype.view.is_equal(close_ttype)) {
            polarity -= 1;
        }
        if (polarity == 0) {
            return tv.slice_sv(0,i+1);
        }
    }
    return .empty;
}
pub fn nooo_i_dont_want_to_be_a_tree( tv:TokenView ) Tree {
    var i:usize =0;
    var new_tree :Tree = .empty;
    while (i<tv.count) {

//        std.debug.print("{d}..{d}: ", .{i,tv.count});
        //for (tv.slice(i,tv.count)) |s| {
 //         std.debug.print("{s}|{s},", .{s.content.items(),s.ttype.items()});
       // }
        //std.debug.print("\n", .{});
      const sub_expr = match_token_by_ttype(tv.slice_sv(i,tv.count), .from("open brace"), .from("close brace"));
      if ( sub_expr.is_empty() ) {
          //std.debug.print("PUSHED ONE\n", .{});
          new_tree.func.push_elem( .id(tv.at(i))  );
          i+=1;
      } else {
          //std.debug.print("PUSHED MANY\n", .{});
          const sub_tree = nooo_i_dont_want_to_be_a_tree(sub_expr.slice_sv(1,sub_expr.count-1));
          new_tree.func.push_elem( sub_tree);
          i+=sub_expr.count;
      }
    }
    return new_tree;

}
pub const TreeBuilder = zig_sb_sv.Builder(Tree, alloca.allocator());
pub const TreeView = zig_sb_sv.View(Tree );
pub const Tree = struct {
    const Self = @This();
    token: Token,
    func: TreeBuilder,
    pub const empty :Self= .{.token=.empty, .func=.empty};
    // TODO: find a better name
    pub fn id( token : Token ) Tree {
        var self:Tree = .empty;
        self.token = token;
        return self;
    }
    pub fn sum(trees:TreeView) Self {
        var total :i32 = 0;
        for (trees.items()) |tree| {
            total += tree.eval().to_number();
        }
        var tmp_sb :StringBuilder= .empty;
        tmp_sb.push_fmt("{d}",.{total});

        return .id(.id(tmp_sb.view));
    }
    pub fn sub(trees:TreeView) Self {
        var total :i32 = trees.first().eval().to_number();
        for (trees.items()[1..]) |tree| {
            total -= tree.eval().to_number();
        }
        var tmp_sb :StringBuilder= .empty;
        tmp_sb.push_fmt("{d}",.{total});

        return .id(.id(tmp_sb.view));
    }
    pub fn to_number(self:Self) i32 {
        if (!self.token.content.is_empty()) {
            return std.fmt.parseInt(i32, self.token.content.items(), 10) catch { return 0; };
        } else {
            return 0;
        }
    }

    pub fn eval(self:Self) Self {
                //std.debug.print("TREE: {s}|{s}\n", .{self.token.content.items(), self.token.ttype.items()});
        var new_self = self;
        if (self.func.is_empty()) {
            //std.debug.print("NOTHING TO EVAL\n",.{});
            return new_self;
            // nothing to eval
        }

        const operator = self.func.view.first().eval();
        new_self.func.set_at(0,operator);
        if (operator.token.ttype.view.is_equal(.from("operator"))) {
            //std.debug.print("OP\n",.{});
            if (operator.token.content.is_equal(.from("+"))) {
                //std.debug.print("TREE: {s}|{s}\n", .{self.token.content.items(), self.token.ttype.items()});
                //std.debug.print("PLUS\n",.{});
                if (self.func.view.count > 2) {
                    return .sum(self.func.view.slice_sv(1,self.func.view.count));
                }
                return .empty;
            }
            if (operator.token.content.is_equal(.from("-"))) {
                if (self.func.view.count > 2) {
                    return .sub(self.func.view.slice_sv(1,self.func.view.count));
                }
                return .empty;

            }
            return new_self;
        } else {
            //std.debug.print("something else\n",.{});
            return operator;
        }
    }
    // (+ a b)<Tree>
    // ((+)<func> (a b)<args>)

    // ((just_put +)<func> (a b)<args>)<Tree>
    // \/
    // (+<func> (a b)<args>)<Tree>
    // evaled = (a+b<func>)<Tree>

};
