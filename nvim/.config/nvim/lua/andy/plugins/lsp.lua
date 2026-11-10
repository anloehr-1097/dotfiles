return {
	"neovim/nvim-lspconfig",
	event = { "BufReadPre", "BufNewFile" },
	dependencies = {
		"hrsh7th/nvim-cmp",
		"hrsh7th/cmp-nvim-lsp",
		"hrsh7th/cmp-buffer",
		"hrsh7th/cmp-path",
		"hrsh7th/cmp-cmdline",
		{ "antosha417/nvim-lsp-file-operations", config = true },
	},
	config = function()
		-- basic completion setup
		local cmp = require("cmp")
		cmp.setup({
			snippet = {
				expand = function(args)
					require("luasnip").lsp_expand(args.body) -- For LuaSnip users
				end,
			},
			mapping = cmp.mapping.preset.insert({
				["<C-b>"] = cmp.mapping.scroll_docs(-4),
				["<C-f>"] = cmp.mapping.scroll_docs(4),
				["<C-Space>"] = cmp.mapping.complete(),
				["<C-e>"] = cmp.mapping.abort(),
				["<CR>"] = cmp.mapping.confirm({ select = true }),
			}),
			sources = {
				{ name = "nvim_lsp" },
				{ name = "buffer" },
			},
		})
		vim.opt.completeopt = { "menu", "menuone", "noselect" }

		local capabilities = require("cmp_nvim_lsp").default_capabilities()

        capabilities = vim.tbl_deep_extend('force', capabilities, {
            general = {
                positionEncodings = { 'utf-16' },  -- Enforce utf-16 for consistency
            },
            textDocument = {
                semanticTokens = {
                    multilineTokenSupport = true,
                },
            },
        })

		local venv_path = os.getenv("VIRTUAL_ENV")
		local conda_path = os.getenv("CONDA_PREFIX")
		local py_path = nil
		if venv_path ~= nil then
			py_path = venv_path .. "/bin/python3"
		elseif conda_path ~= nil then
			py_path = conda_path .. "/bin/python3"
		else
			py_path = vim.g.python3_host_prog or "/usr/bin/python3"
		end

		-- Global lsp settings
		vim.lsp.config("*", {
			capabilities = capabilities,
			root_markers = { ".git" },
		})

		-- Lua (arch setup)
		vim.lsp.config("lua_ls", {
			cmd = { "lua-language-server" },
			filetypes = { "lua" },
			root_markers = { ".luarc.json", ".luarc.jsonc", ".git" },
			settings = {
				Lua = {
					diagnostics = { globals = { "vim" } },
				},
			},
		})
		vim.lsp.enable("lua_ls")

		-- Clangd setup: cleanly falls back to system clangd or esp32.nvim if applicable (arch setup)
		vim.lsp.config("clangd", {
			filetypes = { "c", "cpp", "objc", "objcpp", "cuda" },
			root_markers = {
				"sdkconfig",
				"idf_component.yml",
				".esp-idf",
				"CMakeLists.txt",
				"compile_commands.json",
				-- Bazel workspaces (bazel-gcc.nvim writes compile_commands.json at this root)
				"MODULE.bazel",
				"WORKSPACE.bazel",
				"WORKSPACE",
				".git",
			},

				local root_dir = vim.fs.root(args.buf, {
					"compile_commands.json",
					".clangd",
					"sdkconfig",
					"idf_component.yml",
					".esp-idf",
					"CMakeLists.txt",
					-- NOTE: .git is intentionally omitted. Git submodules have a
					-- .git *file* (not directory), and vim.fs.root stops at the
					-- first ancestor that contains any marker. Including .git would
					-- cause clangd to root at the submodule directory instead of
					-- the workspace root (where compile_commands.json and .clangd live).
				})

				local cmd = { "clangd", "--background-index", "--clang-tidy", "--header-insertion=iwyu" }

				if root_dir then
					-- Use wrapper script when present (e.g. Bazel + Qt6 + GCC 13 projects)
					local wrapper = root_dir .. "/clangd-wrapper.sh"
					if vim.fn.filereadable(wrapper) == 1 then
						cmd[1] = wrapper
					end

					-- ESP32 projects: prefer the IDF-bundled clangd.
					-- Use cheap shallow checks only — no recursive glob, which would
					-- traverse the entire project tree on every C/C++ buffer open.
					local is_esp = vim.fn.filereadable(root_dir .. "/sdkconfig") == 1
						or vim.fn.filereadable(root_dir .. "/.esp-idf") == 1
						or vim.fn.filereadable(root_dir .. "/idf_component.yml") == 1
					if is_esp then
						local ok, esp32 = pcall(require, "esp32")
						if ok and type(esp32.find_esp_clangd) == "function" then
							local esp_clangd = esp32.find_esp_clangd()
							if esp_clangd and vim.fn.executable(esp_clangd) == 1 then
								cmd[1] = esp_clangd
							end
						end
					end
				end

				-- Optional query-driver override from environment
				local query_driver = os.getenv("CLANGD_QUERY_DRIVER")
				if query_driver then
					table.insert(cmd, "--query-driver=" .. query_driver)
				end

				vim.lsp.start({
					name     = "clangd",
					cmd      = cmd,
					root_dir = root_dir,
					capabilities = capabilities,
				})
			end,
		})

		-- Python (pylsp from main) -- disabled, enable by uncommenting vim.lsp.enable below
		vim.lsp.config("pylsp", {
			cmd = { "pylsp" },
			filetypes = { "python" },
			capabilities = capabilities,
			root_markers = { "pyproject.toml", ".git", "*.lock" },
			settings = {
				pylsp = {
					plugins = {
						black = { enabled = false },
						jedi_completion = {
							enabled = true,
							fuzzy = true,
							include_params = true,
						},
						pylsp_mypy = {
							enabled = true,
							live = true,
							config_sub_paths = { "." },
							overrides = { "--python-executable", py_path, true },
						},
					},
				},
			},
		})
		-- vim.lsp.enable("pylsp")

		-- Python (pyright from main)
        vim.lsp.config("pyright",  {
            settings = {
                pyright = {
                    -- Using Ruff's import organizer
                    disableOrganizeImports = true,
                },
                python = {
                venv_path = ".",
                venv = ".venv"
                },
            },
        })
        vim.lsp.enable("pyright")

		-- Python (ruff from main)
		vim.lsp.config("ruff", {
			cmd = { "ruff", "server" },
			filetypes = { "python" },
			root_markers = { "pyproject.toml", ".git" },
			settings = {},
		})
		vim.lsp.enable("ruff")

        -- Fish
        vim.lsp.config('fish-lsp', {
            cmd = { 'fish-lsp', 'start' },
            filetypes = { 'fish' },
        })
        vim.lsp.enable('fish-lsp')

		-- Bash (bashls from main)
        vim.lsp.config("bashls", {
            cmd = {'bash-language-server', 'start'},
            filetypes = {'bash', 'sh', 'zsh'},
        })
        vim.lsp.enable("bashls")

        vim.lsp.config("tsserver", {
            cmd = {'typescript-language-server', '--stdio'},
            filetypes = {'javascript', 'javascriptreact', 'typescript', 'typescriptreact'},
        })
        vim.lsp.enable("tsserver")

        -- Rust: handled entirely by rustaceanvim (see rust.lua), which manages
        -- its own rust_analyzer client. Do not vim.lsp.enable('rust_analyzer')
        -- here as well or you'll get two LSP clients attached to rust buffers.

		-- Global diagnostics keybindings (from arch)
		vim.keymap.set("n", "<space>e", vim.diagnostic.open_float)
		vim.keymap.set("n", "gl", "<cmd>lua vim.diagnostic.open_float()<cr>")
		vim.keymap.set("n", "[d", "<cmd>lua vim.diagnostic.goto_prev()<cr>")
		vim.keymap.set("n", "]d", "<cmd>lua vim.diagnostic.goto_next()<cr>")
		vim.keymap.set("n", "<space>q", vim.diagnostic.setloclist)
		vim.keymap.set("n", "<space>th", function()
			vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = 0 }), { bufnr = 0 })
		end, { desc = "Toggle inlay hints" })

		-- Buffer-local LspAttach keybindings (from arch)
		vim.api.nvim_create_autocmd("LspAttach", {
			desc = "LSP actions",
			callback = function(event)
				local opts = { buffer = event.buf }

				vim.bo[event.buf].omnifunc = "v:lua.vim.lsp.omnifunc"

				local client = vim.lsp.get_client_by_id(event.data.client_id)
				if client and client:supports_method("textDocument/inlayHint") then
					vim.lsp.inlay_hint.enable(true, { bufnr = event.buf })
				end

				vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
				vim.keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, opts)
				vim.keymap.set("n", "<space>D", vim.lsp.buf.type_definition, opts)
				vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
				vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
				vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
				vim.keymap.set("n", "go", vim.lsp.buf.type_definition, opts)
				vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
				vim.keymap.set("n", "gs", vim.lsp.buf.signature_help, opts)
				vim.keymap.set("n", "<space>rn", vim.lsp.buf.rename, opts)
				vim.keymap.set({ "n", "x" }, "<space>bf", function() vim.lsp.buf.format({ async = true }) end, opts)
				vim.keymap.set({ "n", "v" }, "<space>ca", vim.lsp.buf.code_action, opts)
			end,
		})
	end,
}
