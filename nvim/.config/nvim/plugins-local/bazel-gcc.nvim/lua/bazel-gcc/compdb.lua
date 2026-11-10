-- compile_commands.json generation from `bazel aquery`, so clangd sees the exact GCC
-- command lines (include paths, defines, -std) that Bazel uses.
local config = require("bazel-gcc.config")
local workspace = require("bazel-gcc.workspace")
local parser = require("bazel-gcc.parser")

local M = {}

local function keep_flag(arg)
	for _, pat in ipairs(config.options.compdb.remove_flags) do
		if arg:match(pat) then
			return false
		end
	end
	return true
end

--- Make execroot-relative paths (external/..., bazel-out/...) resolvable from the workspace.
local function ensure_links(ws)
	if not config.options.compdb.link_external then
		return
	end
	local links = {
		external = ws.info.output_base .. "/external",
		["bazel-out"] = ws.info.execution_root .. "/bazel-out",
	}
	for name, target in pairs(links) do
		local p = ws.root .. "/" .. name
		if not vim.uv.fs_lstat(p) and workspace.exists(target) then
			vim.uv.fs_symlink(target, p)
		end
	end
end

--- Convert aquery jsonproto output into compile_commands.json entries.
function M.entries(ws, aquery)
	local entries, seen = {}, {}
	for _, a in ipairs(aquery.actions or {}) do
		local argv = a.arguments or {}
		local src = parser.compiled_source(argv)
		-- Generated sources of external repos live under bazel-out/<cfg>/bin/external/.
		local external = src and (src:match("^external/") or src:match("^bazel%-out/[^/]+/[^/]+/external/"))
		if src and not seen[src] and (config.options.compdb.include_external or not external) then
			seen[src] = true
			local args = {}
			for _, x in ipairs(argv) do
				if keep_flag(x) then
					table.insert(args, x)
				end
			end
			table.insert(entries, { directory = ws.root, file = src, arguments = args })
		end
	end
	table.sort(entries, function(x, y)
		return x.file < y.file
	end)
	return entries
end

--- clangd started before compile_commands.json existed keeps using fallback flags, so
--- restart the clients of this workspace and let vim.lsp.enable() re-attach them.
local function restart_clangd(ws)
	local stopping = {}
	for _, client in ipairs(vim.lsp.get_clients({ name = "clangd" })) do
		local root = client.root_dir and workspace.realpath(client.root_dir)
		if root and (workspace.relpath(ws.root, root) or workspace.relpath(root, ws.root)) then
			table.insert(stopping, client)
			client:stop()
		end
	end
	if #stopping == 0 then
		return
	end
	local timer = assert(vim.uv.new_timer())
	local tries = 0
	timer:start(100, 100, vim.schedule_wrap(function()
		tries = tries + 1
		local done = true
		for _, c in ipairs(stopping) do
			if not c:is_stopped() then
				done = false
			end
		end
		if not done and tries == 30 then
			for _, c in ipairs(stopping) do
				c:stop(true) -- force
			end
		end
		if done or tries > 50 then
			timer:stop()
			timer:close()
			-- Same mechanism vim.lsp.enable() uses to attach to already-open buffers.
			if not pcall(vim.cmd.doautoall, "nvim.lsp.enable FileType") then
				pcall(vim.cmd, "LspStart clangd") -- nvim-lspconfig fallback
			end
		end
	end))
end

--- Generate <root>/compile_commands.json. cb(ok, n_entries_or_err)
function M.generate(ws, targets, cb)
	cb = cb or function() end
	if ws.compdb_running then
		-- Wrapped in a table so a queued call without targets (nil) still counts.
		ws.compdb_again = { targets = targets }
		return cb(false, "already running")
	end
	targets = targets and #targets > 0 and targets or config.options.compdb.targets
	-- Set before workspace.info, which can be async, so a second call queues.
	ws.compdb_running = true

	local function done(ok, result)
		ws.compdb_running = false
		cb(ok, result)
		if ws.compdb_again then
			local again = ws.compdb_again
			ws.compdb_again = nil
			M.generate(ws, again.targets)
		end
	end

	workspace.info(ws, function(info, err)
		if not info then
			return done(false, err)
		end
		local expr = ("mnemonic('CppCompile', deps(%s))"):format(table.concat(targets, " + "))
		local args = { expr, "--output=jsonproto", "--include_artifacts=false", "--keep_going",
			"--ui_event_filters=-info", "--noshow_progress", "--color=no" }
		vim.list_extend(args, config.options.bazel_args)
		local cmd = config.bazel("aquery", args)
		local spawned, spawn_err = pcall(vim.system, cmd, { cwd = ws.root, text = true }, function(res)
			vim.schedule(function()
				-- Clear first so an unexpected error below cannot wedge later runs.
				ws.compdb_running = false
				local ok, data = pcall(vim.json.decode, res.stdout or "", { luanil = { object = true, array = true } })
				if not ok or type(data) ~= "table" then
					local msg = vim.trim(res.stderr or ""):gsub("\n.*", "")
					return done(false, "aquery failed: " .. msg)
				end
				ensure_links(ws)
				local entries = M.entries(ws, data)
				local path = ws.root .. "/compile_commands.json"
				local existed = workspace.exists(path)
				local tmp = path .. ".tmp"
				-- vim.json escapes "/" as "\/"; undo that for readability.
				local json = (vim.json.encode(entries):gsub("\\/", "/"))
				local f, open_err = io.open(tmp, "w")
				local written, write_err = false, open_err
				if f then
					written, write_err = f:write(json)
					local closed, close_err = f:close()
					written, write_err = written and closed, write_err or close_err
				end
				if written then
					written, write_err = vim.uv.fs_rename(tmp, path)
				end
				if not written then
					os.remove(tmp)
					return done(false, ("cannot write %s: %s"):format(path, write_err))
				end
				if not existed and config.options.compdb.restart_clangd then
					restart_clangd(ws)
				end
				done(true, #entries)
			end)
		end)
		if not spawned then
			done(false, ("cannot run %s: %s"):format(cmd[1], spawn_err))
		end
	end)
end

return M
