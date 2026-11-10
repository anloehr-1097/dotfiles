-- Driven by tests/e2e.sh with the user's full Neovim config loaded.
local root = assert(os.getenv("BZDEMO"), "BZDEMO not set")
local TIMEOUT = tonumber(os.getenv("E2E_TIMEOUT") or "") or 180000
local failed = 0

local function log(...)
	local s = table.concat(vim.tbl_map(tostring, { ... }), " ") .. "\n"
	io.stdout:write(s)
	io.stdout:flush()
end
local function check(name, ok, detail)
	if not ok then
		failed = failed + 1
	end
	log((ok and "PASS " or "FAIL ") .. name .. (detail and ("  [" .. detail .. "]") or ""))
end

local function wait(ms, cond)
	return vim.wait(ms, cond, 50)
end

-- Count builds via the plugin's User autocmd.
local builds = 0
vim.api.nvim_create_autocmd("User", {
	pattern = "BazelGccBuildDone",
	callback = function()
		builds = builds + 1
	end,
})
-- A configured-but-missing linter errors in BufWritePost; inside pcall that aborts all
-- following BufWritePost handlers (including ours), so drop it for the test.
pcall(function()
	local lint = require("lint")
	for ft, linters in pairs(lint.linters_by_ft) do
		lint.linters_by_ft[ft] = vim.tbl_filter(function(l)
			local def = lint.linters[l]
			local cmd = type(def) == "table" and def.cmd or l
			return type(cmd) ~= "string" or vim.fn.executable(cmd) == 1
		end, linters)
	end
end)

local function save_and_wait_build()
	local n = builds
	-- other BufWritePost hooks (e.g. a missing linter) must not abort the test
	pcall(vim.cmd, "silent write")
	return wait(TIMEOUT, function()
		return builds > n
	end)
end

local function buf_diags(bufnr, ns)
	return vim.diagnostic.get(bufnr, { namespace = ns })
end
local function find(list, pat)
	for _, d in ipairs(list) do
		if d.message:find(pat) then
			return d
		end
	end
end

-- 1. open a source file: loads lsp + bazel-gcc, generates compile_commands.json --------
vim.cmd.edit(root .. "/app/main.cc")
local main_buf = vim.api.nvim_get_current_buf()
local bg = require("bazel-gcc")

-- Record raw clangd diagnostics (outermost wrapper, i.e. before bazel-gcc filters them).
local raw_by_client = {} -- client id -> fname -> diagnostics
local inner = vim.lsp.handlers["textDocument/publishDiagnostics"]
vim.lsp.handlers["textDocument/publishDiagnostics"] = function(err, result, ctx, ...)
	local c = vim.lsp.get_client_by_id(ctx.client_id)
	if c and c.name == "clangd" and result then
		raw_by_client[c.id] = raw_by_client[c.id] or {}
		raw_by_client[c.id][vim.uri_to_fname(result.uri)] = vim.deepcopy(result.diagnostics)
	end
	return inner(err, result, ctx, ...)
end

check("compile_commands.json generated", wait(TIMEOUT, function()
	return vim.uv.fs_stat(root .. "/compile_commands.json") ~= nil
end))
local cdb = vim.json.decode(table.concat(vim.fn.readfile(root .. "/compile_commands.json"), "\n"))
local files = vim.tbl_map(function(e)
	return e.file
end, cdb)
table.sort(files)
check("compdb has both sources", vim.deep_equal(files, { "app/main.cc", "lib/greet.cc" }), table.concat(files, ","))
check("compdb uses Bazel's gcc", cdb[1].arguments[1]:find("gcc") ~= nil, cdb[1].arguments[1])

local function clangd()
	for _, c in ipairs(vim.lsp.get_clients({ name = "clangd", bufnr = main_buf })) do
		if not c:is_stopped() then
			return c
		end
	end
end
-- clangd started before the database existed; bazel-gcc restarts it. Wait for the client
-- that runs with the database to publish diagnostics for main.cc.
wait(3000, function() return false end)
check("clangd attached", wait(TIMEOUT, function()
	local c = clangd()
	return c ~= nil and (raw_by_client[c.id] or {})[root .. "/app/main.cc"] ~= nil
end))
local client = clangd()
local raw_clangd = raw_by_client[client.id]
check("clangd was restarted after the database appeared", vim.tbl_count(raw_by_client) >= 2 or client.id > 1,
	"client id " .. client.id)
check("clangd started with --query-driver", table.concat(client.config.cmd, " "):find("query%-driver") ~= nil)
check("clangd: no errors in main.cc (headers resolved)", #vim.tbl_filter(function(d)
	return d.severity == 1
end, raw_clangd[root .. "/app/main.cc"] or {}) == 0, vim.inspect(raw_clangd[root .. "/app/main.cc"]))

local function pos_of(bufnr, pattern, offset)
	for i, l in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
		local s = l:find(pattern, 1, true)
		if s then
			return { line = i - 1, character = s - 1 + (offset or 0) }
		end
	end
end
local function request(method, pos)
	local params = { textDocument = vim.lsp.util.make_text_document_params(main_buf), position = pos }
	if method == "textDocument/references" then
		params.context = { includeDeclaration = true }
	end
	local res = client:request_sync(method, params, 20000, main_buf)
	return res and res.result
end
local function first_uri(r)
	r = r and (r.uri and r or r[1])
	return r and vim.uri_to_fname(r.uri or r.targetUri) or "nil"
end

-- 2. LSP features through clangd -------------------------------------------------------
local def = first_uri(request("textDocument/definition", pos_of(main_buf, "greet(", 0)))
check("go-to-definition lib::greet -> lib/", def:find("/lib/greet%.") ~= nil, def)

local vdef = first_uri(request("textDocument/definition", pos_of(main_buf, "vector<", 0)))
check("go-to-definition std::vector -> GCC libstdc++", vdef:find("/c%+%+/%d+/") ~= nil, vdef)

local hover = request("textDocument/hover", pos_of(main_buf, "size()", 0))
local htext = hover and (hover.contents.value or vim.inspect(hover.contents)) or ""
check("hover on v.size()", htext:find("size") ~= nil, htext:gsub("\n", " "):sub(1, 80))

local comp = request("textDocument/completion", pos_of(main_buf, "v.size", 2))
local labels = {}
for _, it in ipairs((comp and (comp.items or comp)) or {}) do
	labels[vim.trim(it.label)] = true
	labels[it.filterText or ""] = true
end
check("completion after 'v.' offers push_back", labels["push_back"] or labels["push_back(const value_type &x)"] or
	next(vim.tbl_filter(function(k) return k:find("^push_back") end, vim.tbl_keys(labels))) ~= nil)

local refs = request("textDocument/references", pos_of(main_buf, "v{", 0))
check("references of v", refs and #refs >= 2, refs and #refs)

-- 3. GCC diagnostics via Bazel/BEP ------------------------------------------------------
vim.cmd.edit(root .. "/lib/greet.cc")
local lib_buf = vim.api.nvim_get_current_buf()
wait(30000, function()
	return raw_clangd[root .. "/lib/greet.cc"] ~= nil
end)
local raw = raw_clangd[root .. "/lib/greet.cc"] or {}
local bogus = find(raw, "has_attribute") or find(raw, "undeclared")
check("clangd (raw) reports a bogus error for the GCC builtin", bogus ~= nil and bogus.severity == 1,
	bogus and bogus.message)
local clangd_ns = vim.lsp.diagnostic.get_namespace(client.id, false)
check("...and bazel-gcc hides it (clangd_diagnostics=tidy)",
	#vim.tbl_filter(function(d) return d.severity == 1 end, buf_diags(lib_buf, clangd_ns)) == 0)

-- 3a. introduce a real error
vim.api.nvim_buf_set_lines(lib_buf, 7, 8, false, { '  return "hello, " + whoo;' })
check("build ran after save (error)", save_and_wait_build())
local ds = buf_diags(lib_buf, bg.ns)
local err = find(ds, "whoo")
check("GCC error published", err ~= nil and err.severity == vim.diagnostic.severity.ERROR and err.lnum == 7,
	err and ("%d:%d %s [%s]"):format(err.lnum, err.col, err.message, err.source))
local wcol = ('  return "hello, " + whoo;'):find("whoo", 1, true) - 1
check("error has column range from GCC caret", err and err.col == wcol and err.end_col == wcol + 4,
	err and (err.col .. "-" .. tostring(err.end_col)))
check("no bogus error for the GCC builtin from GCC", find(ds, "has_attribute") == nil)
check("statusline component", bg.status():find("✗") ~= nil, bg.status())

-- 3b. fix it: the compile re-runs, error disappears, the unused-variable warning appears
vim.api.nvim_buf_set_lines(lib_buf, 7, 8, false, { '  return "hello, " + who;' })
check("build ran after save (fixed)", save_and_wait_build())
ds = buf_diags(lib_buf, bg.ns)
local warn = find(ds, "unused variable")
check("error cleared", find(ds, "whoo") == nil)
check("GCC warning published", warn ~= nil and warn.severity == vim.diagnostic.severity.WARN and warn.code == "-Wunused-variable",
	warn and ("%d:%d %s"):format(warn.lnum, warn.col, warn.message))

-- 3c. save again unchanged: the compile is cached, the warning must survive
check("build ran after save (cached)", save_and_wait_build())
local wsobj = require("bazel-gcc.workspace").get(root .. "/lib/greet.cc")
check("cached build re-ran no compile", wsobj.last.ran == 0, "actions ran: " .. wsobj.last.ran)
check("warning kept for cached action", find(buf_diags(lib_buf, bg.ns), "unused variable") ~= nil)

-- 3d. editing the header recompiles includers in other targets
vim.cmd.edit(root .. "/lib/greet.h")
local hdr = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(hdr, 4, 4, false, { "inline int twice(int x) { int y; return x * 2; }" })
check("build ran after header save", save_and_wait_build())
local hw = find(buf_diags(hdr, bg.ns), "unused variable 'y'")
check("GCC warning in header (from //lib:greet compile)", hw ~= nil, hw and hw.message)
vim.api.nvim_buf_set_lines(hdr, 4, 5, false, {})
save_and_wait_build()
check("header warning cleared", find(buf_diags(hdr, bg.ns), "unused variable 'y'") == nil)

-- 3e. BUILD file errors from Bazel itself
vim.cmd.edit(root .. "/app/BUILD.bazel")
local bbuf = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(bbuf, 4, 5, false, { '    deps = ["//lib:greet", "//lib:nope"],' })
check("build ran after BUILD save", save_and_wait_build())
local be = find(buf_diags(bbuf, bg.ns), "nope")
check("Bazel analysis error on BUILD file", be ~= nil and be.source == "bazel",
	be and ("%d: %s"):format(be.lnum, be.message:gsub("\n.*", "")))
vim.api.nvim_buf_set_lines(bbuf, 4, 5, false, { '    deps = ["//lib:greet"],' })
save_and_wait_build()
check("BUILD error cleared", find(buf_diags(bbuf, bg.ns), "nope") == nil)

-- 3f. quickfix aggregation
vim.cmd("BazelGcc qf")
local qf = vim.fn.getqflist()
check("quickfix lists the warning", #qf >= 1 and qf[1].text:find("unused") ~= nil, #qf .. " item(s)")

log(failed == 0 and "ALL E2E CHECKS PASSED" or (failed .. " E2E CHECK(S) FAILED"))
vim.cmd(failed == 0 and "qa!" or "cq!")
