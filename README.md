

<table>
<tr>

<td>

Minimalist selector in shell, à la [fzf](https://github.com/junegunn/fzf)

[![test](https://github.com/yazgoo/fuzzysh/actions/workflows/test.yml/badge.svg)](https://github.com/yazgoo/fuzzysh/actions/workflows/test.yml)

## what's it for ?

You need to:

- select between several choices ?
- in a shell script ?
- with minimal dependencies ?

**Just copy the [fsh](fsh) function in your script.**

</td>

<td>

[![screenshot](doc/animation_small.gif)](doc/animation.gif)

</td>

</tr>
</table>

## usage example

```bash
$ echo -e 'Hello, world!\n¡Hola, mundo!\nBonjour, le monde !\nHallo, Welt!' | ./fsh
```

<details>
<summary>
...
</summary>


```
Hello, world!
¡Hola, mundo!
Bonjour, le monde !
Hallo, Welt!

> 
```

type your text

```
Hallo, Welt!

> hall
```

Press enter

```
Hallo, Welt!
```

</details>

## limitations

- not POSIX shell: it's only tested in `zsh` and `bash`.
- to keep it lightweight and fast, I (mostly) don't plan on adding new features.


## variables reference

<details>
<summary>You can customize the behavior of fsh by setting the following variables:</summary>

 | Variable | Description | Default value |
 | -------- | ----------- | ------------- |
 | FSH_SELECTOR_COLOR | the color line currently highlighted | 40 |
 | FSH_FRAME_COLOR | the color of the frame | 30 |
 | FSH_PROMPT_COLOR | the color used for the prompt | 34 |
 | FSH_SELECT_COLOR | the color of the sign before the line currently selected | 31 |
 | FSH_TEST_INPUT | the simulated user input given as a string, one character at a time. first character will be ignored. if set the script will not read from stdin | "" |
 | FSH_HEADER | a name to display beofre the prompt to give context on what is expected | "" |
 | FSH_VIM_MODE | (not implemented) set this variable to support vim normal mode | "" |
 | FSH_PERF | if this variable is set, will display the time it took to draw the interface | "" |
 | FSH_NO_FUZZY | if this variable is set, will not use fuzzy search, instead will do a pattern match | "" |
 | FSH_LINES | the height of the terminal (used for testing, otherwise will be set by tput) | $(tput lines 2>/dev/null) |
 | FSH_COLUMNS | the width of the terminal (used for testing, otherwise will be set by tput) | $(tput cols 2>/dev/null) |
 | FSH_SCREENSHOT | if this variable is set, will write a screenshot of the terminal at each iteration and generate an animation at the end | "" |

</details>
