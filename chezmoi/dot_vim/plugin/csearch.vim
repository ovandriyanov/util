" Maintainer:  Yury Kartynnik
" Available as a Pathogen/VimBundle/NeoBundle plugin at:  https://github.com/kartynnik/vim-f


" ----- Commands -----
" Usage: :CodeSearchEx 'regexp' -f 'fileRegexp' -m matches ... (see f usage)
command! -nargs=+ CodeSearchEx   call CodeSearch("<args>")
" Usage: :CodeSearch regexp
command! -nargs=+ CodeSearch     call CodeSearch("'<args>'")
" Perform code search for the word under cursor
command!          CodeSearchWord call CodeSearch("'\\b" . expand("<cword>") . "\\b'")
" Perform code search for a word-bounded regexp defined by the visual selection
command!          CodeSearchSel  call CodeSearch("'\\b" . CodeSearchGetVisualSelection() . "\\b'")


" ----- Configuration -----
" Whether to use tabs for search results
if ! exists("g:csearch_tabs")
    let g:csearch_tabs = 0
endif
" Whether to override the K mapping to use CodeSearchWord/CodeSearchSel
if ! exists("g:csearch_keyword")
    let g:csearch_keyword = 1
endif
" Whether to set the <Leader>f/<Leader>F mappings to use CodeSearch/CodeSearchEx
if ! exists("g:csearch_mappings")
    let g:csearch_mappings = 1
endif
" Script name (and possibly default command-line arguments) to call
if ! exists("g:csearch_command")
    let g:csearch_command = "f"
endif
" Environment variable settings to override
if ! exists("g:csearch_env")
    let g:csearch_env = "CS_WSVN=no CS_COLORS=Never"
endif


" ----- Mappings -----
if g:csearch_mappings
    nmap <leader>f :CodeSearch<Space>
    nmap <leader>F :CodeSearchEx<Space>
endif
if g:csearch_keyword
    nmap K :CodeSearchWord<CR>
    vmap K :CodeSearchSel<CR>
endif


" ----- Implementation -----
function! CodeSearch(args)
  if g:csearch_tabs
      tabnew
  endif

  let cmd = g:csearch_env . " " . g:csearch_command . " " . a:args

  echom "Performing command: " . cmd
  cexpr system(cmd)
  copen

  let b:csearch_args = a:args
  setlocal statusline=%{b:csearch_args}

  if len(getqflist()) == 2
      cfirst
      cclose
  elseif len(getqflist()) <= 1
      cclose
      if g:csearch_tabs
          tabclose
      endif
      echohl ErrorMsg | echo "Couldn't find code matching '" . a:args . "'" | echohl None
  endif
endfunc

function! CodeSearchGetVisualSelection()
  let [line1, col1] = getpos("'<")[1:2]
  let [line2, col2] = getpos("'>")[1:2]
  if line1 != line2
      throw "CodeSearch doesn't support multiline regexps"
  endif
  let line = getline(line1)
  let line = line[col1 - 1 : col2 - (&selection == 'inclusive' ? 1 : 2)]
  return line
endfunction
