![screenshot](doc/screenshot.png)

mininmalist selector in shell, inspired by fzf

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
