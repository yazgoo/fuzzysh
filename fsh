#!/bin/env sh

fsh() {

  setup_theme() {
    grep_colors='ms=01;92'
    frame_color=30
    prompt_color=34
  }

  remove_ansi_escape_codes() {
    sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2};?)?)?[mGK]//g" 
  }

  get_new_choices() {
    echo "$choices" | GREP_COLORS="$grep_colors" grep -i --color=always "$filter"
  }

  read_key() {
    # not POSIX
    read -rsn1 key </dev/tty >&2
  }

  handle_key() {
    read_key
    case "$key" in
      ' ') filter="$filter " ;;
      '') 
        result=$(echo "$choices" | grep -i "$filter" | tail -1 | head -1 | remove_ansi_escape_codes)
        running=false
        ;;
      # not POSIX
      $'\x7f') filter="${filter%?}" ;;
      *) filter="$filter$key" ;;
    esac
  }

  smcup() {
    printf "\e[?1049h"
    printf "\e[?25l"
  }

  rmcup() {
    printf "\e[?1049l"
    printf "\e[?25h"
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
    (
    move_cursor_to "$((LINES - 2))" 0
    start_color "$frame_color"
    printf "  %s  " "$(printf '─%.0s' $(seq 1 $((COLUMNS - 4))))"
    end_color
    ) >&2
  }

  draw_frame() {
    (
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
    ) >&2
  }
  
  print_text() {
    (
    printf "\n%s\n" "$new_choices" | tac -b
    printf "\n%s%d/%d%s%s " "$(start_color "$frame_color")" "$n_choices" "$total_n_choices" "$(end_color)" "$header"
    printf "\n%s>%s %s" "$(start_color "$prompt_color")" "$(end_color)" "$filter" 
    ) | sed 's/^/  /' 
  }

  draw() {
    new_choices=$(get_new_choices)
    n_choices=$(echo "$new_choices" | wc -l)
    start_line=$(( LINES -  n_choices - 4))
    # goto start_line
    (
    move_cursor_to $start_line 0
    print_text
    ) >&2
  }

  init() {
    setup_theme
    header=""
    [ -n "$1" ] && header=" $1"
    choices=$(cat)
    total_n_choices=$(echo "$choices" | wc -l)
    filter=""
    result=""
    running=true
  }

  do_clear() {
    # move_cursor_to $start_line 0
    # print_text | sed 's/./  /g' >&2
    clear >&2
  }

  run() {
    clear >&2
    while $running
    do
      draw_line
      draw
      draw_frame
      handle_key
      do_clear
    done
  }

  main() {
    init "$@"
    smcup
    run
    rmcup
    echo "$result"
  }

  main "$@"
}

fsh "$@"
