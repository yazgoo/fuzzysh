SRC=fsh
lint:
	shellcheck -s bash $(SRC)
tst:
	test/test.sh
doc: fsh doc/generate_readme.sh
	doc/generate_readme.sh
check_doc_up_to_date: doc
	git diff --exit-code
checks: lint check_doc_up_to_date tst
	echo "All checks passed 🎉"
install_hooks:
	git config core.hooksPath .git/hooks
add_hooks:
	echo QUIET=true make checks > .git/hooks/pre-push
	chmod +x .git/hooks/pre-push
format:
	shfmt -w -i 2 $(SRC)
animation:
	rm -f _screenshot/*; FSH_SCREENSHOT=1 ./fsh 2>&1 |test/terminal_emulator_render.rb -r $$LINES -c $$COLUMNS -P 4242 -p
