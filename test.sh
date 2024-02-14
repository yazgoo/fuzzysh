#!/bin/bash
set -ex

for shell in bash zsh
do
  result="$(echo hello | FSH_TEST_INPUT=h "$shell" ./fsh)"
  echo "$shell"
  [[ "$result" = hello ]]
done
