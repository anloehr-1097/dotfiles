return {
	"yetone/avante.nvim",
	-- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
	-- ⚠️ must add this setting! ! !
	build = vim.fn.has("win32") ~= 0 and "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false"
		or "make",
	event = "VeryLazy",
	version = false, -- Never set this value to "*"! Never!
	---@module 'avante'
	---@type avante.Config
	opts = {
		-- add any opts here
		-- this file can contain specific instructions for your project
		instructions_file = "avante.md",
		-- for example
		provider = "copilot/claude-sonnet",
		mode = "agentic",
		auto_suggestions_provider = "copilot/gpt-5-mini",
		providers = {
			["copilot/claude-sonnet"] = {
				__inherited_from = "copilot",
				model = "claude-sonnet-4.5",
				display_name = "copilot/claude-sonnet",
				timeout = 30000, -- Timeout in milliseconds
				extra_request_body = {
					temperature = 0.75,
					max_tokens = 20480,
				},
			},
			["copilot/gemini-3-pro"] = {
				__inherited_from = "copilot",
				model = "gemini-3-pro-preview",
				display_name = "copilot/gemini-3-pro",
				timeout = 30000, -- Timeout in milliseconds
				extra_request_body = {
					temperature = 0.75,
					max_tokens = 5000,
				},
			},
			["copilot/gpt-5-mini"] = {
				__inherited_from = "copilot",
				model = "gpt-5-mini",
				display_name = "copilot/gpt-5-mini",
				timeout = 30000, -- Timeout in milliseconds
				extra_request_body = {
					temperature = 0.75,
					max_tokens = 20480,
				},
			},
		},
		behaviour = {
			auto_approve_tool_permissions = false,
		},
	},
	dependencies = {
		"nvim-lua/plenary.nvim",
		"MunifTanjim/nui.nvim",
		"nvim-telescope/telescope.nvim", -- for file_selector provider telescope
		"hrsh7th/nvim-cmp", -- autocompletion for avante commands and mentions
		"ibhagwan/fzf-lua", -- for file_selector provider fzf
		"github/copilot.vim", -- for providers='copilot'
		-- "zbirenbaum/copilot.lua", -- for providers='copilot'
		{
			-- support for image pasting
			"HakonHarnes/img-clip.nvim",
			event = "VeryLazy",
			opts = {
				-- recommended settings
				default = {
					embed_image_as_base64 = false,
					prompt_for_file_name = false,
					drag_and_drop = {
						insert_mode = true,
					},
					-- required for Windows users
					use_absolute_path = true,
				},
			},
		},
		{
			-- Make sure to set this up properly if you have lazy=true
			"MeanderingProgrammer/render-markdown.nvim",
			opts = {
				file_types = { "markdown", "Avante" },
			},
			ft = { "markdown", "Avante" },
		},
	},
}
