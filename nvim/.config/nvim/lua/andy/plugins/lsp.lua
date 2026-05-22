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
			capabilities = {
				textDocument = {
					semanticTokens = {
						multilineTokenSupport = true,
					},
				},
                general = {
                    positionEncodings = { 'utf-16' },  -- Enforce utf-16 for consistency
                },
			},
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
				".git",
			},

			cmd = { "clangd", "--background-index", 
					"--clang-tidy",
					"--header-insertion=iwyu",
					"--query-driver=**/*gcc*,**/*g++*" }, -- Base command, will be modified
			on_new_config = function(new_config, new_root_dir)
				-- Standard clangd args. The --query-driver flag is critical for cross-compilers
				-- (like ESP-IDF xtensa): it allows clangd to extract standard library paths (like <string>) 
				local cmd_list = {
					"clangd",
					"--background-index",
					"--clang-tidy",
					"--header-insertion=iwyu",
					"--query-driver=**/*gcc*,**/*g++*",
				}

				local is_esp = false
				if new_root_dir then
					is_esp = vim.fn.filereadable(new_root_dir .. "/sdkconfig") == 1 or
							 vim.fn.filereadable(new_root_dir .. "/.esp-idf") == 1 or
							 vim.fn.glob(new_root_dir .. "/**/idf_component.yml", 0, 1) ~= ""
				end

				if is_esp then
					local ok, esp32 = pcall(require, "esp32")
					if ok and type(esp32.find_esp_clangd) == "function" then
						local esp_clangd = esp32.find_esp_clangd()
						if esp_clangd and vim.fn.executable(esp_clangd) == 1 then
							cmd_list[1] = esp_clangd
						end
					end
				end

				new_config.cmd = cmd_list
			end,
		})
		vim.lsp.enable("clangd")

		-- Python (pylsp from main)
		vim.lsp.config("pylsp", {
            enabled = false,
			name = "pylsp",
			-- cmd_cwd = py_path,
			cmd = { "pylsp" },
			filetypes = { "python" },
			capabilities = capabilities,
			root_dir = vim.fs.root(0, { ".git", "pyproject.toml", "setup.py" }),
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
							print("Using python executable for mypy: " .. py_path),
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
			name = "ruff",
			cmd = { "ruff", "server" },
			filetypes = { "python" },
			root_dir = vim.fs.root(0, { ".git", "pyproject.toml", "setup.py" }),
			root_markers = { "pyproject.toml", ".git" },
			settings = {},
		})
		vim.lsp.enable("ruff")

		-- Python (ruff_lsp from main)
        vim.lsp.config('ruff_lsp', {
          init_options = {
            settings = {
              -- Any extra CLI arguments for `ruff` go here.
              args = {},
            }
          }
        })
        vim.lsp.enable('ruff_lsp')

        vim.lsp.config('fish-lsp', {
            cmd = { 'fish-lsp', 'start' },
            filetype = 'fish',
            }
        )
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

        -- Optional: Only required if you need to update the language server settings
        vim.lsp.config('ty', {})
        -- Required: Enable the language server
        vim.lsp.enable('ty')


		-- Global diagnostics keybindings (from arch)
		vim.keymap.set("n", "<space>e", vim.diagnostic.open_float)
		vim.keymap.set("n", "gl", "<cmd>lua vim.diagnostic.open_float()<cr>")
		vim.keymap.set("n", "[d", "<cmd>lua vim.diagnostic.goto_prev()<cr>")
		vim.keymap.set("n", "]d", "<cmd>lua vim.diagnostic.goto_next()<cr>")
		vim.keymap.set("n", "<space>q", vim.diagnostic.setloclist)

		-- Buffer-local LspAttach keybindings (from arch)
		vim.api.nvim_create_autocmd("LspAttach", {
			desc = "LSP actions",
			callback = function(event)
				local opts = { buffer = event.buf }

				vim.bo[event.buf].omnifunc = "v:lua.vim.lsp.omnifunc"

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
        vim.api.nvim_create_autocmd('FileType', {
            pattern = 'fish',
            callback = function()
                vim.lsp.start({
                    name = 'fish-lsp',
                    cmd = { 'fish-lsp', 'start' },
                })
            end,
        })


	end,
}
