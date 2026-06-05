-- return {
    --   "github/copilot.vim" 
    -- }
return  {
    "zbirenbaum/copilot.lua",
    requires = {
        "copilotlsp-nvim/copilot-lsp", -- (optional) for NES functionality
    },
    cmd = "Copilot",
    event = "InsertEnter",
    init = function()
      vim.g.copilot_nes_debounce = 500
    end,
    config = function()
        require("copilot").setup({
            suggestion = {
                enabled = true,
                auto_trigger = false,
                hide_during_completion = true,
                debounce = 15,
                trigger_on_accept = true,
                keymap = {
                    accept = "<C-e>",
                    accept_word = false,
                    accept_line = false,
                    next = "<C-n>",
                    prev = "<C-p>",
                    dismiss = "<C-]>",
                    toggle_auto_trigger = false,
                },
            },
            nes = {
                enabled = false,
                keymap = {
                    accept_and_goto = "<leader>p",
                    accept = false,
                    dismiss = "<Esc>",
                },
            },
        })
    end
}
