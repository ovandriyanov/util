call plug#begin()
Plug 'hrsh7th/cmp-nvim-lsp'
Plug 'hrsh7th/cmp-buffer'
Plug 'hrsh7th/cmp-path'
Plug 'hrsh7th/cmp-cmdline'
Plug 'hrsh7th/nvim-cmp'
Plug 'rafamadriz/friendly-snippets'

" For vsnip users.
" Plug 'hrsh7th/cmp-vsnip'
" Plug 'hrsh7th/vim-vsnip'

" For luasnip users.
Plug 'L3MON4D3/LuaSnip'
Plug 'saadparwaiz1/cmp_luasnip'

" For mini.snippets users.
" Plug 'echasnovski/mini.snippets'
" Plug 'abeldekat/cmp-mini-snippets'

" For ultisnips users.
" Plug 'SirVer/ultisnips'
" Plug 'quangnguyen30192/cmp-nvim-ultisnips'

" For snippy users.
" Plug 'dcampos/nvim-snippy'
" Plug 'dcampos/cmp-snippy'

Plug 'nvim-lua/plenary.nvim'

" Telescope
" Plug 'BurntSushi/ripgrep'
Plug 'nvim-treesitter/nvim-treesitter'
Plug 'nvim-tree/nvim-web-devicons'
Plug 'nvim-telescope/telescope.nvim'

let s:arcadia_tooling_root = empty($ARCADIA_TOOLING_ROOT)
    \ ? expand('$HOME/arc/tooling')
    \ : $ARCADIA_TOOLING_ROOT
let s:arcanum_review_path = s:arcadia_tooling_root . "/junk/ovandriyanov/nvim/arcanum-review"
if isdirectory(s:arcanum_review_path)
    execute "Plug '" . s:arcanum_review_path . "'"
endif
Plug 'nanozuki/tabby.nvim', { 'tag': 'v2.8.1' }

call plug#end()

if !get(g:, 'workstation_plugin_bootstrap', 0)
    lua dofile(vim.fn.stdpath('config') .. '/nvim-cmp.lua')
    lua dofile(vim.fn.stdpath('config') .. '/gosnip.lua')
endif
