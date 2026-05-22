# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# if [[ $(uname -m) == arm* ]]; then
#     source /opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme
# elif [[ $(uname -m) == x86* ]]; then
#     source "$HOME/powerlevel10k/powerlevel10k.zsh-theme"
# fi
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
# if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
#   source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
# fi

if [[ $OSTYPE == darwin* ]]; then
    echo "OS: MacOs"
    export PATH="$HOME/.emacs.d/bin:$PATH"
    export PATH="$HOME/homebrew/bin:$PATH"
    export PATH="$HOME/homebrew/sbin:$PATH"
    export PATH="$PATH:/Users/Andy/.local/bin"
    export PATH="/Users/Andy/.config/emacs/bin:$PATH"
    export PATH="/Users/Andy/Library/Python/3.9/bin:$PATH"
    export PATH="/Users/Andy/lldb/lldb-mi/src:$PATH"

    if [[ $MACHTYPE == x86* ]]; then
    # alias emacs="open -a ~/Applications/Emacs.app"
    # alias em="~/Applications/Emacs.app/Contents/MacOs/bin/emacsclient -cn"
    #alias emst='emacs --bg-daemon'
    alias code='open -a /Applications/Visual\ Studio\ Code.app'
    alias emst='emacs --daemon'

    elif [[ $MACHTYPE == arm* ]]; then
        echo "Apple silicon."
    fi

elif [[ "$OSTYPE" =~ "linux" && ! "$XDG_SESSION_TYPE" =~ "wayland" ]]; then
    # only set xkbmap if we're on linux and not using wayland, since wayland compositors handle this differently
    echo "Running on Linux with X11, setting xkbmap to us."
    setxkbmap us
    echo "OS: Linux"
fi

export PATH="/usr/local/opt/llvm/bin:$PATH"
export PATH="/usr/local/sbin:$PATH"
export PATH="/usr/local/opt/ncurses/bin:$PATH"
export PATH="${HOME}/.local/bin:$PATH"
export LDFLAGS="-L/usr/local/opt/ncurses/lib"
export CPPFLAGS="-I/usr/local/opt/ncurses/include"
export PKG_CONFIG_PATH="/usr/local/opt/ncurses/lib/pkgconfig"
alias ls='ls --color'
export PATH="/usr/local/opt/m4/bin:$PATH"
alias gconf='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'
alias fzfp="fzf --preview='cat {}'"


export PATH="/usr/local/Cellar/gdb/13.1/bin:$PATH"
alias emc="emacsclient -nc &"
alias emct="emacsclient -t"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

source $HOME/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source $HOME/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
source $HOME/.zsh/zsh-autocomplete/zsh-autocomplete.plugin.zsh

export PATH="/usr/local/opt/python@3.11:$PATH"
export PATH="/usr/local/opt/sqlite/bin:$PATH"
export PATH="/usr/local/bin:$PATH"
export PATH="/usr/local/Cellar/gdb/13.2/bin:$PATH"

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/opt/homebrew/Caskroom/miniconda/base/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/opt/homebrew/Caskroom/miniconda/base/etc/profile.d/conda.sh" ]; then
        . "/opt/homebrew/Caskroom/miniconda/base/etc/profile.d/conda.sh"
    else
        export PATH="/opt/homebrew/Caskroom/miniconda/base/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<
#
export PATH="/opt/nvim-linux64/bin:$PATH"

# zoxide init
eval "$(zoxide init zsh)"


# vim:et:ts=4:sw=4
#
#// SPDX-License-Identifier: Apache-2.0

# Example hook to change profile based on directory.
# update_profile()
# {
#     case "$PWD" in
#         "$HOME"/work*) contour set profile to work ;;
#         "$HOME"/projects*) contour set profile to main ;;
#         *) contour set profile to mobile ;;
#     esac
# }

autoload -Uz add-zsh-hook

precmd_hook_contour()
{
    # Disable text reflow for the command prompt (and below).
    print -n '\e[?2028l' >$TTY

    # Marks the current line (command prompt) so that you can jump to it via key bindings.
    echo -n '\e[>M' >$TTY

    # Informs contour terminal about the current working directory, so that e.g. OpenFileManager works.
    echo -ne '\e]7;'$(pwd)'\e\\' >$TTY

    # Example hook to update configuration profile based on base directory.
    # update_profile >$TTY
}

preexec_hook_contour()
{
    # Enables text reflow for the main page area again, so that a window resize will reflow again.
    print -n "\e[?2028h" >$TTY
}

add-zsh-hook precmd precmd_hook_contour
add-zsh-hook preexec preexec_hook_contour
source $HOME/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source $HOME/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
source $HOME/.zsh/zsh-autocomplete/zsh-autocomplete.plugin.zsh

# make ripgrep alternative for grep if it exists
if command -v rg >/dev/null 2>&1; then
    alias grep='rg'
fi

set -o vi
export EDITOR=nvim
# eval "$(starship init zsh)"

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/anlhr/Downloads/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/anlhr/Downloads/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/anlhr/Downloads/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/anlhr/Downloads/google-cloud-sdk/completion.zsh.inc'; fi

# alias gconf='/usr/bin/git --git-dir=$HOME/.cfg.git/ --work-tree=$HOME'
# source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme
# source ~/powerlevel10k/powerlevel10k.zsh-theme


# if tmux sessionizer exists, alias to ts
#


if [ -d "$HOME/tmux-sessionizer" ]; then
    alias ts="${HOME}/tmux-sessionizer/tmux-sessionizer"
fi

if command -v starship >/dev/null 2>&1; then
    eval "$(starship init zsh)"
else 
    if [[ -f /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme ]]; then
        source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme
    fi
fi

