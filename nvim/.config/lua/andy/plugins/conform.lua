return {
	"stevearc/conform.nvim",
	opts = {},
	config = function()
		require("conform").setup({
			formatters_by_ft = {
				lua = { "stylua" },
				json = { "jq" },
				python = { "ruff" },
				cpp = { "clang-format", "cpplint" },
			},
		})
		vim.api.nvim_create_autocmd("BufWritePre", {
			group = vim.api.nvim_create_augroup("Conform", { clear = true }),
			pattern = "*",
			callback = function()
				require("conform").format()
			end,
		})
	end,
}
