let s:cpo_save = &cpo
set cpo&vim

let s:operators = {
      \ 'y': 'Yank (copy)',
      \ 'd': 'Delete (cut)',
      \ 'c': 'Change (cut + insert)',
      \ '<': 'Unindent',
      \ '>': 'Indent',
      \ 'gU': 'Uppercase',
      \ 'gu': 'Lowercase',
      \ 'g~': 'Switch case',
      \ '=': 'Format',
      \ 'zf': 'Define fold',
      \ }

""
" @public
" Fuzzy-select an operator (yank,change,delete,etc)
function! fuzzymenu#operators#OperatorCommands() abort
 let opts = {
    \ 'source': s:OperatorsSource(),
    \ 'sink': function('s:OperatorsSink'),
    \ 'options': '--ansi',
    \ g:fuzzymenu_position : g:fuzzymenu_size,
  \ }
  call fzf#run(fzf#wrap('fzm#operators#OperatorCommands', opts, 0))
endfunction

function! s:OperatorsSource() abort
  let operators = []
  for i in items(s:operators)
    let key = i[0]
    let val = i[1]
    let operator = printf("%s\t%s", key, val)
    call add(operators, operator)
  endfor
  return operators
endfunction

function! s:OperatorsSink(arg) abort
  let key = split(a:arg, "\t")[0]
  if !has_key(s:operators, key)
    echo printf("key '%s' not found!", key)
    return
  endif
  call fuzzymenu#operatorpending#Run(key)
  call fuzzymenu#InsertModeIfNvim()
endfunction

function! fuzzymenu#operators#AddOperations() abort
  let ops = {}
  let kvPairs = items(s:operators)
  for i in kvPairs
    let name = i[1]
    let op = i[0]
    let ops[name] = { 'exec': 'call fuzzymenu#operatorpending#Run("'.op.'")' }
  endfor
  call fuzzymenu#AddAll(ops,
    \ {'after': 'call fuzzymenu#InsertModeIfNvim()', 'tags': ['normal','fzf']})
endfunction
