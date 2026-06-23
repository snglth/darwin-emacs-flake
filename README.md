# darwin-emacs-flake

A single-output flake that provides `emacs-git` for **aarch64-darwin** with a stack of NS patches:

| Patch | Origin | Effect |
|-------|--------|--------|
| `fix-ns-x-colors.patch` | emacs-plus | Fixes the NS `x-colors` list (`lisp/term/ns-win.el`) |
| `system-appearance.patch` | emacs-plus | Adds `ns-system-appearance` + hook so Emacs follows macOS light/dark mode |
| `round-undecorated-frame.patch` | emacs-plus | Rounded corners on undecorated frames |
| `ns_color_cache_0001.patch` | emacs-devel | Caches `NSColor` by packed pixel value - avoids a per-glyph allocation + colorspace conversion |

The three emacs-plus patches are vendored from
[`d12frosted/homebrew-emacs-plus`](https://github.com/d12frosted/homebrew-emacs-plus/tree/master/patches/emacs-31)
(the `emacs-32` dir symlinks to `emacs-31`). They apply in the order listed
above; `nsterm.m` / `frame.h` are touched by several, so order is preserved.

`ns_color_cache_0001.patch` is from Przemysław Alexander Kamiński's emacs-devel
post ["[PATCH] [macOS] Add NSColor
cache"](https://lists.gnu.org/archive/html/emacs-devel/2026-06/msg00515.html).


```
packages.aarch64-darwin.emacs    # the patched emacs-git (also `.default`)
```

## Cache

Binary cache lives on cachix:

```nix
nix.settings.substituters = [ "https://snglth.cachix.org" ];
nix.settings.trusted-public-keys = [
  "snglth.cachix.org-1:XDPcXVEs97RJQ1SVmjf7cnZHcrE9pH7tE1TYJhKKJ1U="
];
```
