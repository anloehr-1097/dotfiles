-- bazel-gcc.nvim: GCC diagnostics from real Bazel builds, alongside clangd.
--
--   clangd  -> navigation, completion, references, index (fed by a generated
--              compile_commands.json with Bazel's exact GCC command lines)
--   bazel   -> authoritative errors/warnings: background `bazel build` on save, GCC output
--              taken per action from the Build Event Protocol, published in namespace
--              "bazel-gcc".
local config = require("bazel-gcc.config")
local workspace = require("bazel-gcc.workspace")
local store = require("bazel-gcc.store")
local build = require("bazel-gcc.build")
local compdb = require("bazel-gcc.compdb")

local M = {}

M.ns = store.ns
M.enabled = true

local function current_ws(bufnr)
	local name = vim.api.nvim_buf_get_name(bufnr or 0)
	return workspace.get(name), name
end

--- Statusline component: "" outside Bazel workspaces.
function M.status()
	local ws = current_ws(0)
	if not ws then
		return ""
	end
	if ws.running then
		return "bazel ⟳"
	end
	if ws.last then
		if ws.last.ok and ws.last.errors == 0 and ws.last.warnings == 0 then
			return "bazel ✓"
		end
		return ("bazel %s %dE %dW"):format(ws.last.ok and "✓" or "✗", ws.last.errors, ws.last.warnings)
	end
	return "bazel"
end

-- ---------------------------------------------------------------------------
-- clangd diagnostic filtering in Bazel workspaces
-- ---------------------------------------------------------------------------
local function filter_clangd(diags)
	local mode = config.options.clangd_diagnostics
	if mode == "all" or not diags then
		return diags
	end
	if mode == "none" then
		return {}
	end
	local out = {}
	for _, d in ipairs(diags) do
		local compiler = d.source == nil or d.source == "clang"
		if not compiler then
			table.insert(out, d) -- clang-tidy, include-cleaner ("clangd")
		elseif mode == "hint" then
			d.severity = vim.lsp.protocol.DiagnosticSeverity.Hint
			table.insert(out, d)
		end
	end
	return out
end

local function in_bazel_ws(uri)
	local ok, fname = pcall(vim.uri_to_fname, uri or "")
	return ok and workspace.get(fname) ~= nil
end

local function wrap_clangd_handlers()
	local function wrap(method, field)
		local orig = vim.lsp.handlers[method]
		if not orig then
			return
		end
		vim.lsp.handlers[method] = function(err, result, ctx, ...)
			local client = ctx and vim.lsp.get_client_by_id(ctx.client_id)
			if result and client and client.name == "clangd" then
				local uri = result.uri or (ctx.params and ctx.params.textDocument and ctx.params.textDocument.uri)
				if in_bazel_ws(uri) then
					result[field] = filter_clangd(result[field])
				end
			end
			return orig(err, result, ctx, ...)
		end
	end
	wrap("textDocument/publishDiagnostics", "diagnostics") -- push
	wrap("textDocument/diagnostic", "items") -- pull
end

-- ---------------------------------------------------------------------------
-- Buffer attach / autocmds
-- ---------------------------------------------------------------------------
local function maybe_compdb(ws)
	if ws.compdb_checked then
		return
	end
	ws.compdb_checked = true
	if config.options.compdb.auto_generate and not workspace.exists(ws.root .. "/compile_commands.json") then
		build.notify("generating compile_commands.json ...")
		compdb.generate(ws, nil, function(ok, res)
			build.notify(ok and ("compile_commands.json: %d entries"):format(res) or res,
				ok and vim.log.levels.INFO or vim.log.levels.WARN)
		end)
	end
end

local function attach(bufnr)
	local ws = current_ws(bufnr)
	if not ws then
		return
	end
	store.ensure(ws)
	store.publish_buf(ws, bufnr)
	local ft = vim.bo[bufnr].filetype
	if ft == "c" or ft == "cpp" or ft == "objc" or ft == "objcpp" or ft == "cuda" then
		maybe_compdb(ws)
	end
end

local function on_save(args)
	if not M.enabled or not config.options.build_on_save then
		return
	end
	if not vim.tbl_contains(config.options.filetypes, vim.bo[args.buf].filetype) then
		return
	end
	local ws, name = current_ws(args.buf)
	if not ws then
		return
	end
	if workspace.is_build_file(name) then
		build.invalidate_owners(ws) -- target ownership may have changed
		if config.options.compdb.regenerate_on_build_change then
			compdb.generate(ws)
		end
	end
	build.schedule_file(ws, workspace.realpath(name))
end

-- ---------------------------------------------------------------------------
-- :BazelGcc
-- ---------------------------------------------------------------------------
local commands = {}

function commands.build(ws, args, file)
	if #args > 0 then
		build.build(ws, args)
	else
		build.build_file(ws, file)
	end
end

function commands.compdb(ws, args)
	compdb.generate(ws, args, function(ok, res)
		build.notify(ok and ("compile_commands.json: %d entries"):format(res) or res,
			ok and vim.log.levels.INFO or vim.log.levels.ERROR)
	end)
end

function commands.qf(ws)
	vim.fn.setqflist({}, " ", { title = "bazel-gcc " .. ws.name, items = store.qf_items(ws) })
	vim.cmd("botright copen")
end

function commands.log(ws)
	if not ws.log then
		return build.notify("no build yet")
	end
	vim.cmd("botright new")
	local b = vim.api.nvim_get_current_buf()
	vim.bo[b].buftype, vim.bo[b].bufhidden, vim.bo[b].swapfile = "nofile", "wipe", false
	vim.api.nvim_buf_set_lines(b, 0, -1, false, ws.log)
	vim.bo[b].modifiable = false
	vim.api.nvim_buf_set_name(b, "bazel-gcc://log/" .. ws.name .. "/" .. b)
end

function commands.clear(ws)
	store.clear(ws)
	store.publish(ws)
end

function commands.pin(ws, args, file)
	if #args > 0 then
		ws.pinned = args
		build.notify("pinned " .. table.concat(args, " "))
	else
		build.owners(ws, file, function(t)
			ws.pinned = t
			build.notify("pinned " .. table.concat(t, " "))
		end)
	end
end

function commands.unpin(ws)
	ws.pinned = nil
	build.notify("unpinned")
end

function commands.toggle()
	M.enabled = not M.enabled
	build.notify("build on save " .. (M.enabled and "enabled" or "disabled"))
end

function commands.targets(ws, _, file)
	build.owners(ws, file, function(t)
		build.notify(("%s -> %s"):format(vim.fs.basename(file), #t > 0 and table.concat(t, " ") or "(none)"))
	end)
end

function commands.info(ws)
	local l = ws.last
	local lines = {
		"root:      " .. ws.root,
		"execroot:  " .. (ws.info and ws.info.execution_root or "?"),
		"pinned:    " .. (ws.pinned and table.concat(ws.pinned, " ") or "-"),
		"running:   " .. (ws.running and table.concat(ws.running_targets or {}, " ") or "no"),
		"last:      " .. (l and ("%s %s (%d actions ran, %dE %dW, %.1fs)"):format(
			l.exit, table.concat(l.targets, " "), l.ran, l.errors, l.warnings, l.seconds) or "-"),
	}
	build.notify(table.concat(lines, "\n"))
end

local function complete(arglead, line)
	local words = vim.split(line, "%s+")
	if #words <= 2 then
		return vim.tbl_filter(function(c)
			return c:find(arglead, 1, true) == 1
		end, vim.tbl_keys(commands))
	end
	return {}
end

-- ---------------------------------------------------------------------------
function M.setup(opts)
	config.setup(opts)
	wrap_clangd_handlers()

	local group = vim.api.nvim_create_augroup("bazel-gcc", { clear = true })
	vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile", "FileType" }, {
		group = group,
		callback = function(a)
			attach(a.buf)
		end,
	})
	vim.api.nvim_create_autocmd("BufWritePost", { group = group, callback = on_save })

	vim.api.nvim_create_user_command("BazelGcc", function(a)
		local sub = a.fargs[1] or "build"
		local fn = commands[sub]
		if not fn then
			return build.notify("unknown subcommand: " .. sub, vim.log.levels.ERROR)
		end
		local ws, file = current_ws(0)
		if not ws and sub ~= "toggle" then
			return build.notify("not in a Bazel workspace", vim.log.levels.WARN)
		end
		fn(ws, vim.list_slice(a.fargs, 2), file ~= "" and workspace.realpath(file) or nil)
	end, { nargs = "*", complete = complete, desc = "bazel-gcc: build | compdb | qf | log | clear | pin | unpin | targets | toggle | info" })

	-- Lazy-loading may happen after buffers were already opened.
	for _, b in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(b) then
			attach(b)
		end
	end
end

return M
