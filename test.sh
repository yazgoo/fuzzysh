#!/bin/bash
set -e

result="$(FSH_TEST_INPUT=blah ./fsh)"
 [[ "$result" =~ "test.sh" ]]


result="$(echo hello | FSH_TEST_INPUT=blah ./fsh)"
 [[ "$result" =~ "hello" ]]
