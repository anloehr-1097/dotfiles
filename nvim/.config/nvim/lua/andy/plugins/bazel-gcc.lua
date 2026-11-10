-- GCC diagnostics from real Bazel builds; clangd keeps navigation/completion.
-- Local plugin: nvim/.config/nvim/plugins-local/bazel-gcc.nvim
return {
	dir = vim.fn.stdpath("config") .. "/plugins-local/bazel-gcc.nvim",
	name = "bazel-gcc.nvim",
	ft = { "c", "cpp", "objc", "objcpp", "cuda", "bzl" },
	cmd = "BazelGcc",
	opts = {
		-- bazel_args = { "--config=gcc" },
		-- clangd_diagnostics = "tidy", -- "all" | "hint" | "tidy" | "none"
	},
	keys = {
		{ "<leader>Bb", "<cmd>BazelGcc build<cr>", desc = "Bazel: build owners of file" },
		{ "<leader>Bq", "<cmd>BazelGcc qf<cr>", desc = "Bazel: diagnostics to quickfix" },
		{ "<leader>Bl", "<cmd>BazelGcc log<cr>", desc = "Bazel: last build log" },
		{ "<leader>Bc", "<cmd>BazelGcc compdb<cr>", desc = "Bazel: regenerate compile_commands.json" },
		{ "<leader>Bp", "<cmd>BazelGcc pin<cr>", desc = "Bazel: pin targets of file" },
		{ "<leader>Bt", "<cmd>BazelGcc toggle<cr>", desc = "Bazel: toggle build on save" },
	},
}
