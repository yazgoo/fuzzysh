cat <<'EOT' > README.md

Minimalist selector in shell, à la [fzf](https://github.com/junegunn/fzf)

[![test](https://github.com/yazgoo/fuzzysh/actions/workflows/test.yml/badge.svg)](https://github.com/yazgoo/fuzzysh/actions/workflows/test.yml)

## what's it for ?

You need to:

- select between several choices ?
- in a shell script ?
- with minimal dependencies ?

**Just copy the [fsh](fsh) function in your script.**

[![screenshot](doc/animation.gif)](doc/animation.gif)

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

EOT

(
cat <<EOT

## variables reference

<details>
<summary>You can customize the behavior of fsh by setting the following variables:</summary>

 | Variable | Description | Default value |
 | -------- | ----------- | ------------- |
EOT

grep -Eo 'FSH_[A-Z_]*:=[^}]*' ./fsh | while read input_variable
do
  variable_name=$(echo "$input_variable" | cut -d':' -f1)
  default_value=$(echo "$input_variable" | cut -d'=' -f2)
  description=$(grep -B1 "$input_variable" ./fsh | head -n1 | sed 's/ *# *//')

  echo " | $variable_name | $description | $default_value |"

done
echo
echo "</details>"
) >> README.md
