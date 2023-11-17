# arduino-cli-mode

`arduino-cli-mode` is an Emacs minor mode for using the excellent new 
[arduino command line interface](https://github.com/arduino/arduino-cli)
in an Emacs-native fashion. The mode covers the full range of
`arduino-cli` features in an Emacs native fashion. It even 
leverages the infinite power the GNU to provide fussy-finding
of libraries and much improved support for handling multiple boards.
The commands that originally require multiple steps (such as first
searching for a library and then separately installing it) have
been folded into one.

It is an improved version of [arduino-cli-mode][https://github.com/motform/arduino-cli-mode]with some added features:

- it is not a minor mode
- it has the ability to set the `arduino-cli` executable path if emacs is not able to find it.


## Installation

A sample configuration with **use-package** could look like this:

```elisp
(use-package arduino-cli-mode
  :load-path "<Location of arduino-cli-mode>"
  :custom
  (arduino-cli-warnings 'all)
  (arduino-cli-verify t)
  (arduino-cli-default-fqbn "arduino:avr:uno")
  (arduino-cli-defcmd (expand-file-name "< location of arduino-cli executable>"))
  )
  
  (add-to-list 'auto-mode-alist '("\\.ino\\'" . arduino-cli-mode))
```

## Default boards

By default `arduino-cli-mode` uses the `board list` command from
`arduino-cli` to determine which board to target.

This works well most of the time, but sometimes fails due to connectivity issues.
It also requires the target board to be connected, which might not always be
possible.

Another use case is when developing and testing there is only the need to compile the
executable and test if always is ok.

To cover these use cases you are able to set:

- a default board (fqbn) via `arduino-cli-default-fqbn` as in the example above.
- a default port via `arduino-cli-default-port`

Sample configuration presented above is showing the use of `arduino-cli-defcmd`
variable that permit to specify a different executable name (just in case) or most
common to specify the whole path (`expand-file-name` will take care of this) of the
executable in case emacs is complaining about not finding it. Sometimes emacs is started wiht  

These can of course be set global via your `init`, but have found them to be an excellent fit for [dir](https://www.gnu.org/software/emacs/manual/html_node/elisp/Directory-Local-Variables.html) and 
[file local variables](https://www.gnu.org/software/emacs/manual/html_node/elisp/File-Local-Variables.html#File-Local-Variables).
To get the fqbn/port information for a currently connected board, use 
`arduino-cli-board-list`.

Using default board variables should be a bit faster, as it eliminates the need to
shelling out and then parse JSON from `arduino-cli`.


## Customization


You can enable the major flags from `arduino-cli` using similar enumerations. 

| Flag                                 | Values                                       |
| ---                                  | ---                                          |
| `arduino-cli-verify`                 | `nil` (default), `t`                         |
| `arduino-cli-warnings`               | `nil` (default), `'default`, `'more`, `'all` |
| `arduino-cli-verbosity`              | `nil` (default), `'quiet`, `'verbose`        |
| `arduino-cli-compile-only-verbosity` | `nil`, `t` (default)                         |

**Note:** flags other than `t` and `nil` have an *apostrophe* in front of them.

## Keymap

The default keymap prefix is `C-c C-a` and can be customized with `arduino-cli-mode-keymap-prefix`.

The following keybindings are provided out of the box.

| Function                | Keymap      |
| ---                     | ---         |
| Compile                 | `C-c C-a c` |
| Upload                  | `C-c C-a u` |
| Compile and Upload      | `C-c C-a b` |
| List Connected Boards   | `C-c C-a l` |
| Create new sketch       | `C-c C-a n` |
| Install a Library       | `C-c C-a i` |
| Uninstall a Library     | `C-c C-a u` |


## Limitations

* Does not support `board attach` commands
* Only tested on Linux
* Not called `elduino-mode`


## Contribute

This is my first real elisp project.


## Donations


>
> **If you have found useful this code please donate using:**
>
> [Link Paypal.me](https://paypal.me/FCSguidait?locale.x=en_EN)
>
> Donations will be used to maintain it and to create new things.
