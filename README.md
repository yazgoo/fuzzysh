minimalist selector in shell, inspired by fzf

[![screenshot](doc/animation_small.gif)](doc/animation.gif)

## what's it for ?

You need to select between several choices in a shell script with minimal dependencies ?

Just copy / paste the fsh function in your script.

## limitations

- for now, it is not POSIX shell, it's only tested in zsh and bash.
- no fuzzy finding, uses regular expression pattern matching instead (might change in the future).
- to keep this as lightweight as possible, I don't plan on adding new features, except optional support for vim mode 

## usage

Example:

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
