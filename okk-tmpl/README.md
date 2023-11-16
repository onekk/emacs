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

```
 "Lookup table mapping % tags to variable/function.  Return a string
to be inserted into the buffer; non-strings are ignored.  Predefined
tags are:

 %u       user's login name
 %U       user's full name
 %a       user's mail address (from the variable `user-mail-address')
 %f       file name with path
 %b       file name without path
 %n       file name without path and extension
 %N       file name without path and extension, capitalized
 %e       file extension
 %E       file extension capitalized
 %p       file directory
 %j       skip tags until %je is found
 %d       day
 %m       month
 %M       abbreviated month name
 %y       last two digits of year
 %Y       year
 %q       `fill-paragraph'
 %[ %]    prompt user for a string
 %1-%9    refer to the nth strings prompted for with %[ %]
 %( %)    elisp form to be evaluated
 %%       inserts %


Note: %j is deleted but following character are not deleted. While the whole line
containing %je is deleted.
```


Feel free to ask using Issues, and remeber to make a donation if you find it useful.


Regards

Carlo D.

