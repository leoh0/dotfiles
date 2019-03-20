#!/bin/bash

#
# ~/.bashrc
#

[[ $- != *i* ]] && return

colors() {
	local fgc bgc vals seq0

	# shellcheck disable=SC2016
	printf "Color escapes are %s\\n" '\e[${value};...;${value}m'
	printf "Values 30..37 are \\e[33mforeground colors\\e[m\\n"
	printf "Values 40..47 are \\e[43mbackground colors\\e[m\\n"
	printf "Value  1 gives a  \\e[1mbold-faced look\\e[m\\n\\n"

	# foreground colors
	for fgc in {30..37}; do
		# background colors
		for bgc in {40..47}; do
			fgc=${fgc#37} # white
			bgc=${bgc#40} # black

			vals="${fgc:+$fgc;}${bgc}"
			vals=${vals%%;}

			seq0="${vals:+\\e[${vals}m}"
			printf "  %-9s" "${seq0:-(default)}"
    	# shellcheck disable=SC2059
			printf "${seq0}TEXT\\e[m"
    	# shellcheck disable=SC2059
			printf "\\e[${vals:+${vals+$vals;}}1mBOLD\\e[m"
		done
		echo; echo
	done
}

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
        # shellcheck disable=SC2015
        test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
        alias ls='ls --color=auto'
        alias dir='dir --color=auto'
        alias vdir='vdir --color=auto'

        alias grep='grep --color=auto'
        alias fgrep='fgrep --color=auto'
        alias egrep='egrep --color=auto'
fi

# Add an "alert" alias for long running commands.  Use like so:
#       sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# shellcheck source=/dev/null
[ -r /usr/share/bash-completion/bash_completion ] && . /usr/share/bash-completion/bash_completion

# Change the window title of X terminals
case ${TERM} in
	xterm*|rxvt*|Eterm*|aterm|kterm|gnome*|interix|konsole*)
		PROMPT_COMMAND='echo -ne "\033]0;${USER}@${HOSTNAME%%.*}:${PWD/#$HOME/\~}\007"'
		;;
	screen*)
		PROMPT_COMMAND='echo -ne "\033_${USER}@${HOSTNAME%%.*}:${PWD/#$HOME/\~}\033\\"'
		;;
esac

xhost +local:root > /dev/null 2>&1

complete -cf sudo

# Bash won't get SIGWINCH if another process is in the foreground.
# Enable checkwinsize so that bash will check the terminal size when
# it regains control.  #65623
# http://cnswww.cns.cwru.edu/~chet/bash/FAQ (E11)
shopt -s checkwinsize

shopt -s expand_aliases

# export QT_SELECT=4

# Enable history appending instead of overwriting.  #139609
shopt -s histappend

# Case-insensitive globbing (used in pathname expansion)
shopt -s nocaseglob

# Autocorrect typos in path names when using `cd`
shopt -s cdspell

# Enable some Bash 4 features when possible:
# * `autocd`, e.g. `**/qux` will enter `./foo/bar/baz/qux`
# * Recursive globbing, e.g. `echo **/*.txt`
for option in autocd globstar; do
        shopt -s "$option" 2> /dev/null
done

# Add tab completion for SSH hostnames based on ~/.ssh/config
# ignoring wildcards
[[ -e "$HOME/.ssh/config" ]] && complete -o "default" \
        -o "nospace" \
        -W "$(grep "^Host" ~/.ssh/config | \
        grep -v "[?*]" | cut -d " " -f2 | \
        tr ' ' '\n')" scp sftp ssh

# source kubectl bash completion
if hash kubectl 2>/dev/null; then
        # shellcheck source=/dev/null
        source <(kubectl completion bash)
fi

# Start the gpg-agent if not already running
if ! pgrep -x -u "${USER}" gpg-agent >/dev/null 2>&1; then
        gpg-connect-agent /bye >/dev/null 2>&1
fi
gpg-connect-agent updatestartuptty /bye >/dev/null
# use a tty for gpg
# solves error: "gpg: signing failed: Inappropriate ioctl for device"
GPG_TTY=$(tty)
export GPG_TTY
# Set SSH to use gpg-agent
unset SSH_AGENT_PID
if [ "${gnupg_SSH_AUTH_SOCK_by:-0}" -ne $$ ]; then
        if [[ -z "$SSH_AUTH_SOCK" ]] || [[ "$SSH_AUTH_SOCK" == *"apple.launchd"* ]]; then
                SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"
                export SSH_AUTH_SOCK
        fi
fi
# add alias for ssh to update the tty
alias ssh="gpg-connect-agent updatestartuptty /bye >/dev/null; ssh"

#
# # ex - archive extractor
# # usage: ex <file>
ex ()
{
  if [ -f "$1" ] ; then
    case $1 in
      *.tar.bz2)   tar xjf "$1"   ;;
      *.tar.gz)    tar xzf "$1"   ;;
      *.bz2)       bunzip2 "$1"   ;;
      *.rar)       unrar x "$1"     ;;
      *.gz)        gunzip "$1"    ;;
      *.tar)       tar xf "$1"    ;;
      *.tbz2)      tar xjf "$1"   ;;
      *.tgz)       tar xzf "$1"   ;;
      *.zip)       unzip "$1"     ;;
      *.Z)         uncompress "$1";;
      *.7z)        7z x "$1"      ;;
      *)           echo "'$1' cannot be extracted via ex()" ;;
    esac
  else
    echo "'$1' is not a valid file"
  fi
}

# better yaourt colors
export YAOURT_COLORS="nb=1:pkg=1:ver=1;32:lver=1;45:installed=1;42:grp=1;34:od=1;41;5:votes=1;44:dsc=0:other=1;35"

# __kga_select__() {
#  local map=$(kubectl get all --show-labels=true --all-namespaces | grep -v '^NAMESPACE')
#  echo "${map}" | fzf -x -e +s --reverse --bind=left:page-up,right:page-down --no-mouse | awk '{print $2" --namespace "$1}'
# }
# __kga_widget__() {
#   local selected="$(__kga_select__)"
#   READLINE_LINE="${READLINE_LINE:0:$READLINE_POINT}$selected${READLINE_LINE:$READLINE_POINT}"
#   READLINE_POINT=$(( READLINE_POINT + ${#selected} ))
# }

# bind '"\er": redraw-current-line'
# if [ $BASH_VERSINFO -gt 3 ]; then
#   stty -ixon
#   bind -x '"\C-q": "__kga_widget__"'
# else
#   stty -ixon
#   bind '"\C-q": " \C-u \C-a\C-k`__kga_select__`\e\C-e\C-y\C-a\C-y\ey\C-h\C-e\er \C-h"'
# fi

# fzf
# shellcheck source=/dev/null
. /usr/share/fzf/key-bindings.bash
# shellcheck source=/dev/null
. /usr/share/fzf/completion.bash

# https://wiki.archlinux.org/index.php/Xorg/Keyboard_configuration#Using_xset
xset r rate 250 60

for file in ~/.{bash_prompt,aliases,functions,path,dockerfunc,extra,exports}; do
        if [[ -r "$file" ]] && [[ -f "$file" ]]; then
                # shellcheck source=/dev/null
                source "$file"
        fi
done
unset file

# autoenv
if [ -d "$HOME/.autoenv/" ]; then
        # shellcheck source=/dev/null
        source "$HOME/.autoenv/activate.sh"
fi 

# pyenv
if [ -d "$HOME/.pyenv/" ]; then
        export PATH="/home/al/.pyenv/bin:$PATH"
        eval "$(pyenv init -)"
        eval "$(pyenv virtualenv-init -)"

        # activate py36
        pyenv activate py36
fi
