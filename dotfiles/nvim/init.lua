local vimrc = vim.fn.stdpath("config") .. "/vimrc.vim"
vim.cmd.source(vimrc)
vim.cmd("highlight clear DiagnosticUnderlineError")
vim.cmd("highlight DiagnosticUnderlineError guibg=#a00000")
vim.cmd("highlight clear DiagnosticUnderlineWarn")
vim.cmd("highlight DiagnosticUnderlineWarn guibg=orange")
