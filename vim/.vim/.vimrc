set path+=**
set wildmenu
set wildignorecase

" Snippets
function! InsertSnippet()
  let l:word = expand('<cword>')
  let l:file = $HOME . '/.vim/snippets/' . l:word . '.snippet'
  if filereadable(l:file)
    normal! diw
    execute 'read ' . l:file
  endif
endfunction

inoremap <C-c>e <Esc>:call InsertSnippet()<CR>
