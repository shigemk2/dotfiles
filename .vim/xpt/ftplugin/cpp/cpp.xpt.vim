if exists("b:__CPP_CPP_XPT_VIM__")
  finish
endif
let b:__CPP_CPP_XPT_VIM__ = 1

" containers
let [s:f, s:v] = XPTcontainer()

" constant definition
call extend(s:v, {'\$TRUE': '1', '\$FALSE' : '0', '\$NULL' : 'NULL', '\$UNDEFINED' : ''})

" inclusion
XPTinclude
      \ _common/common
      \ _loop/java.like
      \ c/c
      \ c/wrap

" ========================= Function and Varaibles =============================
function! s:f.cleanTempl( ctx, ... )
  let notypename = substitute( a:ctx,"\\s*typename\\s*","","g" )
  let cleaned = substitute( notypename, "\\s*class\\s*", "", "g" )
  return cleaned
endfunction


" ================================= Snippets ===================================

XPTemplateDef

XPT namespace hint=namespace {}
namespace `name^
{
    `cursor^
}
..XPT

XPT class   hint=class+ctor
class `className^
{
public:
    `className^( `ctorParam^ );
    ~`className^();
    `className^( const `className^ &cpy );
    `cursor^
private:
};
 
// Scratch implementation
// feel free to copy/paste or destroy
`className^::`className^( `ctorParam^ )
{
}
 
`className^::~`className^()
{
}
 
`className^::`className^( const `className^ &cpy )
{
}
..XPT


XPT templateclass   hint=template\ <>\ class
template
    <`templateParam^>
class `className^
{
public:
    `className^( `ctorParam^ );
    ~`className^();
    `className^( const `className^ &cpy );
    `cursor^
private:
};
 
// Scratch implementation
// feel free to copy/paste or destroy
template <`templateParam^>
`className^<`^cleanTempl(R('templateParam'))^^>::`className^( `ctorParam^ )
{
}
 
template <`templateParam^>
`className^<`^cleanTempl(R('templateParam'))^^>::~`className^()
{
}
 
template <`templateParam^>
`className^<`^cleanTempl(R('templateParam'))^^>::`className^( const `className^ &cpy )
{
}
..XPT

XPT try hint=try\ ...\ catch...
try
{
    `what^
}`...^
catch ( `except^ )
{
    `handler^
}`...^
`catch...^catch ( ... )
{
    \`cursor\^
}^^
..XPT

