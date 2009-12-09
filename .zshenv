# vim:set fdm=marker:

# Basic {{{
export PATH="$PATH:/usr/local/bin:$HOME/local/bin:$HOME/bin:$HOME/private-bin"
if [ -x "$(which vim)" ]; then
    export EDITOR="$(which vim)"
elif [ -x "$(which vi)" ]; then
    export EDITOR="$(which vi)"
fi
export LESS="--LONG-PROMPT --RAW-CONTROL-CHARS"
export PAGER=less

# gisty
export GISTY_DIR="$HOME/work/gisty"


eval `dircolors`
# export LS_COLORS='di=36:ln=35:so=32:pi=33:ex=31:bd=46;34:cd=43;34:su=41;30:sg=46;30:tw=42;30:ow=43;30'
# export LS_COLORS='di=34:ln=35:so=32:pi=33:ex=31:bd=46;34:cd=43;34:su=41;30:sg=46;30:tw=42;30:ow=43;30'


# for cygwin
OS=$(uname -o)
if [ "$OS" = "Cygwin" ]; then
    export LESS="MrXEd --dumb"
    export TERM=cygwin
    export CFLAGS="-I/usr/local/include -I/usr/include"
    export LANG=ja_JP.SJIS
fi


### local ###

if [ -e "$HOME/.env.local" ]; then
    source "$HOME/.env.local"
fi
# }}}

export HISTFILE=~/.zsh_history
export HISTSIZE=1000
export SAVESIZE=1000
export LISTMAX=0
