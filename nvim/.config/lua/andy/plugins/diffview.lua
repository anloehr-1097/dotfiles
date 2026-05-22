return {
	"sindrets/diffview.nvim",
	config = function()
		vim.keymap.set("n", "<leader>go", "<cmd>DiffviewOpen<cr>")
		vim.keymap.set("n", "<leader>gc", "<cmd>DiffviewClose<cr>")
		-- if Diffview open, close with same command
	end,
}
