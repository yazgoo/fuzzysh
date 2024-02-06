#!/bin/env sh

remove_ansi_escape_codes() {
  sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2};?)?)?[mGK]//g" 
}

fsh() {
  choices=$(cat)
  filter=""
  result=""
  printf "\e[?1049h"
  while true
  do
    clear >&2
    echo "$choices" | grep -i --color=always "$filter" >&2
    printf "\n> %s" "$filter" >&2
    read -rsn1 key </dev/tty >&2
    case "$key" in
      ' ') filter="$filter " ;;
      '') 
        result=$(echo "$choices" | grep -i "$filter" | tail -1 | head -1 | remove_ansi_escape_codes)
        break
        ;;
      $'\x7f') filter="${filter%?}" ;;
      *) filter="$filter$key" ;;
    esac
  done
  printf "\e[?1049l"
  echo "$result"
}

fsh "@$"
