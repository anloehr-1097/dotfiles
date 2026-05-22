return {
	{
		"mfussenegger/nvim-dap",
		config = function(_, opts)
			local opts_map = { noremap = true, silent = true }
			local on_attach = function(client, bufnr)
				local keymap = vim.keymap
				opts.buffer = bufnr

				-- set keybinds
				opts_map.desc = "Set denbugging breakpoint"
				keymap.set("n", "<leader>db", "<cmd> DapToggleBreakpoint <CR>", opts_map)
				keymap.set("n", "<leader>ds", "<cmd> DapContinue <CR>", opts_map)
			end
		end,
	},
}
