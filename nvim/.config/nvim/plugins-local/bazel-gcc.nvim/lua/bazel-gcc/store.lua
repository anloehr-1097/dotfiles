-- Diagnostic store keyed by Bazel action.
--
-- Bazel does not replay compiler output for cached actions, so a warning only shows up in
-- the build that actually ran the compile. We therefore keep diagnostics per action
-- (primary output): an action that ran replaces its entry, an action that was cached keeps
-- what it reported last time. The store is persisted per workspace so warnings survive
-- restarts of Neovim.
local parser = require("bazel-gcc.parser")
local workspace = require("bazel-gcc.workspace")

local M = {}

M.ns = vim.api.nvim_create_namespace("bazel-gcc")

local SEV = {
	error = vim.diagnostic.severity.ERROR,
	warning = vim.diagnostic.severity.WARN,
	note = vim.diagnostic.severity.HINT,
}

local function state_file(ws)
	local dir = vim.fn.stdpath("state") .. "/bazel-gcc"
	vim.fn.mkdir(dir, "p")
	return ("%s/%s.json"):format(dir, vim.fn.sha256(ws.root):sub(1, 16))
end

local function ensure(ws)
	if ws.store then
		return ws.store
	end
	ws.store = { actions = {}, bazel = {} }
	local f = io.open(state_file(ws), "r")
	if f then
		local ok, data = pcall(vim.json.decode, f:read("*a"), { luanil = { object = true, array = true } })
		f:close()
		if ok and type(data) == "table" and data.version == 1 then
			ws.store.actions = data.actions or {}
		end
	end
	return ws.store
end
M.ensure = ensure

--- Forget diagnostics of files that no longer exist (deleted or renamed sources).
local function prune(actions)
	local exists = {}
	for key, by_file in pairs(actions) do
		for path in pairs(by_file) do
			if exists[path] == nil then
				exists[path] = vim.uv.fs_stat(path) ~= nil
			end
			if not exists[path] then
				by_file[path] = nil
			end
		end
		if next(by_file) == nil then
			actions[key] = nil
		end
	end
end

--- Persist the store. Written to a temporary file and renamed over the state file, so a
--- crash, a full disk or a second Neovim reading it never sees truncated JSON.
function M.save(ws)
	local actions = ensure(ws).actions
	prune(actions)
	local path = state_file(ws)
	local tmp = ("%s.%d.tmp"):format(path, vim.uv.os_getpid())
	local f, err = io.open(tmp, "w")
	local ok = false
	if f then
		local wrote, werr = f:write(vim.json.encode({ version = 1, root = ws.root, actions = actions }))
		local closed, cerr = f:close()
		ok, err = (wrote and closed) and true or false, werr or cerr
		if ok then
			ok, err = vim.uv.fs_rename(tmp, path)
		end
	end
	if not ok then
		os.remove(tmp)
		vim.notify(("bazel-gcc: cannot save diagnostics state %s: %s"):format(path, err), vim.log.levels.WARN)
	end
end

--- Replace the diagnostics of one executed action. `diags` are parser.parse_gcc() results
--- with `path` already resolved to a real file path.
function M.set_action(ws, key, diags)
	local by_file = {}
	for _, d in ipairs(diags) do
		local list = by_file[d.path] or {}
		by_file[d.path] = list
		table.insert(list, {
			lnum = d.lnum,
			col = d.col,
			end_col = d.end_col,
			severity = d.severity,
			message = d.message,
			code = d.code,
			source = d.source,
		})
	end
	ensure(ws).actions[key] = next(by_file) and by_file or nil
end

--- Bazel's own messages (BUILD file errors) are re-reported by every build, so replace all.
function M.set_bazel(ws, diags)
	local by_file = {}
	for _, d in ipairs(diags) do
		by_file[d.path] = by_file[d.path] or {}
		table.insert(by_file[d.path], d)
	end
	ensure(ws).bazel = by_file
end

function M.clear(ws)
	ws.store = { actions = {}, bazel = {} }
	M.save(ws)
end

--- All raw diagnostics for a file, deduplicated (the same file is often compiled in several
--- configurations or included by several translation units).
function M.for_file(ws, file)
	local store = ensure(ws)
	local seen, out = {}, {}
	local function add(list)
		for _, d in ipairs(list or {}) do
			local k = table.concat({ d.lnum, d.col or 0, d.severity, d.message }, "\0")
			if not seen[k] then
				seen[k] = true
				table.insert(out, d)
			end
		end
	end
	for _, files in pairs(store.actions) do
		add(files[file])
	end
	add(store.bazel[file])
	return out
end

--- Every file that currently has diagnostics.
function M.files(ws)
	local store, set = ensure(ws), {}
	for _, files in pairs(store.actions) do
		for f in pairs(files) do
			set[f] = true
		end
	end
	for f in pairs(store.bazel) do
		set[f] = true
	end
	return vim.tbl_keys(set)
end

local function to_vim(d, line, tabstop)
	local col = parser.display_to_byte(line, d.col or 1, tabstop)
	local end_col = d.end_col and parser.display_to_byte(line, d.end_col + 1, tabstop) or nil
	if d.col == nil and line then
		col = #(line:match("^%s*") or "") -- no column: start at first non-blank
	end
	return {
		lnum = math.max(d.lnum - 1, 0),
		col = col,
		end_col = end_col and end_col > col and end_col or nil,
		severity = SEV[d.severity] or vim.diagnostic.severity.ERROR,
		message = d.message,
		code = d.code,
		source = d.source or "gcc",
	}
end

function M.publish_buf(ws, bufnr)
	if not vim.api.nvim_buf_is_loaded(bufnr) then
		return
	end
	local name = vim.api.nvim_buf_get_name(bufnr)
	if name == "" then
		return
	end
	local raw = M.for_file(ws, workspace.realpath(name))
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local diags = {}
	for _, d in ipairs(raw) do
		table.insert(diags, to_vim(d, lines[d.lnum], 8))
	end
	vim.diagnostic.set(M.ns, bufnr, diags)
end

function M.publish(ws)
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(bufnr) then
			local name = vim.api.nvim_buf_get_name(bufnr)
			if name ~= "" and workspace.relpath(ws.root, workspace.realpath(name)) then
				M.publish_buf(ws, bufnr)
			end
		end
	end
end

--- Quickfix items for the whole workspace (including files that are not open).
function M.qf_items(ws)
	local items = {}
	for _, file in ipairs(M.files(ws)) do
		for _, d in ipairs(M.for_file(ws, file)) do
			table.insert(items, {
				filename = file,
				lnum = d.lnum,
				col = d.col or 1,
				type = d.severity:sub(1, 1):upper(),
				text = d.message:gsub("\n", " "),
			})
		end
	end
	-- Errors, then warnings, then notes; within a type by file and line.
	local rank = { E = 1, W = 2, N = 3 }
	table.sort(items, function(a, b)
		if a.type ~= b.type then
			return (rank[a.type] or 4) < (rank[b.type] or 4)
		end
		if a.filename ~= b.filename then
			return a.filename < b.filename
		end
		return a.lnum < b.lnum
	end)
	return items
end

function M.counts(ws)
	local e, w = 0, 0
	for _, file in ipairs(M.files(ws)) do
		for _, d in ipairs(M.for_file(ws, file)) do
			if d.severity == "error" then
				e = e + 1
			elseif d.severity == "warning" then
				w = w + 1
			end
		end
	end
	return e, w
end

return M
