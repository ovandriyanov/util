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

vim.api.nvim_set_hl(0, "UserCodeDiffLineInsert", {
    bg = "#294329",
    ctermbg = 22,
})
vim.api.nvim_set_hl(0, "UserCodeDiffCharInsert", {
    bg = "#355535",
    ctermbg = 22,
})
vim.api.nvim_set_hl(0, "UserCodeDiffLineDelete", {
    bg = "#4a2b32",
    ctermbg = 52,
})
vim.api.nvim_set_hl(0, "UserCodeDiffCharDelete", {
    bg = "#603740",
    ctermbg = 52,
})

require("codediff").setup({
    highlights = {
        line_insert = "UserCodeDiffLineInsert",
        char_insert = "UserCodeDiffCharInsert",
        line_delete = "UserCodeDiffLineDelete",
        char_delete = "UserCodeDiffCharDelete",
    },
})
