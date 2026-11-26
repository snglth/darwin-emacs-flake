# darwin-emacs-flake

Patched Emacs with glass frames for Apple Silicon Macs running macOS 26 or later.

## Build

From a checkout, build and run Emacs:

```sh
nix build .#emacs
./result/bin/emacs
```

For the optional `AporeticSerifMono Nerd Font`, run `nix build .#aporetic-serif-mono-nerd-font`.

## Binary cache

To use prebuilt packages, add these lines to `nix.conf`:

```ini
extra-substituters = https://snglth.cachix.org
extra-trusted-public-keys = snglth.cachix.org-1:XDPcXVEs97RJQ1SVmjf7cnZHcrE9pH7tE1TYJhKKJ1U=
```

To use the cached Emacs packages from another flake, add this input:

```nix
inputs.darwin-emacs.url = "github:snglth/darwin-emacs-flake";
```

Select packages from its `aarch64-darwin` package set:

```nix
inputs.darwin-emacs.legacyPackages.aarch64-darwin.emacsWithPackages (epkgs: [ epkgs.ghostel ])
```

## Glass frames

Load [macos-glass.el](lisp/macos-glass.el) from your Emacs init file:

```elisp
(add-to-list 'load-path "/path/to/darwin-emacs-flake/lisp")
(require 'macos-glass)
```

The default style is `regular`. Use `(macos-glass-set-style 'clear)` for clear glass.

## License

Copyright (C) 2026 Illia Shestakov. Original code and documentation: [GPL-3.0-or-later](LICENSE).
Imported patches retain their upstream copyrights and licenses.

Aporetic Serif Mono uses the [SIL Open Font License 1.1](https://github.com/protesilaos/aporetic/blob/1.2.0/LICENSE.md).
The added glyphs retain their [Nerd Fonts upstream licenses](https://github.com/ryanoasis/nerd-fonts/blob/master/license-audit.md).
