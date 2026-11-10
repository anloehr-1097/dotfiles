-- Run: nvim -l tests/parser_test.lua   (from the plugin directory)
vim.opt.rtp:prepend(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h"))
local p = require("bazel-gcc.parser")

local failures = 0
local function eq(got, want, what)
	if not vim.deep_equal(got, want) then
		failures = failures + 1
		print(("FAIL %s\n  got:  %s\n  want: %s"):format(what, vim.inspect(got), vim.inspect(want)))
	end
end

-- warning with caret range, function context line, ANSI colours
local d = p.parse_gcc(table.concat({
	"lib/greet.cc: In function 'std::string lib::greet(const std::string&)':",
	"\27[01m\27[Klib/greet.cc:4:7:\27[m\27[K \27[01;35m\27[Kwarning: \27[m\27[Kunused variable 'unused' [-Wunused-variable]",
	"    4 |   int unused = 42;",
	"      |       ^~~~~~",
}, "\n"))
eq(#d, 1, "one warning")
eq({ d[1].path, d[1].lnum, d[1].col, d[1].end_col, d[1].severity, d[1].code },
	{ "lib/greet.cc", 4, 7, 12, "warning", "-Wunused-variable" }, "warning fields")

-- error followed by notes (folded) and a range that starts before the caret
d = p.parse_gcc(table.concat({
	"app/main.cc:7:14: error: no match for 'operator+' (operand types are 'A' and 'B')",
	"    7 |   auto c = a + b;",
	"      |            ~ ^ ~",
	"      |            |   |",
	"app/main.cc:3:8: note: candidate: 'A operator+(A, A)'",
	"In file included from app/main.cc:1:",
	"lib/x.h:2:1: fatal error: nope.h: No such file or directory",
	"compilation terminated.",
}, "\n"))
eq(#d, 2, "error + fatal error, note folded")
eq({ d[1].col, d[1].end_col }, { 14, 14 }, "caret run without adjacent tildes")
eq(d[1].message:match("note %(main.cc:3%)") ~= nil, true, "note folded into message")
eq({ d[2].path, d[2].severity }, { "lib/x.h", "error" }, "fatal error in header")

-- gold linker: file:line: error: (no column)
d = p.parse_gcc("app/main.cc:6: error: undefined reference to 'lib::missing()'\ncollect2: error: ld returned 1 exit status")
eq({ #d, d[1].lnum, d[1].col, d[1].severity }, { 1, 6, nil, "error" }, "linker error without column")

-- "required from here" context lines are not diagnostics
d = p.parse_gcc("a.cc:3:10:   required from here\na.cc:9:5: error: boom")
eq(#d, 1, "context lines ignored")

-- display columns -> byte columns
eq(p.display_to_byte("\tint x;", 10), 2, "tab expands to 8")
eq(p.display_to_byte("int x;", 5), 4, "ascii")
eq(p.display_to_byte("s = \"äö\"; y", 11), 12, "utf-8 multibyte")

-- Bazel console blocks
local blocks = p.split_blocks(table.concat({
	"INFO: From Compiling lib/greet.cc:",
	"lib/greet.cc:4:7: warning: unused variable 'unused' [-Wunused-variable]",
	"ERROR: /ws/app/BUILD.bazel:2:10: Compiling app/main.cc failed: (Exit 1): gcc failed: error executing CppCompile command",
	"app/main.cc:7:10: error: 'x' was not declared in this scope",
	"ERROR: /ws/app/BUILD.bazel:2:10: no such target '//lib:nope'",
	"INFO: Elapsed time: 0.1s",
}, "\n"))
eq(#blocks, 4, "four blocks")
eq({ p.block_subject(blocks[1].header) }, { "lib/greet.cc", false }, "INFO From subject")
eq({ p.block_subject(blocks[2].header) }, { "app/main.cc", true }, "failed subject")
eq(p.located(blocks[3].header), { path = "/ws/app/BUILD.bazel", lnum = 2, col = 10, message = "no such target '//lib:nope'" }, "located")
eq(p.compiled_source({ "/usr/bin/gcc", "-c", "lib/a.cc", "-o", "a.o" }), "lib/a.cc", "compiled source")

if failures > 0 then
	print(failures .. " failure(s)")
	os.exit(1)
end
print("parser tests: all passed")
