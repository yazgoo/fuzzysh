# fuzzysh

mininmalist fuzzy finder in shell

![screenshot](doc/screenshot.png)

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
