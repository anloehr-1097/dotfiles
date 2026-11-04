return {
    {
        'milanglacier/minuet-ai.nvim',
        dependencies = { 'hrsh7th/nvim-cmp' },
        config = function()
            require('minuet').setup {
                -- The OpenCode Go gateway requires a session id header;
                -- minuet doesn't set one, so inject it via curl instead.
                curl_extra_args = { '-H', 'x-opencode-session: nvim-minuet' },
                virtualtext = {
                    auto_trigger_ft = {},
                    keymap = {
                        -- accept whole completion
                        accept = '<C-g>A',
                        -- accept one line
                        accept_line = '<C-g>a',
                        -- accept n lines (prompts for number)
                        -- e.g. "C-g z 2 CR" will accept 2 lines
                        accept_n_lines = '<C-g>z',
                        -- Cycle to prev completion item, or manually invoke completion
                        prev = '<C-g>[',
                        -- Cycle to next completion item, or manually invoke completion
                        next = '<C-g>]',
                        dismiss = '<C-g>e',
                    },
                },
                provider = 'openai_compatible',
                request_timeout = 2.5,
                throttle = 1500, -- Increase to reduce costs and avoid rate limits
                debounce = 600,  -- Increase to reduce costs and avoid rate limits
                provider_options = {
                    openai_compatible = {
                        -- Pass the *name* of the env var; minuet reads it itself
                        api_key = 'OPENCODE_GO_API_KEY',
                        end_point = 'https://opencode.ai/zen/go/v1/chat/completions',
                        model = 'deepseek-v4.1-flash',
                        name = 'Opencode',
                        optional = {
                            max_tokens = 56,
                            top_p = 0.9,
                            -- disable thinking to avoid first token latency
                            thinking = { type = 'disabled' },
                        },
                    },
                },
            }
        end,
    },
}
