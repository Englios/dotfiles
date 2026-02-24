# vim:ft=zsh ts=2 sw=2 sts=2
#
# Begin a segment
# Takes two arguments, background and foreground. Both can be omitted,
# rendering default background/foreground.

prompt_segment() {
    local fg
    [[ -n $1 ]] && fg="%F{$1}" || fg="%f"
    echo -n "%{$fg%}"
    [[ -n $2 ]] && echo -n "%b$2%B "
}

# End the prompt, closing any open segments
prompt_end() {
    echo -n "%{%f%}"
}

### Prompt components
# Each component will draw itself, and hide itself if no information needs to be shown

# Context: user@hostname (who am I and where am I)
prompt_context() {
    # if [[ "$USER" != "$DEFAULT_USER" || -n "$SSH_CLIENT" ]]; then
    # prompt_segment 237 7 "%(!.%{%F{3}%}.)%n@%m"
    # fi
    case "$OSTYPE" in
        darwin*)  OS_LOGO="\ue29e" ;;
        linux*)   OS_LOGO="\ue712" ;;
    esac
    prompt_segment 15 $OS_LOGO
}

# Git: branch/detached head, dirty status
function +vi-git-st() {
    local ahead behind
    local -a gitstatus

    # Exit early in case the worktree is on a detached HEAD
    #git rev-parse ${hook_com[branch]}@{upstream} >/dev/null 2>&1 || return 0

    local -a ahead_and_behind=(
        $(git rev-list --left-right --count HEAD...${hook_com[branch]}@{upstream} 2>/dev/null)
    )
    local -a stat=("$(git status --porcelain)")
    local -a untracked=(
        $(echo "$stat" | grep '^??' | wc -l)
    )
    local -a modified=(
        $(echo "$stat" | grep '^.M' | wc -l)
    )
    local -a staged=(
        $(echo "$stat" | grep '^[AM]' | wc -l)
    )

    ahead=${ahead_and_behind[1]}
    behind=${ahead_and_behind[2]}

    (( $modified )) && gitstatus+=( "%{\033[1m%}${modified}●" )
    (( $staged )) && gitstatus+=( "%{\033[1m%}${staged}" )
    (( $untracked )) && gitstatus+=( "%{\033[1m%}${untracked}" )
    (( $ahead )) && gitstatus+=( '' )
    (( $behind )) && gitstatus+=( '' )

    if [[ gitstatus != '' ]] then
        hook_com[misc]+=''
    fi
    hook_com[misc]+=${(j:  :)gitstatus}
}

prompt_git() {
    (( $+commands[git] )) || return
    if [[ "$(git config --get oh-my-zsh.hide-status 2>/dev/null)" = 1 ]]; then
        return
    fi
    local PL_BRANCH_CHAR
    () {
        local LC_ALL="" LC_CTYPE="en_US.UTF-8"
        PL_BRANCH_CHAR=$'\ue0a0'         # 
    }
    local ref dirty mode repo_path

    if $(git rev-parse --is-inside-work-tree >/dev/null 2>&1); then
        repo_path=$(git rev-parse --git-dir 2>/dev/null)
        dirty=$(parse_git_dirty)
        ref=$(git symbolic-ref HEAD 2> /dev/null) || ref="➦ $(git rev-parse --short HEAD 2> /dev/null)"
        if [[ -n $dirty ]]; then
            prompt_segment 3
        else
            prompt_segment 2
        fi

        if [[ -e "${repo_path}/BISECT_LOG" ]]; then
            mode=" <B>"
        elif [[ -e "${repo_path}/MERGE_HEAD" ]]; then
            mode=" >M<"
        elif [[ -e "${repo_path}/rebase" || -e "${repo_path}/rebase-apply" || -e "${repo_path}/rebase-merge" || -e "${repo_path}/../.dotest" ]]; then
            mode=" >R>"
        fi

        setopt promptsubst
        autoload -Uz vcs_info

        zstyle ':vcs_info:*' enable git
        zstyle ':vcs_info:*' get-revision true
        zstyle ':vcs_info:*' check-for-changes true
        #zstyle ':vcs_info:*' stagedstr ''
        #zstyle ':vcs_info:*' unstagedstr '●'
        zstyle ':vcs_info:*' formats ' %m'
        zstyle ':vcs_info:*' actionformats ' %m'
        zstyle ':vcs_info:git*+set-message:*' hooks git-st
        vcs_info
        echo -n "[ ${ref/refs\/heads\//$PL_BRANCH_CHAR }${vcs_info_msg_0_%% }${mode} ]"
    fi
}

prompt_bzr() {
    (( $+commands[bzr] )) || return
    if (bzr status >/dev/null 2>&1); then
        status_mod=`bzr status | head -n1 | grep "modified" | wc -m`
        status_all=`bzr status | head -n1 | wc -m`
        revision=`bzr log | head -n2 | tail -n1 | sed 's/^revno: //'`
        if [[ $status_mod -gt 0 ]] ; then
            prompt_segment 3
            echo -n "bzr@"$revision "✚ "
        else
            if [[ $status_all -gt 0 ]] ; then
                prompt_segment 3
                echo -n "bzr@"$revision

            else
                prompt_segment 2
                echo -n "bzr@"$revision
            fi
        fi
    fi
}

prompt_hg() {
    (( $+commands[hg] )) || return
    local rev st branch
    if $(hg id >/dev/null 2>&1); then
        if $(hg prompt >/dev/null 2>&1); then
            if [[ $(hg prompt "{status|unknown}") = "?" ]]; then
                # if files are not added
                prompt_segment 1
                st='±'
            elif [[ -n $(hg prompt "{status|modified}") ]]; then
                # if any modification
                prompt_segment 3
                st='±'
            else
                # if working copy is clean
                prompt_segment 2
            fi
            echo -n $(hg prompt "☿ {rev}@{branch}") $st
        else
            st=""
            rev=$(hg id -n 2>/dev/null | sed 's/[^-0-9]//g')
            branch=$(hg id -b 2>/dev/null)
            if `hg st | grep -q "^\?"`; then
                prompt_segment 1
                st='±'
            elif `hg st | grep -q "^[MA]"`; then
                prompt_segment 3
                st='±'
            else
                prompt_segment 2
            fi
            echo -n "☿ $rev@$branch" $st
        fi
    fi
}

# Dir: current working directory
prompt_dir() {
    prompt_segment 4 '%~'
}

# Virtualenv: current working virtualenv
prompt_virtualenv() {
    local virtualenv_path="$VIRTUAL_ENV"
    if [[ -n $virtualenv_path && -n $VIRTUAL_ENV_DISABLE_PROMPT ]]; then
        prompt_segment 5 "(`basename $virtualenv_path`)"
    fi
}


# Status:
# - was there an error
# - am I root
# - are there background jobs?
prompt_status() {
    local -a symbols

    symbols+="%{%F{6}%}%1(j. .)"
    [[ $RETVAL -ne 0 ]] && symbols+="%{%F{9}%}"
    [[ $UID -eq 0 ]] && symbols+="%{%F{3}%}󱐋"
    [[ -n "$symbols" ]] && prompt_segment 0 "$symbols"
}

VI_INSERT_SEG=" "
VI_NORMAL_SEG=" "
VI_INSERT_COLOUR=12
VI_NORMAL_COLOUR=15
VI_MODE_PROMPT_SEG=$VI_INSERT_SEG
VI_MODE_COLOUR=$VI_INSERT_COLOUR
zle-keymap-select() {
    if [ "${KEYMAP}" = 'vicmd' ]; then
        VI_MODE_PROMPT_SEG=$VI_NORMAL_SEG
        VI_MODE_COLOUR=$VI_NORMAL_COLOUR
    else
        VI_MODE_PROMPT_SEG=$VI_INSERT_SEG
        VI_MODE_COLOUR=$VI_INSERT_COLOUR
    fi
    zle reset-prompt

    if [[ ${KEYMAP} == vicmd ]] ||
    [[ $1 = 'block' ]]; then
        echo -ne '\e[1 q'

    elif [[ ${KEYMAP} == main ]] ||
    [[ ${KEYMAP} == viins ]] ||
    [[ ${KEYMAP} = '' ]] ||
    [[ $1 = 'beam' ]]; then
        echo -ne '\e[5 q'
    fi

}
zle -N zle-keymap-select

zle-line-finish() {
    VI_MODE_PROMPT_SEG=$VI_INSERT_SEG
    VI_MODE_COLOUR=$VI_INSERT_COLOUR
}
zle -N zle-line-finish

TRAPINT() {
    VI_MODE_PROMPT_SEG=$VI_INSERT_SEG
    VI_MODE_COLOUR=$VI_INSERT_COLOUR
    return $(( 128 + $1 ))
}

prompt_vi() {
    prompt_segment $VI_MODE_COLOUR "%{\033[1m%}"$VI_MODE_PROMPT_SEG
}
## Main prompt
top_prompt() {
    RETVAL=$?
    echo -n ""
    prompt_status
    prompt_virtualenv
    #prompt_context
    prompt_dir
    prompt_git
    prompt_bzr
    prompt_hg
}

PROMPT='╭─$(top_prompt;prompt_end)
╰─$(prompt_vi;prompt_end)'

