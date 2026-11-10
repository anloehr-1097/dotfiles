local M = {}

M.defaults = {
	-- Bazel client. Falls back to "bazelisk" when "bazel" is not on $PATH.
	bazel_cmd = "bazel",
	-- Startup options placed before the command, e.g. { "--output_base=/tmp/nvim-bazel" }
	-- to give the editor its own server (no lock contention, but a separate cache).
	startup_args = {},
	-- Options shared by `build` and `aquery` (e.g. { "--config=gcc" }). Keep these identical to
	-- what you use in the terminal, otherwise Bazel discards its analysis cache on every switch.
	bazel_args = {},
	-- Extra options for the background build only.
	build_args = {},

	-- Build the owning targets whenever a C/C++ (or BUILD) file in a Bazel workspace is written.
	build_on_save = true,
	debounce_ms = 250,
	-- Only produce object files (skips linking: faster, but no linker errors).
	compile_only = false,
	-- When a save happens during a running build: false = queue a follow-up build,
	-- true = interrupt the running build and start over.
	interrupt = false,
	-- What to build when a file is not listed in any rule: "package" (//pkg:all) or "none".
	fallback = "package",
	-- Filetypes whose save triggers a build.
	filetypes = { "c", "cpp", "objc", "objcpp", "cuda", "bzl" },

	-- How to treat clangd's own *compiler* diagnostics in Bazel workspaces (clangd's clang
	-- frontend misreports some GCC extensions / libstdc++ code; GCC is authoritative):
	--   "all"  keep everything clangd reports
	--   "hint" keep them, but downgrade to HINT severity
	--   "tidy" drop clang frontend diagnostics, keep clang-tidy / include-cleaner (default)
	--   "none" drop every clangd diagnostic
	clangd_diagnostics = "tidy",

	compdb = {
		-- Generate compile_commands.json when a workspace without one is opened.
		auto_generate = true,
		-- Regenerate when BUILD / .bzl / MODULE files are saved.
		regenerate_on_build_change = true,
		-- Target pattern(s) whose CppCompile actions go into the database.
		targets = { "//..." },
		-- Include compile commands for sources in external repositories.
		include_external = false,
		-- Lua patterns (anchored) of GCC-only flags that clang does not understand.
		remove_flags = {
			"^%-fno%-canonical%-system%-headers$",
			"^%-Wno%-free%-nonheap%-object$",
			"^%-Wunused%-but%-set%-parameter$",
			"^%-fstack%-usage$",
			"^%-fconserve%-stack$",
			"^%-fno%-tree%-.*",
			"^%-fipa%-.*",
			"^%-mabi=.*",
			"^%-mlongcalls$",
			"^%-fstrict%-volatile%-bitfields$",
		},
		-- Create <workspace>/external and <workspace>/bazel-out symlinks when missing so that
		-- execroot-relative include paths resolve from the workspace root.
		link_external = true,
		-- Restart clangd after the database was created for the first time.
		restart_clangd = true,
	},

	-- "failures": notify when a build fails, "always", or "never".
	notify = "failures",
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
	if vim.fn.executable(M.options.bazel_cmd) == 0 and vim.fn.executable("bazelisk") == 1 then
		M.options.bazel_cmd = "bazelisk"
	end
	return M.options
end

--- Quote a label or file name for use inside a `bazel query` expression. Unquoted, a name
--- with a space, '+', ',' or a parenthesis is parsed as query syntax. Bazel's lexer has no
--- escapes, so a name holding both quote characters cannot be expressed (returns nil).
function M.query_word(s)
	if not s:find('"', 1, true) then
		return '"' .. s .. '"'
	elseif not s:find("'", 1, true) then
		return "'" .. s .. "'"
	end
end

-- Full argv for a bazel command: bazel <startup> <command> <args...>
function M.bazel(command, args)
	local o = M.options
	local cmd = { o.bazel_cmd }
	vim.list_extend(cmd, o.startup_args)
	table.insert(cmd, command)
	vim.list_extend(cmd, args or {})
	return cmd
end

return M
