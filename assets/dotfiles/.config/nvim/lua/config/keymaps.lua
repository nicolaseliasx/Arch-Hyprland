-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
local hlp = require("config.hlp")

hlp.setup()
vim.keymap.set("n", "<leader>h", hlp.toggle, { desc = "Nvim HLP" })
