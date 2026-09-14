set runtimepath+=~/.vim/bundle/Vundle.vim/

filetype off
call vundle#begin()
Plugin 'VundleVim/Vundle.vim'

Plugin 'jiangmiao/auto-pairs'
Plugin 'endel/vim-github-colorscheme'
Plugin 'google/vim-searchindex'
Plugin 'tpope/vim-repeat'
Plugin 'tpope/vim-surround'
Plugin 'vim-scripts/BufOnly.vim'
Plugin 'preservim/nerdtree'
Plugin 'udalov/kotlin-vim'
"Plugin 'rlue/vim-barbaric'
Plugin 'vim-signify'
if exists('g:devmode') && g:devmode
    " C/C++ stuff
    Plugin 'vim-scripts/Cpp11-Syntax-Support'   " Proper C++11 syntax highlighting
    Plugin 'Valloric/YouCompleteMe'
    Plugin 'mom0tomo/dotfiles'
    Plugin 'vim-scripts/git-time-lapse'
    Plugin 'vim-scripts/a.vim'                  " Quick switching between .h/.cpp
    Plugin 'tpope/vim-fugitive'
    Plugin 'ovandriyanov/dlvim'
    "Plugin 'vim-signify', {'pinned': 1}
    Plugin 'vim-quarc', {'pinned': 1}
endif

call vundle#end()

filetype plugin indent on
