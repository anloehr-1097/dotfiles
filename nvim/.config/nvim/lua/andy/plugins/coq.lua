return {
    {
        "ms-jpq/coq_nvim",
        branch = "coq",
        dependencies = {
            "ms-jpq/coq.artifacts",
            "ms-jpq/coq.thirdparty",
        },
        config = function()
            vim.g.coq_settings = {
                auto_start = "shut-up",
                keymap = {
                    recommended = false,
                    jump_to_mark = "<C-n>",
                    manual_complete = "<C-Space>",
                },
            }
        end,

    },
}
