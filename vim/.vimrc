set path+=**
syntax on
filetype plugin indent on
set wildmenu
set wildignorecase

" :FindAll — like :find, but lists files with ripgrep
" (includes hidden dirs, skips .git and gitignored files)
if executable('rg')
  function! s:RgFiles(arglead) abort
    " Cache the file list for one command line so each <Tab> doesn't rerun rg
    if !exists('s:rg_files')
      let s:rg_files = systemlist("rg --files --hidden -g '!.git'")
    endif
    return empty(a:arglead) ? copy(s:rg_files) : matchfuzzy(s:rg_files, a:arglead)
  endfunction

  function! s:FindAllComplete(arglead, cmdline, cursorpos) abort
    return s:RgFiles(a:arglead)
  endfunction

  function! s:FindAll(arg) abort
    let l:matches = filereadable(a:arg) ? [a:arg] : s:RgFiles(a:arg)
    if empty(l:matches)
      echohl ErrorMsg | echo 'FindAll: no match for "' . a:arg . '"' | echohl None
      return
    endif
    execute 'edit ' . fnameescape(l:matches[0])
  endfunction

  command! -nargs=1 -bar -complete=customlist,s:FindAllComplete FindAll call s:FindAll(<q-args>)

  augroup RgFind
    autocmd!
    autocmd CmdlineEnter : silent! unlet s:rg_files
  augroup END
endif

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
