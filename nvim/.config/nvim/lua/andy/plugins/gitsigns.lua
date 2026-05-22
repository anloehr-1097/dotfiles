return {
	"lewis6991/gitsigns.nvim",
	event = "BufReadPre",
	opts = {
		signs = {
			add = { text = "┃" },
			change = { text = "┃" },
			delete = { text = "_" },
			topdelete = { text = "‾" },
			changedelete = { text = "~" },
			untracked = { text = "┆" },
		},
		signs_staged = {
			add = { text = "┃" },
			change = { text = "┃" },
			delete = { text = "_" },
			topdelete = { text = "‾" },
			changedelete = { text = "~" },
			untracked = { text = "┆" },
		},
		signs_staged_enable = true,
		signcolumn = true, -- Toggle with `:Gitsigns toggle_signs`
		numhl = false, -- Toggle with `:Gitsigns toggle_numhl`
		linehl = false, -- Toggle with `:Gitsigns toggle_linehl`
		word_diff = false, -- Toggle with `:Gitsigns toggle_word_diff`
		watch_gitdir = {
			follow_files = true,
		},
		auto_attach = true,
		attach_to_untracked = false,
		current_line_blame = false, -- Toggle with `:Gitsigns toggle_current_line_blame`
		current_line_blame_opts = {
			virt_text = true,
			virt_text_pos = "eol", -- 'eol' | 'overlay' | 'right_align'
			delay = 1000,
			ignore_whitespace = false,
			virt_text_priority = 100,
			use_focus = true,
		},
		current_line_blame_formatter = "<author>, <author_time:%R> - <summary>",
		sign_priority = 6,
		update_debounce = 100,
		status_formatter = nil, -- Use default
		max_file_length = 40000, -- Disable if file is longer than this (in lines)
		preview_config = {
			-- Options passed to nvim_open_win
			style = "minimal",
			relative = "cursor",
			row = 0,
			col = 1,
		},
		on_attach = function(bufnr)
			local gitsigns = require("gitsigns")

			local function map(mode, l, r, opts)
				opts = opts or {}
				opts.buffer = bufnr
				vim.keymap.set(mode, l, r, opts)
			end

			-- Navigation
			map("n", "]gc", function()
				if vim.wo.diff then
					vim.cmd.normal({ "]gc", bang = true })
				else
					gitsigns.nav_hunk("next")
				end
			end, { desc = "next hunk" })

			map("n", "[gc", function()
				if vim.wo.diff then
					vim.cmd.normal({ "[gc", bang = true })
				else
					gitsigns.nav_hunk("prev")
				end
			end, { desc = "prev hunk" })

			-- Actions
			map("n", "<leader>ghs", gitsigns.stage_hunk, { desc = "stage_hunk" })
			map("n", "<leader>ghr", gitsigns.reset_hunk, { desc = "reset_hunk" })
			map("n", "<leader>ghp", gitsigns.preview_hunk, { desc = "preview_hunk" })
			map("n", "<leader>ghi", gitsigns.preview_hunk_inline, { desc = "preview_hunk_inline" })
			map("v", "<leader>ghs", function()
				gitsigns.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
			end)

			map("v", "<leader>ghr", function()
				gitsigns.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
			end)

			map("n", "<leader>gbS", gitsigns.stage_buffer, { desc = "stage_buffer" })
			map("n", "<leader>gbR", gitsigns.reset_buffer, { desc = "reset_buffer" })

			map("n", "<leader>glb", function()
				gitsigns.blame_line({ full = true })
			end, { desc = "blame_line" })

			map("n", "<leader>gd", gitsigns.diffthis, { desc = "diffthis" })

			map("n", "<leader>gD", function()
				gitsigns.diffthis("~")
			end, { desc = "diffthis ~" })

			map("n", "<leader>ghQ", function()
				gitsigns.setqflist("all")
			end, { desc = "setqflist all" })
			map("n", "<leader>ghq", gitsigns.setqflist, { desc = "setqflist" })

			-- Toggles
			map("n", "<leader>gtb", gitsigns.toggle_current_line_blame, { desc = "toggle_current_line_blame" })
			map("n", "<leader>gtw", gitsigns.toggle_word_diff, { desc = "toggle_word_diff" })

			-- Text object
			map({ "o", "x" }, "ih", gitsigns.select_hunk, { desc = "select_hunk" })
		end,
	},
}
