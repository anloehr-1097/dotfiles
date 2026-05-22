-- set leader key to space
vim.g.mapleader = " "
vim.g.maplocalleader = "ll"

local keymap = vim.keymap -- for conciseness

---------------------
-- General Keymaps -------------------
keymap.set("n", "<leader>pv", vim.cmd.Ex)

-- use jk to exit insert mode
keymap.set("i", "jk", "<ESC>", { desc = "Exit insert mode with jk" })

-- clear search highlights
keymap.set("n", "<leader>nh", ":nohl<CR>", { desc = "Clear search highlights" })

-- delete single character without copying into register
-- keymap.set("n", "x", '"_x')

-- increment/decrement numbers
keymap.set("n", "<leader>+", "<C-a>", { desc = "Increment number" }) -- increment
keymap.set("n", "<leader>-", "<C-x>", { desc = "Decrement number" }) -- decrement

-- window management
keymap.set("n", "<leader>sv", "<C-w>v", { desc = "Split window vertically" }) -- split window vertically
keymap.set("n", "<leader>sh", "<C-w>s", { desc = "Split window horizontally" }) -- split window horizontally
keymap.set("n", "<leader>se", "<C-w>=", { desc = "Make splits equal size" }) -- make split windows equal width & height
keymap.set("n", "<leader>sx", "<cmd>close<CR>", { desc = "Close current split" }) -- close current split window

keymap.set("n", "<leader>to", "<cmd>tabnew<CR>", { desc = "Open new tab" }) -- open new tab
keymap.set("n", "<leader>tx", "<cmd>tabclose<CR>", { desc = "Close current tab" }) -- close current tab
keymap.set("n", "<leader>tn", "<cmd>tabnext<CR>", { desc = "Go to next tab" }) --  go to next tab
keymap.set("n", "<leader>tp", "<cmd>tabp<CR>", { desc = "Go to previous tab" }) --  go to previous tab
keymap.set("n", "<leader>tf", "<cmd>tabnew %<CR>", { desc = "Open current buffer in new tab" }) --  move current buffer to new tab

keymap.set("v", "J", ":m '>+1<CR>gv=gv")
keymap.set("v", "K", ":m '<-2<CR>gv=gv")

keymap.set("n", "J", "mzJ`z")
keymap.set("n", "<C-d>", "<C-d>zz")
keymap.set("n", "<C-u>", "<C-u>zz")
keymap.set("n", "n", "nzzzv")
keymap.set("n", "N", "Nzzzv")

-- greatest remap ever
keymap.set("x", "<leader>p", [["_dP]])

-- next greatest remap ever : asbjornHaland
keymap.set({ "n", "v" }, "<leader>y", [["+y]])
keymap.set("n", "<leader>Y", [["+Y]])

keymap.set({ "n", "v" }, "<leader>d", [["_d]])

-- This is going to get me cancelled
keymap.set("n", "Q", "<nop>")
keymap.set("n", "<leader>bf", vim.lsp.buf.format)

keymap.set("n", "<C-k>", "<cmd>cnext<CR>zz")
keymap.set("n", "<C-j>", "<cmd>cprev<CR>zz")
keymap.set("n", "<leader>k", "<cmd>lnext<CR>zz")
keymap.set("n", "<leader>j", "<cmd>lprev<CR>zz")
keymap.set("n", "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])
keymap.set("n", "<leader>x", "<cmd>!chmod +x %<CR>", { silent = true })

keymap.set("n", "<leader>vpp", "<cmd>e ~/.config/nvim/lua/andy<CR>")
keymap.set("n", "<leader>ca", "<cmd>CellularAutomaton make_it_rain<CR>")

-- Cmake
keymap.set("n", "<leader>cg", ":CMakeGenerate<CR>", { desc = "Generate CMake." })
keymap.set("n", "<leader>cb", ":CMakeBuild<CR>", { desc = "Build Cmake." })
keymap.set("n", "<leader>cq", ":CMakeClose<CR>", { desc = "CMake Close." })
keymap.set("n", "<leader>cd", ":CMakeClean<CR>", { desc = "CMake Clean." })
--
-- Debugging
keymap.set("n", "<C-c>db", ":DapToggleBreakpoint<CR>", { desc = "Set debugging breakpoint" })
keymap.set("n", "<C-c>ds", ":DapContinue<CR>", { desc = "Continue debugging" })
keymap.set("n", "<C-c>do", ":DapStepOver<CR>", { desc = "Step over" })
keymap.set("n", "<C-c>di", ":DapStepInto<CR>", { desc = "Step into" })
keymap.set("n", "<C-c>da", ":DapStepOut<CR>", { desc = "Step out" })
keymap.set("n", "<C-c>dr", ":DapToggleRepl", { desc = "Toggle REPL" })
