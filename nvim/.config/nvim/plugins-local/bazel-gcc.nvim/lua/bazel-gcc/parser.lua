-- Parsers for GCC diagnostics and Bazel console output. Pure functions (no Neovim state)
-- so they can be unit tested headless.
local M = {}

local SEVERITY = {
	["error"] = "error",
	["fatal error"] = "error",
	["internal compiler error"] = "error",
	["sorry, unimplemented"] = "error",
	["warning"] = "warning",
	["note"] = "note",
}

local function strip_ansi(s)
	return (s:gsub("\27%[[%d;]*[mK]", ""))
end
M.strip_ansi = strip_ansi

--- Parse GCC (or GNU ld / gold) stderr.
--- Returns a list of raw diagnostics:
---   { path, lnum (1-based), col (1-based display column or nil),
---     end_col (1-based inclusive display column or nil), severity, message, code }
--- Notes are folded into the preceding diagnostic's message.
---@param text string
---@return table[]
function M.parse_gcc(text)
	local out = {}
	local last -- last non-note diagnostic, for notes and caret ranges
	local want_caret = false
	for raw in (text or ""):gmatch("[^\r\n]+") do
		local line = strip_ansi(raw)
		local path, lnum, col, sev, msg = line:match("^(.-):(%d+):(%d+): ([%l ,]-): (.*)$")
		if not path then
			path, lnum, sev, msg = line:match("^(.-):(%d+): ([%l ,]-): (.*)$")
			col = nil
		end
		local severity = sev and SEVERITY[sev]
		if severity and path ~= "" and not path:match("^%s") then
			local d = {
				path = path,
				lnum = tonumber(lnum),
				col = col and tonumber(col) or nil,
				severity = severity,
				message = msg,
				code = msg:match("%[(%-W[^%]]+)%]$"),
			}
			if severity == "note" and last then
				local where = ("%s:%d"):format(vim.fs.basename(path), d.lnum)
				last.message = ("%s\n  note (%s): %s"):format(last.message, where, msg)
				want_caret = false
			else
				table.insert(out, d)
				last = d
				want_caret = d.col ~= nil
			end
		elseif want_caret then
			-- Snippet lines:  "    4 |   int x = 42;"  then  "      |       ^~"
			local caret = line:match("^%s*|(.*)$")
			if caret and caret:find("%^") then
				want_caret = false
				local cpos = caret:find("%^")
				local s, e = cpos, cpos
				while s > 1 and caret:sub(s - 1, s - 1):match("[~%^]") do
					s = s - 1
				end
				while caret:sub(e + 1, e + 1):match("[~%^]") do
					e = e + 1
				end
				last.end_col = last.col + (e - cpos)
				last.col = math.max(1, last.col - (cpos - s))
			elseif not line:match("^%s*%d*%s*|") then
				want_caret = false
			end
		end
	end
	return out
end

--- Split Bazel console text (the BEP `progress.stderr` stream) into blocks.
--- Each block: { level = "ERROR"|"WARNING"|"INFO"|..., header = string, body = { lines } }
function M.split_blocks(text)
	local blocks, cur = {}, nil
	for raw in (text or ""):gmatch("[^\r\n]*") do
		local line = strip_ansi(raw)
		local level, header = line:match("^(%u+): (.*)$")
		if level == "ERROR" or level == "WARNING" or level == "INFO" or level == "DEBUG" then
			cur = { level = level, header = header, body = {} }
			table.insert(blocks, cur)
		elseif cur and line ~= "" then
			table.insert(cur.body, line)
		end
	end
	return blocks
end

--- The action a Bazel header line is about, e.g.
---   "From Compiling lib/a.cc:"                      -> "lib/a.cc"
---   "/ws/BUILD:2:10: Compiling app/main.cc failed: ..." -> "app/main.cc", true
---@return string|nil subject, boolean failed
function M.block_subject(header)
	local subj = header:match("^From %u%l+ (%S-):$")
	if subj then
		return subj, false
	end
	subj = header:match("%u%l+ (%S+) failed:")
	if subj then
		return subj, true
	end
end

--- Bazel's own located messages: "ERROR: /abs/BUILD:3:10: message"
---@return table|nil { path, lnum, col, message }
function M.located(header)
	local path, lnum, col, msg = header:match("^(/.-):(%d+):(%d+): (.*)$")
	if not path then
		path, lnum, msg = header:match("^(/.-):(%d+): (.*)$")
	end
	if path then
		return { path = path, lnum = tonumber(lnum), col = col and tonumber(col) or nil, message = msg }
	end
end

--- Source file compiled by a command line (argument after -c).
function M.compiled_source(argv)
	for i, a in ipairs(argv or {}) do
		if a == "-c" and argv[i + 1] then
			return argv[i + 1]
		end
	end
end

--- Convert a 1-based GCC display column into a 0-based byte column of `line`.
--- GCC counts display columns by default (tabs expand to 8, wide chars count 2).
function M.display_to_byte(line, dcol, tabstop)
	if not line or not dcol then
		return math.max((dcol or 1) - 1, 0)
	end
	if not line:find("[\t\128-\255]") then
		return math.min(dcol - 1, #line)
	end
	tabstop = tabstop or 8
	local disp, i = 1, 1
	while i <= #line do
		if disp >= dcol then
			return i - 1
		end
		local b = line:byte(i)
		local len = b < 0x80 and 1 or b < 0xE0 and 2 or b < 0xF0 and 3 or 4
		if b == 9 then
			disp = disp + (tabstop - ((disp - 1) % tabstop))
		elseif len == 1 then
			disp = disp + 1
		else
			disp = disp + vim.fn.strdisplaywidth(line:sub(i, i + len - 1))
		end
		i = i + len
	end
	return #line
end

return M
