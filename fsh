#!/bin/env sh

fsh() {

  setup_theme() {
    selector_color=40
    grep_colors='ms=01;92'
    frame_color=30
    prompt_color=34
    select_color=31
  }

  remove_ansi_escape_codes() {
    sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2};?)?)?[mGK]//g" 
  }

  get_new_choices() {
    echo "$choices" | GREP_COLORS="$grep_colors" grep -i --color=always "$filter"
  }

  read_key() {
    # not POSIX
    IFS= read -rsn1 "$1" </dev/tty >&2
  }

  handle_key() {
    read_key key
    case "$key" in
      ' ') filter="$filter " ;;
      $'\x1b') 
        read_key key3
        # arrows
        read_key key2
        case "$key2" in
          'A') [ "$item_n" -lt "$((n_choices - 1))" ] && item_n=$((item_n + 1)) ;;
          'B') [ "$item_n" -gt 0 ] && item_n=$((item_n - 1)) ;;
          *) ;;
        esac
        # flush stdin
        read -rsn5 -t 0.1
        ;;
      '') 
        result=$(echo "$new_choices" | head "-$((item_n + 1))" | tail -1 | remove_ansi_escape_codes)
        running=false
        ;;
      # not POSIX
      $'\x7f') filter="${filter%?}" ;;
      *) filter="${filter}${key}" ;;
    esac
  }

  smcup() {
    stty -echo
    printf "\e[?1049h"
    printf "\e[?25l"
  }

  rmcup() {
    printf "\e[?1049l"
    printf "\e[?25h"
    stty echo
  }

  move_cursor_to() {
    printf "\e[%d;%dH" "$1" "$2"
  }

  start_color() {
    printf "\e[1;%dm" "$1"
  }

  end_color() {
    printf "\e[0m"
  }

  draw_line() {
    move_cursor_to "$((LINES - 2))" 0
    start_color "$frame_color"
    printf "  %s  " "$(printf '─%.0s' $(seq 1 $((COLUMNS - 4))))"
    end_color
  }

  draw_frame() {
    move_cursor_to 0 0
    start_color "$frame_color"
    printf "┌%s┐" "$(printf '─%.0s' $(seq 1 $((COLUMNS - 2))))"
    for i in $(seq 2 $((LINES - 1)))
    do
      move_cursor_to "$i" 0
      printf "│"
      move_cursor_to "$i" $COLUMNS
      printf "│"
    done
    move_cursor_to $LINES 0
    printf "└%s┘" "$(printf '─%.0s' $(seq 1 $((COLUMNS - 2))))"
    end_color
  }
  
  print_text() {
    (
    i="$((n_choices - 1))"
    echo "$new_choices" | tac | while read -r choice
    do
      cursor=" "$(end_color)
      [ $i -eq $item_n ] && cursor=$(printf "%s>%s%s" "$(start_color "$select_color")" "$(end_color)" "$(start_color "$selector_color")")
      printf "\n%s%s %s %s" "$(start_color "$selector_color")" "$cursor" "$choice" "$(end_color)" 
      i=$((i - 1))
    done
    printf "\n%s%d/%d%s%s " "$(start_color "$frame_color")" "$n_choices" "$total_n_choices" "$(end_color)" "$header"
    printf "\n%s>%s %s" "$(start_color "$prompt_color")" "$(end_color)" "$filter" 
    ) | sed 's/^/  /' 
  }

  draw_text() {
    new_choices=$(get_new_choices)
    n_choices=$(echo "$new_choices" | wc -l)
    start_line=$(( LINES -  n_choices - 4))
    # goto start_line
    move_cursor_to $((start_line + 1)) 0
    print_text
  }

  init() {
    setup_theme
    header=""
    [ -n "$1" ] && header=" $1"
    if read -t 0; then
      choices=$(cat)
    else
      choices=$(find . -not -path '*/.*' | sed 's,^./,,')
    fi
    total_n_choices=$(echo "$choices" | wc -l)
    filter=""
    result=""
    running=true
    item_n=0
  }

  do_clear() {
    move_cursor_to $((start_line + 1)) 0
    print_text | remove_ansi_escape_codes | sed 's/./ /g'
  }

  draw() {
    draw_line
    draw_text
    draw_frame
  }

  run() {
    clear >&2
    while $running
    do
      draw >&2
      handle_key >/dev/null 2>&1
      do_clear >&2
    done
  }

  main() {
    init "$@"
    smcup
    run
    rmcup
    if [ -n "$result" ]; then
      echo "$result"
    else
      false
    fi
  }

  main "$@"
}

fsh "$@"
