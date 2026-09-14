" Arcadia paths
set path+=$ARCADIA_ROOT
set path+=$CLOUDIA_ROOT
set path+=$ARCADIA_ROOT/cloud/bitbucket/private-api
set path+=$ARCADIA_ROOT/cloud/bitbucket/public-api
set path+=$ARCADIA_ROOT/cloud/bitbucket/common-api
set path+=$ARCADIA_ROOT/contrib/libs/protobuf/src

augroup extra
    autocmd!
    " Arcadia files options
    autocmd BufRead */ya.make                           set syntax=yamake
    autocmd BufRead $ARCADIA_ROOT/*.sql                 set syntax=yql
    autocmd BufRead $ARCADIA_ROOT/logfeller/*.sql       setlocal include='^\\s*import\\s*\\.'
    autocmd BufRead $ARCADIA_ROOT/logfeller/*.sql       setlocal includeexpr=substitute(v:fname,'\\.','/','g')[1:].'.sql'
    autocmd FileType python                             setlocal path+=$ARCADIA_ROOT/*/python

    autocmd FileType proto syn region  protoBlock   start="{" end="}" transparent fold
    autocmd BufReadPost */transfer_manager/go/proto/api/**/*.proto
        \   setlocal foldmethod=syntax
        \ | setlocal foldlevel=1
        \ | setlocal foldtext=getline(v:foldstart)\ .\ '...}'
        \ | setlocal foldcolumn=1
    autocmd BufReadPost */transfer_manager/go/proto/api/*.proto
        \   setlocal foldmethod=syntax
        \ | setlocal foldlevel=1
        \ | setlocal foldtext=getline(v:foldstart)\ .\ '...}'
        \ | setlocal foldcolumn=1
augroup END

command! Adiff call Adiff()
command! Astage call Astage()
command! -range=0 Stream call Stream('', <count>)
command! -range=0 VStream call Stream('vsplit', <count>)
command! -range=0 SStream call Stream('split', <count>)
command! -range=0 TStream call Stream('tabnew', <count>)
command! -range=0 Parser call Parser('', <count>)
command! -range=0 VParser call Parser('vsplit', <count>)
command! -range=0 SParser call Parser('split', <count>)
command! -range=0 TParser call Parser('tabnew', <count>)
command! -range=0 Precomputer call Precomputer('', <count>)
command! -range=0 VPrecomputer call Precomputer('vsplit', <count>)
command! -range=0 SPrecomputer call Precomputer('split', <count>)
command! -range=0 TPrecomputer call Precomputer('tabnew', <count>)

vnoremap gyh "zy:silent call Yopen('hahn', getreg('z'))<Cr>
vnoremap gyu "zy:silent call Yopen('hume', getreg('z'))<Cr>
vnoremap gya "zy:silent call Yopen('arnold', getreg('z'))<Cr>
nnoremap gyh :silent call Yopen('hahn', '<cfile>')<Cr>
nnoremap gyu :silent call Yopen('hume', '<cfile>')<Cr>
nnoremap gya :silent call Yopen('arnold', '<cfile>')<Cr>
nnoremap gyH :silent call Yopen('hahn', '//home/logfeller')<Cr>
nnoremap gyU :silent call Yopen('hume', '//home/logfeller')<Cr>
nnoremap gyA :silent call Yopen('arnold', '//home/logfeller')<Cr>
nnoremap gA :silent Aopen<Cr>
vnoremap gA :Aopen<Cr>
nnoremap gc :silent AopenCurrent \| redraw!<Cr>
vnoremap gc :AopenCurrent \| redraw!<Cr>

function! Adiff() abort
    let l:file = expand('%')
    let l:bufnr = bufnr()
    let l:winid = win_getid()
    diffthis
    let l:arelfile = Arel(l:file)
    let l:splitright = &g:splitright
    set nosplitright | vnew | let &g:splitright = l:splitright
    let b:adiff_file = l:file
    let b:adiff_bufnr = l:bufnr
    set bt=nofile
    execute 'read !arc show HEAD:' . shellescape(l:arelfile)
    normal ggdd
    diffthis
    call win_gotoid(l:winid)
endfunction

function! BufDo(range, command) abort
    split
    execute a:range . 'bufdo ' . a:command
    wincmd q
endfunction

function Call(cmd, input)
    let l:output = system(a:cmd, a:input)
    let l:exit_status = v:shell_error
    if l:exit_status != 0
        throw 'Cannot execute ' . a:cmd . ': ' . l:output
    endif
    return l:output
endfunction

function BufEqual(b1, b2)
    let l:sum1 = Call('sha256sum', a:b1)
    let l:sum2 = Call('sha256sum', a:b2)
    return l:sum1 == l:sum2
endfunction

function! Astage() abort
    let l:orig_file = b:adiff_file
    let l:orig_bufnr = b:adiff_bufnr
    let l:equal = BufEqual(bufnr(), l:orig_bufnr)

    if !l:equal
        call BufDo(l:orig_bufnr, '1,$+1diffget')
    endif

    silent call BufDo(l:orig_bufnr, 'write')
    silent execute '!arc add ' . shellescape(l:orig_file)

    if !l:equal
        call BufDo(l:orig_bufnr, 'undo')
        silent call BufDo(l:orig_bufnr, 'write')
    endif
endfunction

function! Yopen(cluster, path)
    execute '!yopen ' . a:cluster . ' ' . a:path
endfunction

function! Stream(splitter, visual)
    call Grep1(a:splitter, a:visual, '$ARCADIA_ROOT/logfeller/configs/logs/*_streams.json')
endfunction

function! Parser(splitter, visual)
    call Grep1(a:splitter, a:visual, '$ARCADIA_ROOT/logfeller/configs/parsers/parsers.auto.json')
endfunction

function! Precomputer(splitter, visual)
    call Grep1(a:splitter, a:visual, '$ARCADIA_ROOT/logfeller/configs/parsers/precomputers.json')
endfunction

function! Grep1(splitter, visual, files_glob)
    if a:visual
        norm "zy
        let l:pattern = getreg('z')
    else
        let l:pattern = expand("<cfile>")
    endif
    if strlen(l:pattern) == 0
        echom 'Empty pattern'
        return
    endif

    let l:pattern = printf('^[\ ]*\"%s\":', l:pattern)
    execute a:splitter
    silent execute 'grep' l:pattern a:files_glob
    cfirst
    redraw!
endfunction

let s:dbext_conf_file = expand('~/.vim/dbext.vim')
if filereadable(s:dbext_conf_file)
    exe "source " . s:dbext_conf_file
endif
execute 'autocmd BufWritePost' s:dbext_conf_file 'source' s:dbext_conf_file
