" surround - Surrounding text objects
" Author: Tim Pope <vimNOSPAM@tpope.info>
" ModifiedBy: kana <http://whileimautomaton.net/>
" BasedOn: $Id: surround.vim,v 1.34 2008-02-15 21:43:42 tpope Exp $
" License: same as the original one, i.e., same as Vim itself.
" "{{{1
" Original Header  "{{{2
" >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
" surround.vim - Surroundings
" Author:       Tim Pope <vimNOSPAM@tpope.info>
" GetLatestVimScripts: 1697 1 :AutoInstall: surround.vim
" $Id: surround.vim,v 1.34 2008-02-15 21:43:42 tpope Exp $
"
" See surround.txt for help.  This can be accessed by doing
"
" :helptags ~/.vim/doc
" :help surround
"
" Licensed under the same terms as Vim itself.
" <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
" "}}}2

" Exit quickly when:
" - this plugin was already loaded or disabled
" - when 'compatible' is set
if (exists("g:loaded_surround") && g:loaded_surround) || &cp
    finish
endif

let s:cpo_save = &cpo
set cpo&vim




" Implementation  "{{{1
" Input functions  "{{{2

function! s:getchar()
    let c = getchar()
    if c =~ '^\d\+$'
        let c = nr2char(c)
    endif
    return c
endfunction

let s:OBJS_BUILTIN = '"()<>BW`bpstw{}''[]'
let s:OBJS_DELETION = '/'
let s:OBJS_ADDITION = "T\<C-t>,l\\fF\<C-[>\<C-]>"
let s:RE_A_OBJS = '\V\^\[' . escape(s:OBJS_BUILTIN.s:OBJS_ADDITION, '\') . '\]'
let s:RE_D_OBJS = '\V\^\[' . escape(s:OBJS_BUILTIN.s:OBJS_DELETION, '\') . '\]'

function! s:inputtarget(...)
    let space_prefixed_p = a:0 ? a:1 : s:FALSE
    let cnt = ''

    " get count part
    if !space_prefixed_p
        let c = s:getchar()
        while c =~ '\d'
            let cnt = cnt . c
            let c = s:getchar()
        endwhile
    endif

    " check user-defined objects
    let [success_p, keyseq] = s:user_obj_input(c)
    if success_p
        return cnt . keyseq
    endif

    " other works
        " FIXME: User-defined objects with keys prefixed by a whitespace.
    if (!space_prefixed_p) && keyseq == ' '
        let keyseq = s:inputtarget(s:TRUE)
        if keyseq == ''
            return ''
        else
            " return cnt . ' ' . keyseq  " the original doesn't accept count
            return ' ' . keyseq
        endif
    endif
    if (keyseq =~ "[\<Esc>\<C-c>\0]"
    \   || (1 < len(keyseq) && keyseq !~# s:RE_D_OBJS))
        return ''
    else
        return cnt . keyseq
    endif
endfunction

function! s:inputreplacement(...)
    let space_prefixed_p = a:0 ? a:1 : s:FALSE
    let keyseq = ''

    " check user-defined objects
    let [success_p, keyseq] = s:user_obj_input('')
    if success_p
        return keyseq
    endif

    " other works
    if (!space_prefixed_p) && keyseq == ' '
        let keyseq = s:inputreplacement(s:TRUE)
        if keyseq == ''
            return ''
        else
            return ' ' . keyseq
        endif
    endif
    if (keyseq =~ "[\<Esc>\<C-c>\0]"
    \   || (1 < len(keyseq) && keyseq !~# s:RE_A_OBJS))
        return ''
    else
        return keyseq
    endif
endfunction

function! s:beep()
    exe "norm! \<Esc>"
    return ""
endfunction

function! s:redraw()
    redraw
    return ""
endfunction


" Wrapping functions  "{{{2

function! s:extractbefore(str)
    if a:str =~ '\r'
        return matchstr(a:str,'.*\ze\r')
    else
        return matchstr(a:str,'.*\ze\n')
    endif
endfunction

function! s:extractafter(str)
    if a:str =~ '\r'
        return matchstr(a:str,'\r\zs.*')
    else
        return matchstr(a:str,'\n\zs.*')
    endif
endfunction

function! s:repeat(str,count)
    let cnt = a:count
    let str = ""
    while cnt > 0
        let str = str . a:str
        let cnt = cnt - 1
    endwhile
    return str
endfunction

function! s:fixindent(str,spc)
    let str = substitute(a:str,'\t',s:repeat(' ',&sw),'g')
    let spc = substitute(a:spc,'\t',s:repeat(' ',&sw),'g')
    let str = substitute(str,'\(\n\|\%^\).\@=','\1'.spc,'g')
    if ! &et
        let str = substitute(str,'\s\{'.&ts.'\}',"\t",'g')
    endif
    return str
endfunction

function! s:process(string)
    let i = 0
    while i < 7
        let i = i + 1
        let repl_{i} = ''
        let m = matchstr(a:string,nr2char(i).'.\{-\}\ze'.nr2char(i))
        if m != ''
            let m = substitute(strpart(m,1),'\r.*','','')
            let repl_{i} = input(substitute(m,':\s*$','','').': ')
        endif
    endwhile
    let s = ""
    let i = 0
    while i < strlen(a:string)
        let char = strpart(a:string,i,1)
        if char2nr(char) < 8
            let next = stridx(a:string,char,i+1)
            if next == -1
                let s = s . char
            else
                let insertion = repl_{char2nr(char)}
                let subs = strpart(a:string,i+1,next-i-1)
                let subs = matchstr(subs,'\r.*')
                while subs =~ '^\r.*\r'
                    let sub = matchstr(subs,"^\r\\zs[^\r]*\r[^\r]*")
                    let subs = strpart(subs,strlen(sub)+1)
                    let r = stridx(sub,"\r")
                    let insertion = substitute(insertion,strpart(sub,0,r),strpart(sub,r+1),'')
                endwhile
                let s = s . insertion
                let i = next
            endif
        else
            let s = s . char
        endif
        let i = i + 1
    endwhile
    return s
endfunction

function! s:wrap(string,char,type,...)
    let keeper = a:string
    let newchar = a:char
    let type = a:type
    let linemode = type ==# 'V' ? 1 : 0
    let special = a:0 ? a:1 : 0
    let before = ""
    let after  = ""
    if type == "V"
        let initspaces = matchstr(keeper,'\%^\s*')
    else
        let initspaces = matchstr(getline('.'),'\%^\s*')
    endif
    " Duplicate b's are just placeholders (removed)
    let pairs = "b()B{}r[]a<>"
    let extraspace = ""
    if newchar =~ '^ '
        let newchar = strpart(newchar,1)
        let extraspace = ' '
    endif
    let idx = stridx(pairs,newchar)
    let user_defined_object = s:user_obj_value(newchar)
    if newchar == ' '
        let before = ''
        let after  = ''
    elseif len(user_defined_object)
        let all    = s:process(user_defined_object)
        let before = s:extractbefore(all)
        let after  =  s:extractafter(all)
    elseif newchar ==# "p"
        let before = "\n"
        let after  = "\n\n"
    elseif newchar =~# "[tT\<C-T><,]"
        let unmap_necessary_p = maparg('>', 'c') == ''
        if unmap_necessary_p
            " FIXME: With the returning value of maparg(), it's not possible
            "        to determine whether the given lhs is not mapped to
            "        anything or it is mapped to <Nop>.
            " To end input() with '>'.
            cnoremap <buffer> >  <CR>
        endif
        let default = ""
        if newchar ==# "T"
            if !exists("s:lastdel")
                let s:lastdel = ""
            endif
            let default = matchstr(s:lastdel,'<\zs.\{-\}\ze>')
        endif
        let tag = input("<",default)
        echo "<".substitute(tag,'>*$','>','')
        if unmap_necessary_p
            silent! cunmap <buffer>  >
        endif
        if tag != ""
            let tag = substitute(tag,'>*$','','')
            let before = '<'.tag.'>'
            if tag =~ '/$'
                let after = ''
            else
                let after  = '</'.substitute(tag,' .*','','').'>'
            endif
            if newchar == "\<C-T>" || newchar == ","
                if type ==# "v" || type ==# "V"
                    let before = before . "\n\t"
                endif
                if type ==# "v"
                    let after  = "\n". after
                endif
            endif
        endif
    elseif newchar ==# 'l' || newchar == '\'
        " LaTeX
        let env = input('\begin{')
        let env = '{' . env
        let env = env . s:closematch(env)
        echo '\begin'.env
        if env != ""
            let before = '\begin'.env
            let after  = '\end'.matchstr(env,'[^}]*').'}'
        endif
        "if type ==# 'v' || type ==# 'V'
            "let before = before ."\n\t"
        "endif
        "if type ==# 'v'
            "let after  = "\n".initspaces.after
        "endif
    elseif newchar ==# 'f' || newchar ==# 'F'
        let fnc = input('function: ')
        if fnc != ""
            let before = substitute(fnc,'($','','').'('
            let after  = ')'
            if newchar ==# 'F'
                let before = before . ' '
                let after  = ' ' . after
            endif
        endif
    elseif idx >= 0
        let spc = (idx % 3) == 1 ? " " : ""
        let idx = idx / 3 * 3
        let before = strpart(pairs,idx+1,1) . spc
        let after  = spc . strpart(pairs,idx+2,1)
    elseif newchar == "\<C-[>" || newchar == "\<C-]>"
        let before = "{\n\t"
        let after  = "\n}"
    elseif newchar !~ '\a'
        let before = newchar
        let after  = newchar
    else
        let before = ''
        let after  = ''
    endif
    "let before = substitute(before,'\n','\n'.initspaces,'g')
    let after  = substitute(after ,'\n','\n'.initspaces,'g')
    "let after  = substitute(after,"\n\\s*\<C-U>\\s*",'\n','g')
    if type ==# 'V' || (special && type ==# "v")
        let before = substitute(before,' \+$','','')
        let after  = substitute(after ,'^ \+','','')
        if after !~ '^\n'
            let after  = initspaces.after
        endif
        if keeper !~ '\n$' && after !~ '^\n'
            let keeper = keeper . "\n"
        elseif keeper =~ '\n$' && after =~ '^\n'
            let after = strpart(after,1)
        endif
        if before !~ '\n\s*$'
            let before = before . "\n"
            if special
                let before = before . "\t"
            endif
        endif
    endif
    if type ==# 'V'
        let before = initspaces.before
    endif
    if before =~ '\n\s*\%$'
        if type ==# 'v'
            let keeper = initspaces.keeper
        endif
        let padding = matchstr(before,'\n\zs\s\+\%$')
        let before  = substitute(before,'\n\s\+\%$','\n','')
        let keeper = s:fixindent(keeper,padding)
    endif
    if type ==# 'V'
        let keeper = before.keeper.after
    elseif type =~ "^\<C-V>"
        " Really we should be iterating over the buffer
        let repl = substitute(before,'[\\~]','\\&','g').'\1'.substitute(after,'[\\~]','\\&','g')
        let repl = substitute(repl,'\n',' ','g')
        let keeper = substitute(keeper."\n",'\(.\{-\}\)\('.(special ? '\s\{-\}' : '').'\n\)',repl.'\n','g')
        let keeper = substitute(keeper,'\n\%$','','')
    else
        let keeper = before.extraspace.keeper.extraspace.after
    endif
    return keeper
endfunction

function! s:wrapreg(reg,char,...)
    let orig = getreg(a:reg)
    let type = substitute(getregtype(a:reg),'\d\+$','','')
    let special = a:0 ? a:1 : 0
    let new = s:wrap(orig,a:char,type,special)
    call setreg(a:reg,new,type)
endfunction


function! s:insert(...)  "{{{2
    " Optional argument causes the result to appear on 3 lines, not 1
    "call inputsave()
    let linemode = a:0 ? a:1 : 0
    let char = s:inputreplacement()
    while char == "\<CR>" || char == "\<C-S>"
        " TODO: use total count for additional blank lines
        let linemode = linemode + 1
        let char = s:inputreplacement()
    endwhile
    "call inputrestore()
    if char == ""
        return ""
    endif
    "call inputsave()
    let cb_save = &clipboard
    let reg_save = @@
    call setreg('"',"\r",'v')
    call s:wrapreg('"',char,linemode)
    " If line mode is used and the surrounding consists solely of a suffix,
    " remove the initial newline.  This fits a use case of mine but is a
    " little inconsistent.  Is there anyone that would prefer the simpler
    " behavior of just inserting the newline?
    if linemode && match(getreg('"'),'^\n\s*\zs.*') == 0
        call setreg('"',matchstr(getreg('"'),'^\n\s*\zs.*'),getregtype('"'))
    endif
    " This can be used to append a placeholder to the end
    if exists("g:surround_insert_tail")
        call setreg('"',g:surround_insert_tail,"a".getregtype('"'))
    endif
    "if linemode
        "call setreg('"',substitute(getreg('"'),'^\s\+','',''),'c')
    "endif
    if col('.') >= col('$')
        norm! ""p
    else
        norm! ""P
    endif
    if linemode
        call s:reindent()
    endif
    norm! `]
    call search('\r','bW')
    let @@ = reg_save
    let &clipboard = cb_save
    return "\<Del>"
endfunction


function! s:reindent()  "{{{2
    if exists("b:surround_indent") ? b:surround_indent : (exists("g:surround_indent") && g:surround_indent)
        silent norm! '[=']
    endif
endfunction


function! s:dosurround(...)  "{{{2
    " ([target-surrounding-object-char, [new-surrounding-object-char]])
    " adjust arguments  "{{{3
    let scount = v:count1
    let char = (a:0 ? a:1 : s:inputtarget())
    let spc = ""
    if char =~ '^\d\+'
        let scount = scount * matchstr(char,'^\d\+')
        let char = substitute(char,'^\d\+','','')
    endif
    if char =~ '^ '
        let char = strpart(char,1)
        let spc = 1
    endif
    if char == 'a'
        let char = '>'
    endif
    if char == 'r'
        let char = ']'
    endif
    let newchar = ""
    if a:0 > 1
        let newchar = a:2
        if newchar == "\<Esc>" || newchar == "\<C-C>" || newchar == ""
            return s:beep()
        endif
    endif

    " save and initialize some values  "{{{3
    let cb_save = &clipboard
    set clipboard-=unnamed
    let append = ""
    let original = getreg('"')
    let otype = getregtype('"')
    call setreg('"',"")

    " move the target text range into @@, then delete surroudings  "{{{3
    let strcount = (scount == 1 ? "" : scount)
    let user_defined_object = s:user_obj_value(char)
    if len(user_defined_object)  " FIXME: [count] is not supported yet
        let all = s:process(user_defined_object)
        let before = s:extractbefore(all)
        let after = s:extractafter(all)
        call s:search_literally(before, 'bcW')
        normal! v
        call s:search_literally(after, 'ceW')
        normal! d
    elseif char == '/'
        exe 'norm! '.strcount.'[/d'.strcount.']/'
    else
        exe 'norm! d'.strcount.'i'.char
    endif
    let keeper = getreg('"')
    let okeeper = keeper " for reindent below
    if keeper == ""
        call setreg('"',original,otype)
        let &clipboard = cb_save
        return ""
    endif
    let oldline = getline('.')
    let oldlnum = line('.')
    if len(user_defined_object)
        call setreg('"', before.after, '')
        let keeper = keeper[len(before):]
        let keeper = keeper[:-(len(after)+1)]
    elseif char ==# "p"
        call setreg('"','','V')
    elseif char ==# "s" || char ==# "w" || char ==# "W"
        " Do nothing
        call setreg('"','')
    elseif char =~ "[\"'`]"
        exe "norm! i \<Esc>d2i".char
        call setreg('"',substitute(getreg('"'),' ','',''))
    elseif char == '/'
        norm! "_x
        call setreg('"','/**/',"c")
        let keeper = substitute(substitute(keeper,'^/\*\s\=','',''),'\s\=\*$','','')
    else
        " One character backwards
        call search('.','bW')
        exe "norm! da".char
    endif
    let removed = getreg('"')
    let rem2 = substitute(removed,'\n.*','','')
    let oldhead = strpart(oldline,0,strlen(oldline)-strlen(rem2))
    let oldtail = strpart(oldline,  strlen(oldline)-strlen(rem2))
    let regtype = getregtype('"')
    if char =~# '[\[({<T]' || spc
        let keeper = substitute(keeper,'^\s\+','','')
        let keeper = substitute(keeper,'\s\+$','','')
    endif
    if col("']") == col("$") && col('.') + 1 == col('$')
        if oldhead =~# '^\s*$' && a:0 < 2
            let keeper = substitute(keeper,'\%^\n'.oldhead.'\(\s*.\{-\}\)\n\s*\%$','\1','')
        endif
        let pcmd = "p"
    else
        let pcmd = "P"
    endif
    if line('.') < oldlnum && regtype ==# "V"
        let pcmd = "p"
    endif

    " surround @@ new objects  "{{{3
    call setreg('"',keeper,regtype)
    if newchar != ""
        call s:wrapreg('"',newchar)
    endif

    " put the result into the original position, then reindent  "{{{3
    silent exe 'norm! ""'.pcmd.'`['
    if removed =~ '\n' || okeeper =~ '\n' || getreg('"') =~ '\n'
        call s:reindent()
    endif
    if getline('.') =~ '^\s\+$' && keeper =~ '^\s*\n'
        silent norm! cc
    endif

    " restore the original value, set some values for later use  "{{{3
    call setreg('"',removed,regtype)
    let s:lastdel = removed
    let &clipboard = cb_save
    if newchar == ""
        silent! call repeat#set("\<Plug>Dsurround".char,scount)
    else
        silent! call repeat#set("\<Plug>Csurround".char.newchar,scount)
    endif
endfunction " }}}1


function! s:changesurround()  "{{{2
    let a = s:inputtarget()
    if a == ""
        return s:beep()
    endif
    let b = s:inputreplacement()
    if b == ""
        return s:beep()
    endif
    call s:dosurround(a,b)
endfunction


function! s:opfunc(type,...)  "{{{2
    let char = s:inputreplacement()
    if char == ""
        return s:beep()
    endif
    let reg = '"'
    let sel_save = &selection
    let &selection = "inclusive"
    let cb_save  = &clipboard
    set clipboard-=unnamed
    let reg_save = getreg(reg)
    let reg_type = getregtype(reg)
    "call setreg(reg,"\n","c")
    let type = a:type
    if a:type == "char"
        silent exe 'norm! v`[o`]"'.reg.'y'
        let type = 'v'
    elseif a:type == "line"
        silent exe 'norm! `[V`]"'.reg.'y'
        let type = 'V'
    elseif a:type ==# "v" || a:type ==# "V" || a:type ==# "\<C-V>"
        silent exe 'norm! gv"'.reg.'y'
    elseif a:type =~ '^\d\+$'
        let type = 'v'
        silent exe 'norm! ^v'.a:type.'$h"'.reg.'y'
        if mode() == 'v'
            norm! v
            return s:beep()
        endif
    else
        let &selection = sel_save
        let &clipboard = cb_save
        return s:beep()
    endif
    let keeper = getreg(reg)
    if type == "v" && a:type != "v"
        let append = matchstr(keeper,'\_s\@<!\s*$')
        let keeper = substitute(keeper,'\_s\@<!\s*$','','')
    endif
    call setreg(reg,keeper,type)
    call s:wrapreg(reg,char,a:0)
    if type == "v" && a:type != "v" && append != ""
        call setreg(reg,append,"ac")
    endif
    silent exe 'norm! gv'.(reg == '"' ? '' : '"' . reg).'p`['
    if type == 'V' || (getreg(reg) =~ '\n' && type == 'v')
        call s:reindent()
    endif
    call setreg(reg,reg_save,reg_type)
    let &selection = sel_save
    let &clipboard = cb_save
    if a:type =~ '^\d\+$'
        silent! call repeat#set("\<Plug>Y".(a:0 ? "S" : "s")."surround".char,a:type)
    else
        silent! call repeat#set("\<Plug>(surround-.)" . char)
    endif
endfunction
nnoremap <Plug>(surround-.)  .

function! s:opfunc2(arg)
    call s:opfunc(a:arg,1)
endfunction


function! s:closematch(str)  "{{{2
    " Close an open (, {, [, or < on the command line.
    let tail = matchstr(a:str,'.[^\[\](){}<>]*$')
    if tail =~ '^\[.\+'
        return "]"
    elseif tail =~ '^(.\+'
        return ")"
    elseif tail =~ '^{.\+'
        return "}"
    elseif tail =~ '^<.+'
        return ">"
    else
        return ""
    endif
endfunction
 

" Trie  "{{{2
"
" trie ::= {'root': node,
"           'default_value': <any value>}
" default-value ::= <any value>
" node ::= {'value': <any value>,
"           'children': {<a part of key (1 char)>: node,
"                        ...}}

let s:trie = {}
let s:FALSE = 0
let s:TRUE = !s:FALSE


function! s:trie.new(default_value)  "{{{3
    let new_instance = copy(s:trie)
    let new_instance.root = s:trie.node.new(a:default_value)
    let new_instance.default_value = a:default_value
    return new_instance
endfunction


function! s:trie.dump()  "{{{3
    echomsg 'Trie:'
    echomsg '  default_value:' string(self.default_value)
    call self.root.dump('root', 1)
endfunction


function! s:trie.put(sequence, value)  "{{{3
    let node = self.root
    let i = 0
    while i < len(a:sequence)
        let item = a:sequence[i]
        if !has_key(node.children, item)
            let node.children[item] = s:trie.node.new(self.default_value)
        endif
        let node = node.children[item]
        let i = i + 1
    endwhile
    let old_value = node.value
    let node.value = a:value
    return old_value
endfunction


function! s:trie.get(sequence, accept_halfway_matchp, ...)  "{{{3
    let default_value = a:0 ? a:1 : self.default_value
    let node = self.root
    let i = 0
    while i < len(a:sequence)
        let item = a:sequence[i]
        if !has_key(node.children, item)
            return default_value
        endif
        let node = node.children[item]
        let i = i + 1
    endwhile

    if node.leafp() || a:accept_halfway_matchp
        return node.value
    else
        return default_value
    endif
endfunction


function! s:trie.take(sequence)  "{{{3
    if len(a:sequence) == 0
        throw 'empty sequence is not allowed'
    endif
    let parent = self.root
    let node = self.root
    let i = 0
    while i < len(a:sequence)
        let item = a:sequence[i]
        if !has_key(node.children, item)
            throw 'value corresponding to the given sequence is not found'
        endif
        let parent = node
        let node = node.children[item]
        let i = i + 1
    endwhile
    return remove(parent.children, item).value
endfunction


function! s:trie.get_incremental(accept_halfway_matchp, ...)  "{{{3
    let state = {}
    let state.accept_halfway_matchp = a:accept_halfway_matchp
    let state.default_value = a:0 ? a:1 : self.default_value
    let state.node = self.root
    let state.i = 0

    function state.feed(item)
        if !has_key(self.node.children, a:item)
            return [s:trie.FAILED, self.default_value]
        endif
        let self.node = self.node.children[a:item]
        let self.i = self.i + 1

        if self.node.leafp() || self.accept_halfway_matchp
            return [s:trie.MATCHED, self.node.value]
        else
            return [s:trie.CONTINUED, self.default_value]
        endif
    endfunction

    return state
endfunction

let s:trie.CONTINUED = ['CONTINUED']
let s:trie.FAILED = ['FAILED']
let s:trie.MATCHED = ['MATCHED']


let s:trie.node = {}  "{{{3

function! s:trie.node.new(value)
    let new_instance = copy(s:trie.node)
    let new_instance.value = a:value
    let new_instance.children = {}
    return new_instance
endfunction

function! s:trie.node.leafp()
    return len(self.children) == 0
endfunction

function! s:trie.node.dump(label, lv)
    echomsg s:indent(a:lv) string(a:label) ':' string(self.value)
    for key in sort(keys(self.children))
        call self.children[key].dump(key, a:lv+1)
    endfor
endfunction




" User-defined surrounding objects  "{{{2

function! s:user_obj_trie(type)
    if a:type ==# 'b'
        if !exists('b:surround_objects')
            let b:surround_objects = s:trie.new('')
        endif
        return b:surround_objects
    else  " a:type ==# 'g'
        if !exists('g:surround_objects')
            let g:surround_objects = s:trie.new('')
        endif
        return g:surround_objects
    endif
endfunction


function! SurroundRegister(type, key, template)
    return s:user_obj_trie(a:type).put(a:key, a:template)
endfunction

function! SurroundUnregister(type, key)
    return s:user_obj_trie(a:type).take(a:key)
endfunction


function! s:user_obj_input(lookahead_c)
    let [result, key] = s:user_obj_input_sub('b', a:lookahead_c)
    if result is s:trie.FAILED
        let [result, key] = s:user_obj_input_sub('g', key)
        if result is s:trie.FAILED
            return [s:FALSE, key]
        endif
    endif

    return [s:TRUE, key]
endfunction

function! s:user_obj_input_sub(type, lookahead_s)
    let state = s:user_obj_trie(a:type).get_incremental(s:FALSE, 'not-used')
    let key = ''
    let i = 0
    while 1
        if i < len(a:lookahead_s)
            let c = a:lookahead_s[i]
            let i += 1
        else
            let c = s:getchar()
        endif
        let [result, _] = state.feed(c)
        let key = key . c
        if result is s:trie.MATCHED
            break
        elseif result is s:trie.FAILED
            break
        else  " result is s:trie.CONTINUED
            " NOP
        endif
    endwhile
    return [result, key]
endfunction


function! s:user_obj_value(key)
    let Template = s:user_obj_trie('b').get(a:key, s:FALSE, '')
    if Template == ''
        let Template = s:user_obj_trie('g').get(a:key, s:FALSE, '')
    endif

    if type(Template) == type('string')
        return Template
    else  " function?
        return Template()
    endif
endfunction




" Misc. functions  "{{{2

function! s:search_literally(pattern, flags)
    return search(s:literalize_pattern(a:pattern), a:flags)
endfunction


function! s:literalize_pattern(pattern)
    return '\V'.substitute(a:pattern, '\', '\\', 'g')
endfunction


function! s:indent(level)
    return repeat('  ', a:level)[1:]
endfunction




" Key Mappings  "{{{1

nnoremap <silent> <Plug>Dsurround  :<C-U>call <SID>dosurround(<SID>inputtarget())<CR>
nnoremap <silent> <Plug>Csurround  :<C-U>call <SID>changesurround()<CR>
nnoremap <silent> <Plug>Yssurround :<C-U>call <SID>opfunc(v:count1)<CR>
nnoremap <silent> <Plug>YSsurround :<C-U>call <SID>opfunc2(v:count1)<CR>
" <C-U> discards the numerical argument but there's not much we can do with it
nnoremap <silent> <Plug>Ysurround  :<C-U>set opfunc=<SID>opfunc<CR>g@
nnoremap <silent> <Plug>YSurround  :<C-U>set opfunc=<SID>opfunc2<CR>g@
vnoremap <silent> <Plug>Vsurround  :<C-U>call <SID>opfunc(visualmode())<CR>
vnoremap <silent> <Plug>VSurround  :<C-U>call <SID>opfunc2(visualmode())<CR>
inoremap <silent> <Plug>Isurround  <C-R>=<SID>insert()<CR>
inoremap <silent> <Plug>ISurround  <C-R>=<SID>insert(1)<CR>

if !exists("g:surround_no_mappings") || ! g:surround_no_mappings
    nmap          ds   <Plug>Dsurround
    nmap          cs   <Plug>Csurround
    nmap          ys   <Plug>Ysurround
    nmap          yS   <Plug>YSurround
    nmap          yss  <Plug>Yssurround
    nmap          ySs  <Plug>YSsurround
    nmap          ySS  <Plug>YSsurround
    if !hasmapto("<Plug>Vsurround","v")
        if exists(":xmap")
            xmap  s    <Plug>Vsurround
        else
            vmap  s    <Plug>Vsurround
        endif
    endif
    if !hasmapto("<Plug>VSurround","v")
        if exists(":xmap")
            xmap  S    <Plug>VSurround
        else
            vmap  S    <Plug>VSurround
        endif
    endif
    if !hasmapto("<Plug>Isurround","i") && "" == mapcheck("<C-S>","i")
        imap     <C-S> <Plug>Isurround
    endif
    imap        <C-G>s <Plug>Isurround
    imap        <C-G>S <Plug>ISurround
    "Implemented internally instead
    "imap     <C-S><C-S> <Plug>ISurround
endif




" Misc.  "{{{1

let &cpo = s:cpo_save

let g:loaded_surround = 1




" __END__  "{{{1
" vim:set ft=vim sw=4 sts=4 et:
