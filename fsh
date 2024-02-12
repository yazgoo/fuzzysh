#!/bin/env sh

fsh() {
  # https://github.com/yazgoo/fuzzysh/

  setup_theme() {
    selector_color=${FSH_SELECTOR_COLOR:=40}
    grep_colors=${FSH_GREP_COLORS:='ms=01;92'}
    frame_color=${FSH_FRAME_COLOR:=30}
    prompt_color=${FSH_PROMPT_COLOR:=34}
    select_color=${FSH_SELECT_COLOR:=31}
  }

  remove_ansi_escape_codes() {
    sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2};?)?)?[mGK]//g" 
  }

  get_new_choices() {
    echo "$choices" | GREP_COLORS="$grep_colors" grep -i --color=always "$filter"
  }

  read_key() {
    # not POSIX
    if [ "$terminal" = "zsh" ]; then
      read -rk1 "$1" </dev/tty >&2
    else
      # bash
      read -rsn1 "$1" </dev/tty >&2
    fi
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
      ''|$'\n') 
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

  draw_frame() {
    move_cursor_to 0 0
    start_color "$frame_color"
    printf "┌%s┐" "$(printf '─%.0s' $(seq 1 $((columns - 2))))"
    for i in $(seq 2 $((lines - 1)))
    do
      move_cursor_to "$i" 0
      printf "│"
      move_cursor_to "$i" $columns
      printf "│"
    done
    move_cursor_to $lines 0
    printf "└%s┘" "$(printf '─%.0s' $(seq 1 $((columns - 2))))"
    end_color
  }
  
  print_text() {
    i="$((n_choices - 1))"
    line_header=$(printf "\n%s│%s " "$(start_color "$frame_color")" "$(end_color)")
    echo "$new_choices" | tac | while read -r choice
    do
      cursor=" "$(end_color)
      [ $i -eq $item_n ] && cursor=$(printf "%s>%s%s" "$(start_color "$select_color")" "$(end_color)" "$(start_color "$selector_color")")
      printf "%s%s%s %s %s%s" "$line_header" "$(start_color "$selector_color")" "$cursor" "$choice" "$(end_color)" "$(printf " %.0s" $(seq 1 $((columns - 6 - ${#choice}))))"
      i=$((i - 1))
    done
    display_n_choice="$n_choices"
    [ "$new_choices" = "" ] && display_n_choice=0
    choices_quota=$(printf "%d/%d" "$display_n_choice" "$total_n_choices")
    printf "%s%s%s%s%s %s%s%s" "$line_header" "$(start_color "$frame_color")" "$choices_quota" "$(end_color)" "$header" $(start_color "$frame_color") "$(printf "─%.0s" $(seq 1 $((columns - 5 - ${#header} - ${#choices_quota}))))" "$(end_color)"
    printf "\n  %s>%s %s %s" "$(start_color "$prompt_color")" "$(end_color)" "$filter" "$(printf " %.0s" $(seq 1 $((columns - 6 - ${#filter}))))"
  }

  print_whitespaces_content() {
    start_line=$(( lines -  n_choices - 4))
    for i in $(seq 2 $((start_line + 1)))
    do
      move_cursor_to "$i" 2
      printf " %0.s" $(seq 1 $((columns - 6)))
    done
  }

  draw_frame_content() {
    new_choices=$(get_new_choices)
    n_choices=$(echo "$new_choices" | wc -l)
    print_whitespaces_content
    print_text
  }

  init() {
    terminal="$(ps -p $$ -o comm=)"
    setup_theme
    header=""
    [ "$#" -gt 1 ] && header=" $1"
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
    lines=$(tput lines)
    columns=$(tput cols)
  }

  draw() {
    draw_frame_content
    draw_frame
  }

  run() {
    clear >&2
    while $running
    do
      draw >&2
      if [ -n "$FSH_SCREENSHOT" ]
      then
        mkdir -p _screenshot
        [ -z "$FSH_SCREENSHOT_N" ] && FSH_SCREENSHOT_N=0
        FSH_SCREENSHOT_N=$((FSH_SCREENSHOT_N + 1))
        import -window "$WINDOWID" "$(printf "_screenshot/screenshot.%00d.jpg" "$FSH_SCREENSHOT_N")" >/dev/null 2>&1
      fi
      handle_key >/dev/null 2>&1
    done
  }

  main() {
    init "$@"
    smcup
    run
    rmcup
    if [ -n "$result" ]; then
      if [ -n "$FSH_SCREENSHOT" ]
      then
        convert -delay 100 -loop 0 _screenshot/screenshot*.jpg doc/animation.gif
        convert doc/animation.gif -resize 50% doc/animation_small.gif
      fi
      echo "$result"
    else
      false
    fi
  }

  main "$@"
}

fsh "$@"
