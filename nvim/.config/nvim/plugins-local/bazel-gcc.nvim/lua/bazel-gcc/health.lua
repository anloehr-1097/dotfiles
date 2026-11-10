local M = {}

function M.check()
	local h = vim.health
	local config = require("bazel-gcc.config").options
	h.start("bazel-gcc")
	for _, exe in ipairs({ config.bazel_cmd, "gcc", "clangd" }) do
		if vim.fn.executable(exe) == 1 then
			h.ok(exe .. ": " .. vim.fn.exepath(exe))
		else
			(exe == "clangd" and h.warn or h.error)(exe .. " not found on $PATH")
		end
	end
	-- :checkhealth opens its own buffer; inspect the buffer the user came from.
	local buf = vim.fn.bufnr("#")
	if buf <= 0 or not vim.api.nvim_buf_is_valid(buf) then
		buf = 0
	end
	local ws = require("bazel-gcc.workspace").get(vim.api.nvim_buf_get_name(buf))
	if not ws then
		h.info("current buffer is not in a Bazel workspace")
		return
	end
	h.ok("workspace: " .. ws.root)
	if vim.uv.fs_stat(ws.root .. "/compile_commands.json") then
		h.ok("compile_commands.json present")
	else
		h.warn("no compile_commands.json (run :BazelGcc compdb)")
	end
	local clients = vim.lsp.get_clients({ name = "clangd", bufnr = buf })
	if #clients == 0 then
		h.warn("clangd not attached to this buffer")
	else
		local cmd = table.concat(clients[1].config.cmd or {}, " ")
		if cmd:find("--query-driver", 1, true) then
			h.ok("clangd: " .. cmd)
		else
			h.warn("clangd runs without --query-driver; it will not find GCC's libstdc++ headers")
		end
	end
end

return M
