# Move It
This Emacs package provides functionality for conveniently moving around text,
akin to the [move-text](https://github.com/emacsfodder/move-text) and
[drag-stuff](https://github.com/rejeep/drag-stuff.el) packages.[^1] Mostly
implemented just for fun, and does not necessarily provide much novelty compared
to the above-mentioned packages (besides perhaps some customization concerning
the default behavior).

[^1]: Obviously, this package is heavily inspired by `move-text` and `drag-stuff`
as well.

## Installation and Configuration
Placing the following snippet in your initialization file will
install and configure this package, binding the main left, down, up, and right
movement commands to the corresponding arrow keys (modified with Meta).
Evidently, using this particular snippet requires `use-package` with the `:vc` keyword;
however, this is just an example, and there are many ways to achieve the same result
(without these dependencies).
```
(use-package move-it
  :ensure t
  :vc (:url "https://github.com/mmctl/move-it"
            :branch "main"
            :rev :newest)

  :bind
  ("M-<left>" . move-it-left)
  ("M-<down>" . move-it-down)
  ("M-<up>" . move-it-up)
  ("M-<right>" . move-it-right))
```
