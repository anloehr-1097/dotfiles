return {
    "nvim-telescope/telescope.nvim",
    version = '*',

    dependencies = {
        "nvim-lua/plenary.nvim",
        {'nvim-telescope/telescope-fzf-native.nvim', build='make'}

    },

    config = function()
        require('telescope').setup({})

        local builtin = require('telescope.builtin')
        vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
        vim.keymap.set('n', '<C-p>', builtin.git_files, {})
        vim.keymap.set('n', '<leader>fws', function()
            local word = vim.fn.expand("<cword>")
            builtin.grep_string({ search = word })
        end)
        vim.keymap.set('n', '<leader>fWs', function()
            local word = vim.fn.expand("<cWORD>")
            builtin.grep_string({ search = word })
        end)
        -- vim.keymap.set('n', '<leader>fs', function()
        --     builtin.grep_string({ search = vim.fn.input("Grep > ") })
        -- end)
        vim.keymap.set('n', '<leader>fs', builtin.live_grep, {desc = "Live Grep Telescope"})
        vim.keymap.set('n', '<leader>fb', builtin.current_buffer_fuzzy_find, {desc = "Live Grep in current buffer."})
        vim.keymap.set('n', '<leader>bb', builtin.buffers, {desc = "Buffers Telescope"})
        vim.keymap.set('n', '<leader>ft', builtin.tags, {desc = "Tags Telescope"})
        vim.keymap.set('n', '<leader>fm', builtin.man_pages, {desc = "Man Pages Telescope"})
        vim.keymap.set('n', '<leader>fq', builtin.quickfix, {desc = "Quickfix List Telescope"})


        local search_site_packages = function ()

          local site_packages = vim.fn.system("python -c 'import site; print(site.getsitepackages()[0])'"):gsub("\n", "")
          builtin.live_grep({
            prompt_title = "Search Site Packages",
            cwd = site_packages,
          })
        end;

        vim.api.nvim_create_user_command('SearchSitePackages', search_site_packages, {})
        vim.keymap.set('n', '<leader>fd', search_site_packages, {desc = "Find in dependencies"})
        vim.keymap.set('n', '<leader>vh', builtin.help_tags, {})

    end;
}

