# okk-tmpl 

A template system derived from and old code found on EmacsWiki, modified to be lean and quick.

## Install
You simply add these lines in your *emacs.el* or preferred init file:

```
(defvar okk-tmpl-dir <template-directory>)
(autoload 'okk-tmpl-insert "okk-tmpl" nil t)

```


obviously *<template-directory>* must be valid path, maybe a subdirectory of yours *emacs.d* directory.


Nothing more, you could issue *okk-tmpl-insert* as a command and it will open the directory and permit to choose a template file. (there are not predefined extensions for them).

In the file you have inserted proper tags to indicate the substitutions, see in *okk-tmpl.el*

Feel free to ask using Issues, and remeber to make a donation if you find it useful.


Regards

Carlo D.

