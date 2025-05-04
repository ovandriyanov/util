local vimrc = vim.fn.stdpath("config") .. "/vimrc.vim"
vim.cmd.source(vimrc)
vim.cmd("highlight clear DiagnosticUnderlineError")
vim.cmd("highlight DiagnosticUnderlineError guibg=#a00000")
vim.cmd("highlight clear DiagnosticUnderlineWarn")
vim.cmd("highlight DiagnosticUnderlineWarn guibg=#707000")

-- gitsigns.nvim
local ok, gitsigns = pcall(require, "gitsigns")
if ok then
    vim.keymap.set("n", "]c", function() gitsigns.nav_hunk('next') end)
    vim.keymap.set("n", "[c", function() gitsigns.nav_hunk('prev') end)
end
