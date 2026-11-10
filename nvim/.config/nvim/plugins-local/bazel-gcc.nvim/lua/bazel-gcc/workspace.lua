-- Bazel workspace discovery, `bazel info`, and file -> label mapping.
local config = require("bazel-gcc.config")

local M = {}
local uv = vim.uv

M.markers = { "MODULE.bazel", "WORKSPACE.bazel", "WORKSPACE", "REPO.bazel" }

---@type table<string, table> root -> workspace state
M.by_root = {}

function M.realpath(path)
	return uv.fs_realpath(path) or vim.fs.normalize(path)
end

local function exists(path)
	return uv.fs_stat(path) ~= nil
end
M.exists = exists

local function relpath(root, path)
	if path == root then
		return ""
	end
	if path:sub(1, #root + 1) == root .. "/" then
		return path:sub(#root + 2)
	end
end
M.relpath = relpath

--- Workspace for an absolute file path (or nil when the file is not in a Bazel workspace).
function M.get(path)
	if not path or path == "" then
		return nil
	end
	path = M.realpath(path)
	-- Nested list = equal priority: the nearest directory containing any marker wins.
	local root = vim.fs.root(path, { M.markers })
	if not root then
		return nil
	end
	root = M.realpath(root)
	local rel = relpath(root, path)
	-- Ignore Bazel's own output trees and external repos linked into the workspace.
	if rel and (rel:match("^bazel%-") or rel:match("^external/")) then
		return nil
	end
	local ws = M.by_root[root]
	if not ws then
		ws = {
			root = root,
			name = vim.fs.basename(root),
			info = nil, -- { execution_root, output_base }
			info_waiters = nil,
			owners = {}, -- file -> { targets }
			running = nil, -- vim.SystemObj of the current build
			pending = nil, -- set of targets for the next build
			last = nil, -- summary of the last build
		}
		M.by_root[root] = ws
	end
	return ws
end

-- Hand the result of `bazel info` to every queued caller.
local function release_info_waiters(ws, info, err)
	local waiters = ws.info_waiters
	ws.info_waiters = nil
	for _, w in ipairs(waiters) do
		w(info, err)
	end
end

--- Run `bazel info` once per workspace; calls cb(info|nil, err) on the main loop.
function M.info(ws, cb)
	if ws.info then
		return cb(ws.info)
	end
	if ws.info_waiters then
		table.insert(ws.info_waiters, cb)
		return
	end
	ws.info_waiters = { cb }
	local cmd = config.bazel("info", { "execution_root", "output_base" })
	-- vim.system throws when the executable cannot be spawned; release the waiters
	-- so later calls retry instead of queueing forever.
	local ok, spawn_err = pcall(vim.system, cmd, { cwd = ws.root, text = true }, function(res)
		vim.schedule(function()
			local info, err = {}, nil
			if res.code == 0 then
				for line in res.stdout:gmatch("[^\n]+") do
					local k, v = line:match("^(%S+): (.+)$")
					if k then
						info[k] = v
					end
				end
			end
			if not info.execution_root then
				info, err = nil, ("bazel info failed: %s"):format(vim.trim(res.stderr or ""))
			end
			ws.info = info
			release_info_waiters(ws, info, err)
		end)
	end)
	if not ok then
		release_info_waiters(ws, nil, ("cannot run %s: %s"):format(cmd[1], spawn_err))
	end
end

--- Nearest package (directory with a BUILD file) for a file; returns pkg, name.
function M.package_of(ws, file)
	file = M.realpath(file)
	local dir = vim.fs.dirname(file)
	while dir and relpath(ws.root, dir) do
		if exists(dir .. "/BUILD.bazel") or exists(dir .. "/BUILD") then
			return relpath(ws.root, dir), relpath(dir, file)
		end
		if dir == ws.root then
			break
		end
		dir = vim.fs.dirname(dir)
	end
end

--- Source label of a file, e.g. //lib:greet.cc (nil outside any package).
function M.label(ws, file)
	local pkg, name = M.package_of(ws, file)
	if pkg then
		return ("//%s:%s"):format(pkg, name), pkg
	end
end

function M.is_build_file(path)
	local base = vim.fs.basename(path)
	return base == "BUILD" or base == "BUILD.bazel" or base == "MODULE.bazel" or base == "WORKSPACE"
		or base == "WORKSPACE.bazel" or base:match("%.bzl$") ~= nil
end

--- Map a path printed by GCC / Bazel (usually execroot-relative) to a real file path.
function M.resolve(ws, p)
	p = p:gsub("^.-/sandbox/[^/]+/%d+/execroot/[^/]+/", "") -- path inside a sandbox
	p = p:gsub("^/proc/self/cwd/", "")
	if p:sub(1, 1) == "/" then
		return M.realpath(p)
	end
	p = p:gsub("^%./", "")
	local in_ws = ws.root .. "/" .. p
	if exists(in_ws) then
		return M.realpath(in_ws)
	end
	local execroot = ws.info and ws.info.execution_root
	if execroot and exists(execroot .. "/" .. p) then
		return M.realpath(execroot .. "/" .. p)
	end
	return vim.fs.normalize(in_ws)
end

return M
