#!/bin/bash
set -ex

run_test() {
  if [ -z "$choices" ]
  then
    result="$(FSH_TEST_INPUT="$user_input" "$shell" ./fsh)"
  else
    result="$(echo -e "$choices"| FSH_TEST_INPUT="$user_input" "$shell" ./fsh)"
  fi
  echo "with shell=$shell choices=$choices user_input=$user_input expected_result=$expected_result result=$result"
  [[ "$result" = "$expected_result" ]]
}

cd "$(dirname "$0")"
for shell in bash zsh
do
  choices="hello"          user_input=h    expected_result=hello              run_test
  choices="hello\nbonjour" user_input=b    expected_result=bonjour            run_test
  choices="hello\nBonjour" user_input=b    expected_result=Bonjour            run_test
  choices="hello\nBonjour" user_input=B    expected_result=Bonjour            run_test
  choices=""               user_input=test expected_result=test.sh            run_test
  choices=""               user_input=fs   expected_result=fsh                run_test
done
