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

-- Pin parsers whose latest commit is incompatible with the highlight
-- queries bundled with nvim-treesitter/Neovim (wait for upstream to catch
-- up before bumping these).
local pinned_revisions = {
	-- known-good: includes the "apply operator field to binary/unary
	-- expressions" fix that the bundled highlights.scm query requires.
	lua = "10fe0054734eec83049514ea2e718b2a56acd0c9",
}

return {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	lazy = false,
	build = ":TSUpdate",
	config = function()
		vim.api.nvim_create_autocmd("User", {
			pattern = "TSUpdate",
			callback = function()
				local parser_configs = require("nvim-treesitter.parsers")
				for lang, revision in pairs(pinned_revisions) do
					parser_configs[lang].install_info.revision = revision
				end
			end,
		})

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
