-- Parser names (what nvim-treesitter installs)
local parsers = {
	"rust",
	"lua",
	"python",
	"c",
	"cpp",
	"bash",
	"fish",
	"javascript",
	"typescript",
	"tsx",
	"json",
	"yaml",
	"toml",
	"markdown",
	"markdown_inline",
	"vim",
	"vimdoc",
	"query",
	"regex",
}

-- Filetypes to attach treesitter to (differs from parser names for several langs)
local filetypes = {
	"rust",
	"lua",
	"python",
	"c",
	"cpp",
	"sh",
	"bash",
	"fish",
	"javascript",
	"javascriptreact",
	"typescript",
	"typescriptreact",
	"json",
	"yaml",
	"toml",
	"markdown",
	"vim",
	"help",
	"query",
}

return {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	lazy = false,
	build = ":TSUpdate",
	config = function()
		require("nvim-treesitter").install(parsers)

		vim.api.nvim_create_autocmd("FileType", {
			pattern = filetypes,
			callback = function()
				vim.treesitter.start()
				vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
			end,
		})
	end,
}
