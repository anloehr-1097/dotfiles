local function load_dap_configs()
	local cwd = vim.fn.getcwd()
	local dap_config_file = cwd .. "/.nvim/dap.lua"
	if vim.fn.filereadable(dap_config_file) == 1 then
		local dap_config = dofile(dap_config_file)

		for _, config in ipairs(dap_config) do
			table.insert(require("dap").configurations.python, config)
		end
	end
end
-- Create a command to call the function from command mode in nvim
vim.api.nvim_create_user_command("LoadDapConfig", load_dap_configs, {})

--- Create a DAP Python unittest configuration for a given test string
--- @param cwd string: Working directory for the debug session
--- @param test_dir string: Python module/package where tests live (e.g. "tests")
--- @param test_name string: Test (module, class, or method), e.g. "tests.test_module.TestClass.test_method"
--- @return table: DAP configuration
local function create_unittest_dap_config(cwd, test_dir, test_name)
	return {
		type = "python",
		request = "launch",
		name = "Debug unittest: " .. test_name,
		cwd = cwd,
		module = "unittest",
		args = { "-v", test_dir .. "." .. test_name },
		justMyCode = true,
		console = "integratedTerminal",
	}
end

-- Define the user command to call your function
vim.api.nvim_create_user_command("LoadCustomUnittest", function(opts)
	local args = opts.fargs
	local cwd = args[1]
	local test_dir = args[2]
	local test_name = args[3]

	if not test_name or not cwd or not test_dir then
		print("Usage: LoadCustomUnittest <cwd> <test_dir> <test_name>")
		return
	end

	local config = create_unittest_dap_config(cwd, test_dir, test_name)
	local dap = require("dap")
	dap.configurations = dap.configurations or {}
	dap.configurations.python = dap.configurations.python or {}

	-- Create your custom config (replace the argument with your test path)
	-- Add it to the list of Python configurations
	table.insert(dap.configurations.python, config)
	print("Added config" .. vim.inspect(config)) -- or do something else with the config
end, {
	nargs = "+", -- Require exactly one argument (the test string)
	desc = "Create and add a DAP unittest configuration",
})

return {
	{
		"mfussenegger/nvim-dap-python",
		ft = "python",
		dependencies = {
			"mfussenegger/nvim-dap",
			"rcarriga/nvim-dap-ui",
		},
		config = function(_, opts)
			local venv_path = os.getenv("VIRTUAL_ENV")
			local conda_prefix = os.getenv("CONDA_PREFIX")

			local venv_py
			if venv_path then
				venv_py = venv_path .. "/bin/python"
			elseif conda_prefix then
				venv_py = conda_prefix .. "/bin/python"
			elseif os.getenv("PYTHONPATH") then
				venv_py = "/usr/bin/python3"
			else
				venv_py = nil
			end

			if venv_py then
				require("dap-python").setup(venv_py)
			end

			-- local venv_py
			-- local dap_config
			-- if venv_path then
			-- 	venv_py = venv_path .. "/bin/python"
			-- else
			-- 	venv_py = "/usr/bin/python3"
			-- end

			-- local cwd = vim.fn.getcwd()
			-- local dap_config_file = cwd .. '/.nvim/dap.lua'
			-- if vim.fn.filereadable(dap_config_file) == 1 then
			--     dap_config = dofile(dap_config_file)
			--     Conf_name = dap_config.module
			--     Module_name = dap_config.module
			--     Args = dap_config.args
			-- end
			-- require("dap-python").setup(venv_py)

			local keymap = vim.keymap
			local dap_py = require("dap-python")

			local opts_map = { noremap = true, silent = true }
			local on_attach = function(client, bufnr)
				opts.buffer = bufnr

				-- set keybinds
				opts_map.desc = "Set denbugging breakpoint"
				keymap.set("n", "<leader>ba", function()
					dap_py.test_method()
				end, opts_map)
			end
		end,

		splitString = function(input)
			local words = {}
			for word in string.gmatch(input, "%S+") do
				table.insert(words, word)
			end
			return words
		end,
	},
}
