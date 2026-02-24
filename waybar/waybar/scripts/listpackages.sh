#!/bin/bash

dpkg-query -W --showformat='${Package}\n' | fzf --preview 'dpkg -s {}' --layout=reverse --bind 'enter:execute(dpkg -s {} | less)'
