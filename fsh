#!/bin/env bash

fsh() {
  # https://github.com/yazgoo/fuzzysh/

  setup_theme() {
    # the color line currently highlighted
    selector_color=${FSH_SELECTOR_COLOR:=40}
    # the color of the frame
    frame_color=${FSH_FRAME_COLOR:=30}
    # the color used for the prompt
    prompt_color=${FSH_PROMPT_COLOR:=34}
    # the color of the sign before the line currently selected
    select_color=${FSH_SELECT_COLOR:=31}
  }

  remove_ansi_escape_codes() {
    sed -E "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2};?)?)?[mGK]//g" 2>/dev/null
  }

  generate_choices_nums() {
    new_choices_a=()
    for choice in "${choices_a[@]}"
    do
      if [[ -z "$filter" ]] || [[ "$choice" =~ $fuzzy_filter ]]
      then
        new_choices_a+=("$choice")
      fi
    done
    n_choices=${#new_choices_a[@]}
    display_n_choice="$n_choices"
    [ ${#new_choices_a[@]} -eq 0 ] && display_n_choice=0
    choices_quota="$display_n_choice/$total_n_choices"
    separator_line_size=$((columns - 5 - ${#header} - ${#choices_quota}))
    frame_inner_line="$(draw_frame_inner_line "$separator_line_size")"
  }

  read_key_nominal() {
    if [ "$terminal" = "zsh" ]; then
      IFS= read -rk1 "$1" </dev/tty >&2
    else
      # bash
      IFS= read -rsn1 "$1" </dev/tty >&2
    fi
  }

  read_key_test() {
    if [ "$key_test_i" -lt ${#FSH_TEST_INPUT} ]
    then
      out_key="${FSH_TEST_INPUT:$key_test_i:1}"
      key_test_i=$((key_test_i + 1))
    else
      # shellcheck disable=SC2154,SC2034
      out_key=$'\n'
    fi
    eval "$1=\$out_key"
  }

  read_key() {
    # the simulated user input given as a string, one character at a time. first character will be ignored. if set the script will not read from stdin
    if [ -n "${FSH_TEST_INPUT:=""}" ]
    then
      read_key_test "$1"
    else
      read_key_nominal "$1"
    fi
  }

  handle_arrow_keys() {
    read_key key3
    # arrows
    key2=""
    read_key key2
    case "$key2" in
      'A') [ "$item_n" -lt "$((n_choices - 1))" ] && item_n=$((item_n + 1)) ;;
      'B') [ "$item_n" -gt 0 ] && item_n=$((item_n - 1)) ;;
      *) ;;
    esac
    # flush stdin
    read -rsn5 -t 0.1
  }

  handle_enter_key() {
    index=$((n_choices - item_n - 1))
    [ "$terminal" = "zsh" ] && index=$((index + 1))
    result="${new_choices_a[$index]}"
    running=false
  }

  filter_append_fuzzy() {
    if [ "$terminal" = zsh ]
    then
      lower="${1:l}"
      upper="${1:u}"
    else
      lower="${1,,}"
      upper="${1^^}"
    fi
    [ "$1" = "$upper" ] && lower="$upper"
    fuzzy_filter="${fuzzy_filter}.*[$lower$upper]"
  }

  filter_append() {
    filter="${filter}${1}"
    if [ -n "$no_fuzzy" ]
    then
      fuzzy_filter="${filter}"
    else
      filter_append_fuzzy "$1"
    fi
    generate_choices_nums
  }

  filter_pop_fuzzy() {
    for _ in {1..6}
    do
      fuzzy_filter="${fuzzy_filter%?}"
    done
  }

  filter_pop() {
    filter="${filter%?}"
    if [ -n "$no_fuzzy" ]
    then
      fuzzy_filter="${filter}"
    else
      filter_pop_fuzzy
    fi
    generate_choices_nums
  }

  handle_key() {
    read_key key
    case "$key" in
      ' ') filter_append " ";;
      $'\x1b') handle_arrow_keys ;;
      ''|$'\n') handle_enter_key ;;
      $'\x7f') filter_pop ;;
      *) filter_append "$key" ;;
    esac
  }

  smcup() {
    stty -echo 2>/dev/null
    printf "\e[?1049h" >&2
    printf "\e[?25l" >&2
  }

  rmcup() {
    printf "\e[?1049l" >&2
    printf "\e[?25h" >&2
    stty echo 2>/dev/null
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

  draw_frame_inner_line() {
    for (( i = 0; i < $1; i++ ))
    do
      printf "─"
    done
  }

  draw_frame_top() {
    move_cursor_to 1 1
    printf "┌"
    draw_frame_inner_line "$line_length"
    printf "┐"
  }

  draw_frame_bottom() {
    move_cursor_to "$lines" 1
    printf "└"
    draw_frame_inner_line "$line_length"
    printf "┘"
  }

  draw_frame_vertical_borders() {
    for (( i = 2; i < lines; i++ ))
    do
      move_cursor_to "$i" 1
      printf "│"
      move_cursor_to "$i" "$columns"
      printf "│"
    done
  }

  draw_frame() {
    line_length=$((columns - 2))
    start_color "$frame_color"
    draw_frame_top
    draw_frame_vertical_borders
    draw_frame_bottom
    end_color
  }

  print_choices() {
    i="$((n_choices - 1))"
    for choice in "${new_choices_a[@]}"
    do
      if [ "$i" -gt "$((lines - 5))" ]
      then
        i=$((i - 1))
        continue
      fi
      move_cursor_to "$current_line" 3
      cursor=" "$__end_color
      [ "$i" -eq $item_n ] && cursor="${__start_select_color}>$__end_color$__start_selector_color"
      choice_displayed="${choice:0:$((columns - 8))}"
      printf "%s%s %s %s %*c" "$__start_selector_color" "$cursor" "$choice_displayed" \
        "$__end_color" "$((columns - 7 - ${#choice_displayed}))" " "
      i=$((i - 1))
      current_line=$((current_line + 1))
    done
  }

  print_two_last_text_lines() {
    move_cursor_to "$current_line" 2
    printf " %s%s%s%s %s%s%s" \
      "$__start_frame_color" "$choices_quota" "$__end_color" \
      "$header" \
      "$__start_frame_color" "$frame_inner_line" "$__end_color"

    move_cursor_to "$((current_line + 1))" 2
    printf " %s>%s %s  %*c" \
      "$__start_prompt_color" "$__end_color" \
      "$filter" "$((columns - 8 - ${#filter}))" " "
  }

  print_text() {
    print_choices
    print_two_last_text_lines
  }

  print_whitespaces_content() {
    choices_max=$((lines - n_choices - 2))
    for (( ; current_line < choices_max  ; current_line++ ))
    do
      move_cursor_to "$current_line" 2
      printf " %*.c" "$((columns - 6))" " "
    done
  }

  draw_frame_content() {
    current_line=2
    move_cursor_to "$current_line" 2
    print_whitespaces_content
    print_text
  }

  get_choices() {
    if [ ! -t 0 ]
    then
      choices=$(cat </dev/stdin)
    fi
    if [ -z "$choices" ]
    then
      choices=$(find . ! -path '*/.*' | sed 's,^./,,')
    fi
    if [ "$terminal" = "zsh" ]
    then
      # shellcheck disable=SC2296
      choices_a=("${(f)choices}")
    else
      IFS=$'\n' read -r -d '' -a choices_a <<< "$choices"
    fi
    total_n_choices=${#choices_a[@]}
  }

  init() {
    [ -n "$ZSH_VERSION" ] && terminal="zsh" || terminal="bash"
    setup_theme
    # a name to display beofre the prompt to give context on what is expected
    header="${FSH_HEADER:=""}"
    # (not implemented) set this variable to support vim normal mode
    # vim_mode="${FSH_VIM_MODE:=""}"
    # if this variable is set, will display the time it took to draw the interface
    perf_mode="${FSH_PERF:=""}"
    get_choices
    # if this variable is set, will not use fuzzy search, instead will do a pattern match
    no_fuzzy="${FSH_NO_FUZZY:=""}"
    filter=""
    fuzzy_filter=""
    result=""
    running=true
    item_n=0
    t_lines=$(tput lines) 2>/dev/null
    t_cols=$(tput cols) 2>/dev/null
    # the height of the terminal (used for testing, otherwise will be set by tput)
    lines="${FSH_LINES:=$t_lines}"
    # the width of the terminal (used for testing, otherwise will be set by tput)
    columns="${FSH_COLUMNS:=$t_cols}"
    __end_color=$(end_color)
    __start_frame_color=$(start_color "$frame_color")
    __start_prompt_color=$(start_color "$prompt_color")
    __start_selector_color=$(start_color "$selector_color")
    __start_select_color=$(start_color "$select_color")
    key_test_i=1
    screenshot_n=0
    key=""
    generate_choices_nums
  }

  instrument() {
    start_time_ms=$(date +%s%3N)
    "$1"
    end_time_ms=$(date +%s%3N)
    delta_time="$((end_time_ms - start_time_ms))"
  }

  draw() {
    draw_frame_content
    move_cursor_to "$lines" 2
    [ -n "$perf_mode" ] && printf "%sms" "$delta_time"
  }

  write_screenshot() {
    mkdir -p _screenshot
    screenshot_n=$((screenshot_n + 1))
    import -window "$WINDOWID" "$(printf "_screenshot/screenshot.%00d.jpg" "$screenshot_n")" >/dev/null 2>&1
  }

  do_clear()  {
    printf "\e[2J"
  }

  run() {
    do_clear >&2
    draw_frame >&2
    while $running
    do
      instrument draw >&2
      # if this variable is set, will write a screenshot of the terminal at each iteration and generate an animation at the end
      [ -n "${FSH_SCREENSHOT:=""}" ] && write_screenshot
      handle_key >/dev/null 2>&1
    done
  }

  generate_animation() {
    convert -delay 100 -loop 0 _screenshot/screenshot*.jpg doc/animation.gif
    convert doc/animation.gif -resize 50% doc/animation_small.gif
  }

  main() {
    init "$@"
    smcup
    run
    rmcup
    [ -n "$FSH_SCREENSHOT" ] && generate_animation
    if [ -n "$result" ]; then
       printf "%s\n" "$result"
    else
      false
    fi
  }

  main "$@"
}

fsh "$@"
