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
  echo "run shell=$shell choices=$choices user_input=$user_input expected_result=$expected_result result=$result"
  if [ -z "$choices" ]
  then
    result="$(FSH_NO_FUZZY="$no_fuzzy" FSH_TEST_INPUT="y$user_input" "$shell" ./fsh)"
  else
    result="$(echo -e "$choices"| FSH_NO_FUZZY="$no_fuzzy" FSH_TEST_INPUT="y$user_input" "$shell" ./fsh)"
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
