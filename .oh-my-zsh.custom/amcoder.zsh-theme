
local user='%{$fg[yellow]%}%n@%{$fg[yellow]%}%m%{$reset_color%}'
local pwd='%{$fg[blue]%}%~%{$reset_color%}'
local rvm=''
# if which rvm-prompt &> /dev/null; then
#   rvm='%{$fg[green]%}‹$(rvm-prompt i v g)›%{$reset_color%} '
# else
#   if which rbenv &> /dev/null; then
#     rvm='%{$fg[green]%}‹$(rbenv version | sed -e "s/ (set.*$//")›%{$reset_color%} '
#   fi
# fi
local return_code='%(?..%{$fg[red]%}%? ↵ %{$reset_color%})'
local git_branch='$(git_prompt_status)%{$reset_color%}$(git_prompt_info)%{$reset_color%} '
local jobs='%(1j.%{$fg_bold[green]%}(%j jobs) %{$reset_color%}.)'
local time='%{$fg_bold[green]%}[%T]%{$reset_color%}'
local vi='$(vi_mode_prompt_info) '

ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg[green]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_DIRTY=""
ZSH_THEME_GIT_PROMPT_CLEAN=""

ZSH_THEME_GIT_PROMPT_ADDED="%{$fg[green]%}✚"
ZSH_THEME_GIT_PROMPT_MODIFIED="%{$fg[blue]%}✹"
ZSH_THEME_GIT_PROMPT_DELETED="%{$fg[red]%}✖"
ZSH_THEME_GIT_PROMPT_RENAMED="%{$fg[magenta]%}➜"
ZSH_THEME_GIT_PROMPT_UNMERGED="%{$fg[yellow]%}═ "
ZSH_THEME_GIT_PROMPT_UNTRACKED="%{$fg[cyan]%}✭"
ZSH_THEME_GIT_PROMPT_AHEAD="%{$fg[cyan]%}↑"
ZSH_THEME_GIT_PROMPT_BEHIND="%{$fg[cyan]%}↓"
ZSH_THEME_GIT_PROMPT_DIVERGED="%{$fg[cyan]%}⬍"

PROMPT="
${user}:${pwd}$ "
RPROMPT="${vi}${return_code}${git_branch}${rvm}${jobs}${time}"
