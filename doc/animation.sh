#!/bin/zsh
set -e
ANIMATION_WIDTH=40
ANIMATION_HEIGHT=12
up="$(echo '\x1b')[A"
down="$(echo '\x1b')[B"
/bin/rm -f _screenshot/*
FSH_COLUMNS=${ANIMATION_WIDTH} \
  FSH_LINES=${ANIMATION_HEIGHT} \
  FSH_TEST_INPUT="tes$up$up$up" \
  FSH_SCREENSHOT=1 \
  ./fsh 2>&1 | \
  ./test/terminal_emulator_render.rb -r ${ANIMATION_HEIGHT} -c ${ANIMATION_WIDTH} -P 4242 -p
