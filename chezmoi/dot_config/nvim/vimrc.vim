set runtimepath^=~/.vim runtimepath+=~/.vim/after
let &packpath = &runtimepath
source ~/.vimrc
source $HOME/.config/nvim/plug.vim
source $HOME/.config/nvim/nvim-cmp.vim

command! -bar LspStop lua vim.lsp.stop_client(vim.lsp.get_clients(), true)
if $NVIM_DISABLE_LSP !=# '1' || $NVIM_GOPLS_VIA_QSSH ==# '1'
    command! -bar LspStart lua vim.lsp.start(Goplscfg, {reuse_client = function(_, _) return false end})
    command! -bar LspRestart LspStop | LspStart
endif
