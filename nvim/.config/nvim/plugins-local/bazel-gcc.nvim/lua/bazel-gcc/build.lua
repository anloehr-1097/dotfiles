-- Background builds and target discovery.
local config = require("bazel-gcc.config")
local workspace = require("bazel-gcc.workspace")
local store = require("bazel-gcc.store")
local bep = require("bazel-gcc.bep")

local M = {}

local function notify(msg, level)
	vim.notify("bazel-gcc: " .. msg, level or vim.log.levels.INFO, { title = "bazel-gcc" })
end
M.notify = notify

local function emit(pattern, data)
	vim.api.nvim_exec_autocmds("User", { pattern = pattern, data = data, modeline = false })
end

--- Rules that directly list `file` in srcs/hdrs/... (cached until a BUILD file changes).
--- cb(targets) — an empty list when nothing owns the file.
function M.owners(ws, file, cb)
	file = workspace.realpath(file)
	if ws.owners[file] then
		return cb(ws.owners[file])
	end
	local label, pkg = workspace.label(ws, file)
	if not label then
		return cb({})
	end
	local function fallback()
		if config.options.fallback == "package" then
			return { ("//%s:all"):format(pkg) }
		end
		return {}
	end
	if workspace.is_build_file(file) then
		ws.owners[file] = fallback()
		return cb(ws.owners[file])
	end
	local word = config.query_word(label)
	if not word then
		return cb(fallback())
	end
	local expr = ("kind(rule, same_pkg_direct_rdeps(%s))"):format(word)
	local cmd = config.bazel("query", { expr, "--output=label", "--keep_going", "--ui_event_filters=-info", "--noshow_progress" })
	-- A BUILD-file save replaces ws.owners and bumps the generation; a query that started
	-- before that answered for the old BUILD files and must not be cached.
	local gen = ws.owners_gen
	local ok, spawn_err = pcall(vim.system, cmd, { cwd = ws.root, text = true }, function(res)
		vim.schedule(function()
			local targets = {}
			for line in (res.stdout or ""):gmatch("[^\n]+") do
				if line:match("^//") or line:match("^@") then
					table.insert(targets, line)
				end
			end
			if #targets == 0 and res.code ~= 0 then
				-- A failed query says nothing about ownership: report it and don't cache.
				local msg = vim.trim(res.stderr or ""):match("[^\n]*$") or ""
				notify("owners query failed: " .. msg, vim.log.levels.WARN)
				return cb(fallback())
			end
			if #targets == 0 then
				targets = fallback()
			end
			if ws.owners_gen == gen then
				ws.owners[file] = targets
			end
			cb(targets)
		end)
	end)
	if not ok then
		notify(("cannot run %s: %s"):format(cmd[1], spawn_err), vim.log.levels.ERROR)
		cb(fallback())
	end
end

--- Forget which targets own which files (a BUILD file changed).
function M.invalidate_owners(ws)
	ws.owners = {}
	ws.owners_gen = (ws.owners_gen or 0) + 1
end

local function set_to_list(set)
	local l = vim.tbl_keys(set)
	table.sort(l)
	return l
end

local start -- forward declaration

local function finish(ws, res, bep_path, targets, t0)
	ws.running = nil
	local events = bep.read(bep_path)
	os.remove(bep_path)
	local update = bep.extract(ws, events)
	for key, diags in pairs(update.actions) do
		store.set_action(ws, key, diags)
	end
	-- bazel's own messages are re-reported by every build that gets as far as analysis. A
	-- build that never reached BuildFinished (failed to start, killed by an interrupt) says
	-- nothing about them, so keep what we had instead of wiping the BUILD diagnostics.
	local incomplete = events.exit == nil and res.code ~= 0
	if not incomplete then
		store.set_bazel(ws, update.bazel)
	end
	store.save(ws)
	store.publish(ws)

	-- Keep the console output around for :BazelGcc log
	ws.log = vim.split((res.stdout or "") .. (res.stderr or ""), "\n", { trimempty = true })

	-- proto3 JSON omits zero values, so SUCCESS arrives without a `code` field.
	local exit = events.exit or { name = res.code == 0 and "SUCCESS" or "UNKNOWN" }
	local errors, warnings = store.counts(ws)
	ws.last = {
		ok = exit.name == "SUCCESS",
		exit = exit.name,
		targets = targets,
		ran = update.ran,
		failed = update.failed,
		errors = errors,
		warnings = warnings,
		seconds = (vim.uv.hrtime() - t0) / 1e9,
	}
	local n = config.options.notify
	local summary = ("%s %s: %d error(s), %d warning(s), %d action(s) ran, %.1fs"):format(
		ws.last.ok and "OK" or "FAILED", table.concat(targets, " "), errors, warnings, update.ran, ws.last.seconds)
	if n == "always" or (n == "failures" and not ws.last.ok) then
		local msg = summary
		if not ws.last.ok and (errors == 0 or incomplete) then
			msg = msg .. " (see :BazelGcc log)"
		end
		notify(msg, ws.last.ok and vim.log.levels.INFO or vim.log.levels.WARN)
	end
	emit("BazelGccBuildDone", { root = ws.root, last = ws.last })
	vim.cmd.redrawstatus({ bang = true })

	if ws.pending then
		local next_targets = set_to_list(ws.pending)
		ws.pending = nil
		start(ws, next_targets)
	end
end

start = function(ws, targets)
	if #targets == 0 then
		return
	end
	-- Mark the workspace busy now: workspace.info can be async, and M.build must
	-- queue into ws.pending instead of starting a second build meanwhile.
	ws.starting = true
	workspace.info(ws, function(info, err)
		ws.starting = nil
		if not info then
			-- Builds queued meanwhile would fail the same way; the next save queues anew.
			ws.pending = nil
			return notify(err or "bazel info failed", vim.log.levels.ERROR)
		end
		local o = config.options
		local bep_path = vim.fn.tempname() .. "-bep.json"
		local args = {
			"--build_event_json_file=" .. bep_path,
			"--build_event_publish_all_actions",
			"--keep_going",
			"--color=no",
			"--curses=no",
		}
		vim.list_extend(args, o.bazel_args)
		vim.list_extend(args, o.build_args)
		if o.compile_only then
			table.insert(args, "--output_groups=compilation_outputs")
		end
		table.insert(args, "--")
		vim.list_extend(args, targets)

		local t0 = vim.uv.hrtime()
		local cmd = config.bazel("build", args)
		local ok, proc = pcall(vim.system, cmd, { cwd = ws.root, text = true }, function(res)
			vim.schedule(function()
				finish(ws, res, bep_path, targets, t0)
			end)
		end)
		if not ok then
			ws.pending = nil
			return notify(("cannot run %s: %s"):format(cmd[1], proc), vim.log.levels.ERROR)
		end
		emit("BazelGccBuildStart", { root = ws.root, targets = targets })
		ws.running = proc
		ws.running_targets = targets
		vim.cmd.redrawstatus({ bang = true })
	end)
end

--- Build targets now, or queue them when a build is already running.
function M.build(ws, targets)
	if ws.running or ws.starting then
		ws.pending = ws.pending or {}
		for _, t in ipairs(targets) do
			ws.pending[t] = true
		end
		if ws.running and config.options.interrupt then
			ws.running:kill("sigint")
		end
		return
	end
	start(ws, targets)
end

--- Build whatever owns `file` (or the pinned targets).
function M.build_file(ws, file)
	if ws.pinned and #ws.pinned > 0 then
		return M.build(ws, ws.pinned)
	end
	M.owners(ws, file, function(targets)
		if #targets == 0 then
			return
		end
		M.build(ws, targets)
	end)
end

-- Debounced on-save trigger: saves within debounce_ms are merged into one build.
local timers = {}
function M.schedule_file(ws, file)
	ws.save_queue = ws.save_queue or {}
	ws.save_queue[file] = true
	local t = timers[ws.root]
	if not t then
		t = vim.uv.new_timer()
		timers[ws.root] = t
	end
	t:stop()
	t:start(config.options.debounce_ms, 0, vim.schedule_wrap(function()
		local files = vim.tbl_keys(ws.save_queue or {})
		ws.save_queue = nil
		if ws.pinned and #ws.pinned > 0 then
			return M.build(ws, ws.pinned)
		end
		local all, left = {}, #files
		for _, f in ipairs(files) do
			M.owners(ws, f, function(targets)
				for _, x in ipairs(targets) do
					all[x] = true
				end
				left = left - 1
				if left == 0 and next(all) then
					M.build(ws, set_to_list(all))
				end
			end)
		end
	end))
end

return M
