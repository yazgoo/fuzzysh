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
    result="$(FSH_NO_FUZZY="$no_fuzzy" FSH_TEST_INPUT="$user_input" "$shell" ./fsh)"
  else
    result="$(echo -e "$choices"| FSH_NO_FUZZY="$no_fuzzy" FSH_TEST_INPUT="$user_input" "$shell" ./fsh)"
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

cd "$(dirname "$0")"
for shell in bash zsh
do
  pwd
  read -r -t0 && ignore_other_sdtin=$(cat)
  #  In: choices       In: user_input  In: fuzzy      Out: fails     Out: expected result
  🧪 "hello"           h               ✅             🔳             hello
  🧪 "hello\nbonjour"  b               ✅             🔳             bonjour
  🧪 "hello\nBonjour"  b               ✅             🔳             Bonjour
  🧪 "hello\nBonjour"  Bn              ✅             🔳             Bonjour
  🧪 "hello\nBonjour"  Bn              🔳             ✅             ""
  🧪 ""                test            ✅             🔳             test.sh
  🧪 ""                fs              ✅             🔳             fsh
done
