return {
	{
		"mrcjkb/rustaceanvim",
		version = "^6",
		lazy = false, -- this plugin is already lazy via ft
		ft = { "rust" },
		config = function()
			local capabilities = require("cmp_nvim_lsp").default_capabilities()

			-- Best-effort codelldb detection: if `codelldb` isn't on your PATH,
			-- rustaceanvim just won't offer :RustLsp debug (no error either way).
			-- Install codelldb (e.g. from the vscode-lldb release, or via mason
			-- if you add mason.nvim) and this wires itself up automatically.
			local function codelldb_dap_config()
				local codelldb_path = vim.fn.exepath("codelldb")
				if codelldb_path == "" then
					return nil
				end
				-- Typical vscode-lldb extension bundle layout: adapter/codelldb
				-- next to a lldb/lib/liblldb.* next to it. Adjust if yours differs.
				local extension_root = vim.fn.fnamemodify(codelldb_path, ":h:h")
				local liblldb_path = extension_root .. "/lldb/lib/liblldb.dylib"
				local ok, cfg = pcall(function()
					return require("rustaceanvim.config").get_codelldb_adapter(codelldb_path, liblldb_path)
				end)
				if ok then
					return cfg
				end
				return nil
			end

			vim.g.rustaceanvim = {
				tools = {
					hover_actions = { auto_focus = true },
				},
				server = {
					capabilities = capabilities,
					default_settings = {
						["rust-analyzer"] = {
							imports = {
								granularity = { group = "module" },
								prefix = "self",
							},
							cargo = {
								buildScripts = { enable = true },
								features = "all",
							},
							procMacro = { enable = true },
							checkOnSave = true,
							check = { command = "clippy" },
							lens = {
								enable = true,
								run = { enable = true },
								debug = { enable = true },
								references = {
									adt = { enable = true },
									method = { enable = true },
								},
							},
						},
					},
				},
				dap = { adapter = codelldb_dap_config() },
			}
		end,
	},
	{
		"saecki/crates.nvim",
		event = { "BufRead Cargo.toml" },
		opts = {
			completion = {
				cmp = { enabled = true },
			},
			lsp = {
				enabled = true,
				actions = true,
				completion = true,
				hover = true,
			},
		},
	},
}
