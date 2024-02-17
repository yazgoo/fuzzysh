#!/bin/zsh
if [ -z "$QUIET" ]
then
  set -x
fi

🧪() {
  choices="$1"
  user_input="$2"
  fuzzy="$3"
  [[ "$fuzzy" = 🔳 ]] || no_fuzzy=✅
  fails="$4"
  expected_result="$5"
  expected_stderr="$6"
  echo "run shell=$shell choices=$choices user_input=$user_input expected_result=$expected_result result=$result"
  tmp_out="$(mktemp)"
  export FSH_COLUMNS=15
  export FSH_LINES=10
  if [ -z "$choices" ]
  then
    result="$(FSH_NO_FUZZY="$no_fuzzy" FSH_TEST_INPUT="y$user_input" "$shell" ./fsh 2> "$tmp_out")"
  else
    result="$(echo -e "$choices"| FSH_NO_FUZZY="$no_fuzzy" FSH_TEST_INPUT="y$user_input" "$shell" ./fsh 2> "$tmp_out")"
  fi
  rc=$?
  if [ "$fails" = ✅ ]
  then
    if [[ "$rc" -eq 0 ]]
    then
      echo "expected failure, got $rc"
      return 1
    fi
  else
    if [[ "$rc" -ne 0 ]]
    then
      echo "expected success, got $rc"
      return 1
    fi
  fi
  echo "got shell=$shell choices=$choices user_input=$user_input expected_result=$expected_result result=$result"
  if [[ "$result" != "$expected_result" ]]
  then
    echo "expected $expected_result, got $result"
    return 1
  fi
  if [ -n "$expected_stderr" ]
  then
    diff <(cat "$tmp_out"  | ./terminal_emulator_render.rb -r "$FSH_LINES" -c "$FSH_COLUMNS" -f) "$expected_stderr"
    if [[ "$?" -ne 0 ]]
    then
      echo "wrong stderr (expected $expected_stderr)"
      return 1
    fi
  fi
}

up="$(echo '\x1b')[A"
down="$(echo '\x1b')[B"

cd "$(dirname "$0")"
for shell in bash zsh
do
  pwd
  read -r -t0 && ignore_other_sdtin=$(cat)
  eval "$(cat tests)"
done
