-- Build Event Protocol (JSON) ingestion.
local parser = require("bazel-gcc.parser")
local workspace = require("bazel-gcc.workspace")

local M = {}

local function read_file(path)
	local f = path and io.open(path, "r")
	if not f then
		return nil
	end
	local s = f:read("*a")
	f:close()
	return s
end

--- Parse a BEP JSON file into { actions = {...}, progress = string, exit = {name, code} }.
function M.read(path)
	local res = { actions = {}, progress = {}, exit = nil }
	local f = io.open(path, "r")
	if not f then
		return res
	end
	for line in f:lines() do
		local ok, ev = pcall(vim.json.decode, line, { luanil = { object = true, array = true } })
		if ok and type(ev) == "table" and ev.id then
			if ev.id.actionCompleted and ev.action then
				local a = ev.action
				local id = ev.id.actionCompleted
				table.insert(res.actions, {
					key = (id.primaryOutput or "?") .. "|" .. ((id.configuration or {}).id or ""),
					primary_output = id.primaryOutput,
					label = id.label or a.label,
					mnemonic = a.type,
					success = a.success == true, -- proto3 JSON omits `false`
					exit_code = a.exitCode,
					stderr_uri = a.stderr and a.stderr.uri,
					argv = a.commandLine,
				})
			elseif ev.progress then
				if ev.progress.stderr then
					table.insert(res.progress, ev.progress.stderr)
				end
			elseif ev.id.buildFinished and ev.finished then
				res.exit = ev.finished.exitCode or { name = "SUCCESS", code = 0 }
			end
		end
	end
	f:close()
	res.progress = table.concat(res.progress)
	return res
end

--- Turn a parsed BEP stream into store updates.
--- Returns { actions = { [key] = diags }, bazel = diags, ran = n, failed = n }.
function M.extract(ws, bep)
	local blocks = parser.split_blocks(bep.progress)

	-- Console output per action subject, used when an action's stderr file is gone (it lives
	-- in bazel-out/_tmp and is reused by the next invocation).
	local console = {}
	for _, b in ipairs(blocks) do
		local subj = parser.block_subject(b.header)
		if subj then
			console[subj] = table.concat(b.body, "\n")
		end
	end

	local out = { actions = {}, bazel = {}, ran = 0, failed = 0 }
	local had_errors = {} -- action subjects whose own output produced an error diagnostic
	for _, a in ipairs(bep.actions) do
		if a.mnemonic ~= "BazelWorkspaceStatusAction" then
			out.ran = out.ran + 1
			if not a.success then
				out.failed = out.failed + 1
			end
			local src = parser.compiled_source(a.argv)
			local short = a.primary_output and a.primary_output:gsub("^bazel%-out/[^/]+/bin/", "")
			local text = a.stderr_uri and read_file(vim.uri_to_fname(a.stderr_uri))
			if not text or text == "" then
				text = (src and console[src]) or (short and console[short]) or ""
			end
			local diags = parser.parse_gcc(text)
			for _, d in ipairs(diags) do
				d.path = workspace.resolve(ws, d.path)
				if d.severity == "error" then
					if src then
						had_errors[src] = true
					end
					if short then
						had_errors[short] = true
					end
				end
			end
			out.actions[a.key] = diags
		end
	end

	-- Bazel's own located messages (analysis errors, missing deps, failed links, ...).
	for _, b in ipairs(blocks) do
		if b.level == "ERROR" or b.level == "WARNING" then
			local loc = parser.located(b.header)
			local subj, failed = parser.block_subject(b.header)
			-- An action failure whose compiler output we already turned into diagnostics
			-- would only duplicate them on the BUILD file.
			local redundant = failed and subj and had_errors[subj]
			if loc and not redundant then
				local msg = loc.message
				if failed then
					msg = msg:gsub(": %(Exit %d+%).*$", ""):gsub(": error executing .*$", "")
					-- Keep a little of the tool output (e.g. "undefined reference to ...").
					local extra = {}
					for _, l in ipairs(b.body) do
						if #extra >= 6 then
							break
						end
						if not l:match("^Use %-%-") and not l:match("^%s*$") then
							table.insert(extra, l)
						end
					end
					if #extra > 0 then
						msg = msg .. "\n" .. table.concat(extra, "\n")
					end
				elseif #b.body > 0 then
					msg = msg .. "\n" .. table.concat(vim.list_slice(b.body, 1, 8), "\n")
				end
				table.insert(out.bazel, {
					path = workspace.resolve(ws, loc.path),
					lnum = loc.lnum,
					col = loc.col,
					severity = b.level == "ERROR" and "error" or "warning",
					message = msg,
					source = "bazel",
				})
			end
		end
	end
	return out
end

return M
