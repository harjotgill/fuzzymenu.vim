
let s:cpo_save = &cpo
set cpo&vim

""" internal state
let s:menuItemsSource = { }
let s:menuItemsSink = { }

""
" @public
" @usage {items} {baseDef}
" Add several menu items to fuzzymenu. {items} is a dict of names and defs.
" {baseDef} is a dict to combine with each item
" (see Add()).
" {baseDef} is a dict with common members
function! fuzzymenu#AddAll(items, baseDef) abort
  let kvPairs = items(a:items)
  for i in kvPairs 
    let name = i[0]
    let v = i[1]
    let def = copy(a:baseDef)
    for j in items(v)
      let def[j[0]] = j[1]
    endfor
    call fuzzymenu#Add(name, def)
  endfor
endfunction

""
" @public
" @usage {name} {def}
" Add a menu item to fuzzymenu. {name} are unique.
" {def} is a dict with a mandatory member, 'exec'
function! fuzzymenu#Add(name, def) abort
  if !has_key(a:def, 'exec')
    echom "definition not valid"
    return
  endif
  let s:menuItemsSource[s:key(a:name, a:def, 1)] = a:def
  let s:menuItemsSink[s:key(a:name, a:def, 0)] = a:def
endfunction

function fuzzymenu#Get(name) abort
  return s:menuItemsSink[a:name]
endfunction

function s:key(name, def, colored)
  let k = ''
  let kc = ''
  if has_key(a:def, 'tags')
    let k = '[' . join(a:def['tags'], ',') . ']'
    let kc = s:color('cyan', k)
  endif
  if a:colored
    return kc.a:name "s:color('green', a:name)
  endif
  return k.a:name
endfunction

func! s:compare(i1, i2)
  return a:i1[0] == a:i2[0] ? 0 : a:i1[0] > a:i2[0] ? 1 : -1
endfunc

function! s:MenuSource(currentMode) abort
  let extension = expand("%:e")
  let ret = []
  let pairs = items(s:menuItemsSource)
  call sort(pairs, 's:compare')
  for i in pairs 
    let k = i[0]
    let def = i[1]
    if has_key(def, 'for') 
     if extension != def['for'] 
       continue
     endif
    endif
    let help = ''
    if has_key(def, 'help') 
      let help = def['help']
    endif
    if has_key(def, 'modes')
      let modes = def['modes']
      if  modes !~ a:currentMode
        " doesn't apply
        continue
      endif
    endif
    let execu = def['exec']
    if execu =~ '^normal!'
      let execu = substitute(execu, '^normal!', s:color('cyan', ':normal!'), '')
    elseif execu =~ '^call '
      let execu = substitute(execu, '^call ', s:color('cyan', ':call '), '')
    else
      let execu = s:color('cyan', ':') . execu
    endif
    let row= printf("%s\t\t%s\t%s",
            \ k,
            \ execu,
            \ s:color('cyan', help))
    call add(ret, row)
  endfor
  return ret
endfunction

function! s:MenuSink(mode, arg) abort
  let key = split(a:arg, "\t")[0]
  if !has_key(s:menuItemsSink, key)
    "echo s:color('red', printf("key '%s' not found!", key))
    echo printf("key '%s' not found!", key)
    "return
  endif
  let def = s:menuItemsSink[key]
  if has_key(def, 'exec')
    if a:mode == 'v'
      " execute on selected range
      " TODO: only support range when it makes sense to? ... or should we just allow it? Someone can always just use normal-mode if it fails
      execute "'<,'>" . def['exec']
    else
      execute def['exec']
    endif
  else
    echo "invalid key for fuzzymenu: " . key
  endif
  if has_key(def, 'after') 
   execute def['after']
  endif
endfunction

function! fuzzymenu#InsertMode() abort
     if has("nvim")
       call feedkeys('i')
     else
       startinsert
     endif
endfunction

""
" @public
" Invoke fuzzymenu
function! fuzzymenu#Run(params) abort range
  let mode = 'n'
  if has_key(a:params, 'visual')
    if a:params['visual'] == 1
      let mode = 'v'
    endif
  endif

""
" @setting fuzzymenu_position
" Position of the fuzzymenu (using fzf positions down/up/left/right)
  let g:fuzzymenu_position = get(g:, 'fuzzymenu_position', 'down')

""
" @setting fuzzymenu_size
" Relative size of menu (default is '33%')
  let g:fuzzymenu_size = get(g:, 'fuzzymenu_size', '33%')

  let opts = {
    \ 'source': s:MenuSource(mode),
    \ 'sink': function('s:MenuSink', [mode]),
    \ 'options': '--ansi'}
  let opts[g:fuzzymenu_position] = g:fuzzymenu_size
  let fullscreen = 0
  if has_key(a:params, 'fullscreen')
    let fullscreen = a:params['fullscreen']
  endif
  call fzf#run(fzf#wrap('fuzzymenu', opts, fullscreen))
endfunction

function! s:get_color(attr, ...) abort
  let gui = has('termguicolors') && &termguicolors
  let fam = gui ? 'gui' : 'cterm'
  let pat = gui ? '^#[a-f0-9]\+' : '^[0-9]\+$'
  for group in a:000
    let code = synIDattr(synIDtrans(hlID(group)), a:attr, fam)
    if code =~? pat
      return code
    endif
  endfor
  return ''
endfunction

let s:ansi = {'black': 30, 'red': 31, 'green': 32, 'yellow': 33, 'blue': 34, 'magenta': 35, 'cyan': 36}

function! s:csi(color, fg) abort
  let prefix = a:fg ? '38;' : '48;'
  if a:color[0] == '#'
    return prefix.'2;'.join(map([a:color[1:2], a:color[3:4], a:color[5:6]], 'str2nr(v:val, 16)'), ';')
  endif
  return prefix.'5;'.a:color
endfunction

function! s:ansi(str, group, default, ...) abort
  let fg = s:get_color('fg', a:group)
  let bg = s:get_color('bg', a:group)
  let color = (empty(fg) ? s:ansi[a:default] : s:csi(fg, 1)) .
        \ (empty(bg) ? '' : ';'.s:csi(bg, 0))
  return printf("\x1b[%s%sm%s\x1b[m", color, a:0 ? ';1' : '', a:str)
endfunction
  
function! s:color(color_name, str, ...) abort
  return s:ansi(a:str, get(a:, 1, ''), a:color_name)
endfunc

let &cpo = s:cpo_save
unlet s:cpo_save
