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
    sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2};?)?)?[mGK]//g" 
  }

  generate_choices_nums() {
    new_choices_a=()
    for choice in "${choices_a[@]}"
    do
      if [[ "$choice" =~ $filter ]]
      then
        new_choices_a+=("$choice")
      fi
    done
    n_choices=${#new_choices_a[@]}
  }

  read_key_nominal() {
    if [ "$terminal" = "zsh" ]; then
      read -rk1 "$1" </dev/tty >&2
    else
      # bash
      read -rsn1 "$1" </dev/tty >&2
    fi
  }

  read_key_test() {
    if [ "$key_test_i" -lt ${#FSH_TEST_INPUT} ]
    then
      key="${FSH_TEST_INPUT:$key_test_i:1}"
      key_test_i=$((key_test_i + 1))
    else
      key=$'\n'
    fi
  }

  read_key() {
    # the simulated user input given as a string, one character at a time. if set the script will not read from stdin
    if [ -n "${FSH_TEST_INPUT:=""}" ]
    then
      read_key_test
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

  handle_key() {
    read_key key
    case "$key" in
      ' ') filter="$filter " ;;
      $'\x1b') handle_arrow_keys ;;
      ''|$'\n') handle_enter_key ;;
      $'\x7f') filter="${filter%?}" ;;
      *) filter="${filter}${key}" ;;
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

  draw_frame() {
    move_cursor_to 0 0
    start_color "$frame_color"
    printf "┌%s┐" "$(printf '─%.0s' $(seq 1 $((columns - 2))))"
    for i in $(seq 2 $((lines - 1)))
    do
      move_cursor_to "$i" 0
      printf "│"
      move_cursor_to "$i" "$columns"
      printf "│"
    done
    move_cursor_to "$lines" 0
    printf "└%s┘" "$(printf '─%.0s' $(seq 1 $((columns - 2))))"
    end_color
  }
  
  print_choices() {
    for choice in "${new_choices_a[@]}"
    do
      cursor=" "$__end_color
      [ $i -eq $item_n ] && cursor="${__start_select_color}>$__end_color$__start_selector_color"
      printf "%s%s%s %s %s %*c" "$line_header" "$__start_selector_color" "$cursor" "$choice" \
        "$__end_color" "$((columns - 6 - ${#choice}))" " "
      i=$((i - 1))
    done
  }

  print_two_last_text_lines() {
    display_n_choice="$n_choices"
    [ ${#new_choices_a[@]} -eq 0 ] && display_n_choice=0
    choices_quota="$display_n_choice/$total_n_choices"
    printf "%s%s%s%s%s %s%s%s\n  %s>%s %s  %*c" "$line_header" "$__start_frame_color" "$choices_quota" \
      "$__end_color" "$header" "$__start_frame_color" \
      "$(printf "─%.0s" $(seq 1 $((columns - 5 - ${#header} - ${#choices_quota}))))" "$__end_color" \
      "$__start_prompt_color" "$__end_color" \
      "$filter" "$((columns - 6 - ${#filter}))" " " 
  }

  print_text() {
    i="$((n_choices - 1))"
    print_choices
    print_two_last_text_lines
  }

  print_whitespaces_content() {
    start_line=$(( lines -  n_choices - 4))
    i=2
    end=$((start_line + 1))
    while [ $i -lt $end ]
    do
      move_cursor_to "$i" 2
      printf " %*.c" "$((columns - 6))" " "
      i=$((i + 1))
    done
  }

  draw_frame_content() {
    generate_choices_nums
    print_whitespaces_content
    print_text
  }

  get_choices() {
    if [ "$terminal" = zsh ] && [ ! -t 0 ]
    then
      choices=$(cat </dev/stdin)
    elif [ "$terminal" != zsh ] && read -r -t0
    then
      choices=$(cat </dev/stdin)
    fi
    if [ -z "$choices" ]
    then
      choices=$(find . -not -path '*/.*' | sed 's,^./,,')
    fi
    if [ "$terminal" = "zsh" ]
    then
      # shellcheck disable=SC2296
      choices_a=("${(f)choices}")
    else
      IFS=$'\n' read -r -d '' -a choices_a <<< "$choices"
    fi
    total_n_choices=$(echo "$choices" | wc -l)
  }

  init() {
    terminal="$(ps -p $$ -o comm=)"
    setup_theme
    # a name to display beofre the prompt to give context on what is expected
    header="${FSH_HEADER:=""}"
    # (not implemented) set this variable to support vim normal mode
    vim_mode="${FSH_VIM_MODE:=""}"
    # if this variable is set, will display the time it took to draw the interface
    perf_mode="${FSH_PERF:=""}"
    get_choices
    filter=""
    result=""
    running=true
    item_n=0
    lines=$(tput lines)
    columns=$(tput cols)
    __end_color=$(end_color)
    __start_frame_color=$(start_color "$frame_color")
    __start_prompt_color=$(start_color "$prompt_color")
    __start_selector_color=$(start_color "$selector_color")
    __start_select_color=$(start_color "$select_color")
    line_header=$(printf "\n%s│%s " "$__start_frame_color" "$__end_color")
    key_test_i=0
    screenshot_n=0
  }

  instrument() {
    start_time_ms=$(date +%s%3N)
    "$1"
    end_time_ms=$(date +%s%3N)
    delta_time="$((end_time_ms - start_time_ms))"
  }

  draw() {
    draw_frame_content
    draw_frame
    move_cursor_to "$lines" 2
    [ -n "$perf_mode" ] && printf "%sms" "$delta_time"
  }

  write_screenshot() {
    mkdir -p _screenshot
    screenshot_n=$((screenshot_n + 1))
    import -window "$WINDOWID" "$(printf "_screenshot/screenshot.%00d.jpg" "$screenshot_n")" >/dev/null 2>&1
  }

  run() {
    clear >&2
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
      echo "$result"
    else
      false
    fi
  }

  main "$@"
}

fsh "$@"
