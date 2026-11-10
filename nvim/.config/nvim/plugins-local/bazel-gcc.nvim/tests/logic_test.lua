-- Unit tests for the plugin's state handling (no Bazel needed; vim.system is stubbed).
-- Run: nvim -l tests/logic_test.lua   (from the plugin directory)
vim.opt.rtp:prepend(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h"))

local tmp = vim.fn.tempname()
vim.fn.mkdir(tmp, "p")
vim.uv.os_setenv("XDG_STATE_HOME", tmp .. "/state") -- keep the persisted store out of ~/.local

local failures = 0
local function eq(got, want, what)
	if not vim.deep_equal(got, want) then
		failures = failures + 1
		print(("FAIL %s\n  got:  %s\n  want: %s"):format(what, vim.inspect(got), vim.inspect(want)))
	end
end

local config = require("bazel-gcc.config")
local workspace = require("bazel-gcc.workspace")
local store = require("bazel-gcc.store")
local build = require("bazel-gcc.build")
local compdb = require("bazel-gcc.compdb")

-- query_word: unquoted names with query syntax in them would not parse
eq(config.query_word("//lib:a+b.cc"), '"//lib:a+b.cc"', "query_word plus")
eq(config.query_word("//lib:my file.cc"), '"//lib:my file.cc"', "query_word space")
eq(config.query_word("//lib:it's.cc"), '"//lib:it\'s.cc"', "query_word apostrophe")
eq(config.query_word([[//lib:a"b'c.cc]]), nil, "query_word both quote kinds")

-- store.save: atomic write that round-trips, and diagnostics of vanished files are dropped
local real = tmp .. "/real.cc"
vim.fn.writefile({ "int x;" }, real)
local ws = { root = tmp .. "/ws" }
local diag = { lnum = 1, col = 1, severity = "warning", message = "m" }
store.set_action(ws, "keep|cfg", { vim.tbl_extend("force", diag, { path = real }) })
store.set_action(ws, "gone|cfg", { vim.tbl_extend("force", diag, { path = tmp .. "/deleted.cc" }) })
store.save(ws)
local dir = tmp .. "/state/nvim/bazel-gcc"
local files = vim.fn.glob(dir .. "/*", false, true)
eq(#files, 1, "state dir holds only the state file (no leftover .tmp)")
eq(vim.endswith(files[1] or "", ".json"), true, "state file is *.json")
local saved = vim.json.decode(table.concat(vim.fn.readfile(files[1] or ""), "\n"))
eq(vim.tbl_keys(saved.actions), { "keep|cfg" }, "vanished file pruned from the persisted actions")
eq(store.ensure(ws).actions["gone|cfg"], nil, "vanished file pruned from memory")

-- store.save failure: warns and leaves no temporary file behind
local warned
local orig_notify = vim.notify
vim.notify = function(msg, level)
	warned = { msg = msg, level = level }
end
local blocked = { root = tmp .. "/ws2", store = { actions = {}, bazel = {} } }
local state_dir = tmp .. "/state/nvim/bazel-gcc"
vim.uv.fs_chmod(state_dir, tonumber("500", 8))
store.save(blocked)
vim.uv.fs_chmod(state_dir, tonumber("700", 8))
vim.notify = orig_notify
if vim.uv.getuid() ~= 0 then -- root ignores directory permissions
	eq(warned and warned.level, vim.log.levels.WARN, "unwritable state dir warns")
end
eq(#vim.fn.glob(state_dir .. "/*.tmp", false, true), 0, "no .tmp left after a failed save")

-- compdb.generate: requests made while a run is in flight are merged, none is lost
workspace.info = function() end -- never answers, so the first call stays "running"
local cws = { root = tmp }
compdb.generate(cws, { "//pinned:one" })
compdb.generate(cws, { "//explicit:two" })
compdb.generate(cws) -- BUILD-file save path: no targets
eq(cws.compdb_again.targets, { "//explicit:two", unpack(config.options.compdb.targets) }, "queued compdb targets are merged")
compdb.generate(cws, { "//explicit:two" })
eq(#cws.compdb_again.targets, 1 + #config.options.compdb.targets, "queued compdb targets are de-duplicated")

-- compdb.external_entries: one entry per external repo, with the flags of the source that
-- references the repo most, placed inside <output_base>/external/<repo>/
do
	local xws = { root = "/ws", info = { output_base = "/ob" } }
	local x = compdb.external_entries(xws, {
		{ file = "a.cc", arguments = { "g++", "-isystem", "external/qt/include", "-c", "a.cc" } },
		{ file = "b.cc", arguments = { "g++", "-isystem", "external/qt/include", "-isystem",
			"bazel-out/k8-fastbuild/bin/external/qt/include/QtWidgets", "-Iexternal/zlib", "-c", "b.cc" } },
		{ file = "c.cc", arguments = { "g++", "-c", "c.cc" } },
	})
	eq(vim.tbl_map(function(e)
		return e.file
	end, x), { "/ob/external/qt/__bazel_gcc_clangd__.cc", "/ob/external/zlib/__bazel_gcc_clangd__.cc" },
		"external entries: one per referenced repo")
	eq(x[1].arguments[#x[1].arguments], "/ob/external/qt/__bazel_gcc_clangd__.cc", "external entry compiles the placeholder")
	eq(x[1].arguments[5], "bazel-out/k8-fastbuild/bin/external/qt/include/QtWidgets", "external entry takes the best-matching flags")
	eq(x[1].directory, "/ws", "external entry runs from the workspace root")
end

-- build.owners: a query that was in flight when a BUILD file changed must not be cached
workspace.realpath = function(f)
	return f
end
workspace.label = function()
	return "//pkg:f.cc", "pkg"
end
workspace.is_build_file = function()
	return false
end
local pending
local orig_system = vim.system
vim.system = function(cmd, _, on_exit)
	pending = { cmd = cmd, on_exit = on_exit }
	return {}
end
local function answer(ows, file)
	local got
	build.owners(ows, file, function(t)
		got = t
	end)
	local call = pending
	return call, function(res)
		call.on_exit(res)
		vim.wait(200, function()
			return got ~= nil
		end)
		return got
	end
end

local ows = { owners = {} }
local call, finish_query = answer(ows, "f.cc")
eq(table.concat(call.cmd, " "):find('same_pkg_direct_rdeps("//pkg:f.cc")', 1, true) ~= nil, true, "owners query quotes the label")
eq(finish_query({ code = 0, stdout = "//pkg:lib\n", stderr = "" }), { "//pkg:lib" }, "owners result")
eq(ows.owners["f.cc"], { "//pkg:lib" }, "owners result cached when nothing changed")

local ows2 = { owners = {} }
local _, finish_stale = answer(ows2, "f.cc")
build.invalidate_owners(ows2) -- BUILD file saved while the query runs
eq(finish_stale({ code = 0, stdout = "//pkg:old\n", stderr = "" }), { "//pkg:old" }, "stale query still answers its caller")
eq(ows2.owners["f.cc"], nil, "stale owners result not cached")
vim.system = orig_system

-- build finish: a build that never reached BuildFinished keeps the BUILD diagnostics
workspace.info = function(_, cb)
	cb({})
end
local bws = { root = tmp, owners = {} }
local bfile = tmp .. "/BUILD.bazel"
vim.fn.writefile({ "x" }, bfile)
store.ensure(bws).bazel = { [bfile] = { { path = bfile, lnum = 1, col = 1, severity = "error", message = "bad rule" } } }
local exit_cb
vim.system = function(_, _, on_exit)
	exit_cb = on_exit
	return {}
end
build.build(bws, { "//pkg:lib" })
exit_cb({ code = 36, stdout = "", stderr = "boom" }) -- no BEP file was written
vim.wait(200, function()
	return bws.last ~= nil
end)
vim.system = orig_system
eq(bws.last and bws.last.ok, false, "build without BEP reported as failed")
eq(store.ensure(bws).bazel[bfile] ~= nil, true, "BUILD diagnostics survive a build that produced no BEP")

if failures > 0 then
	print(("%d logic test(s) failed"):format(failures))
	os.exit(1)
end
print("logic tests: all passed")
