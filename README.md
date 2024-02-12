minimalist selector in shell, inspired by fzf

[![screenshot](doc/animation_small.gif)](doc/animation.gif)

## what's it for ?

You need to select between several choices in a shell script with minimal dependencies ?

Just copy / paste the fsh function in your script.

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

## limitations

- for now, it is not POSIX shell, it's only tested in zsh and bash.
- no fuzzy finding, use grep pattern instead by design.
  You can use `.*` in your query if you want to do something like fuzzy finding.
