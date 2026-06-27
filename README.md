# darwin-emacs-flake

A flake that provides patched emacs package for **aarch64-darwin** with a stack of NS patches:

| Patch | Origin | Effect |
|-------|--------|--------|
| `fix-ns-x-colors.patch` | emacs-plus | Fixes the NS `x-colors` list (`lisp/term/ns-win.el`) |
| `system-appearance.patch` | emacs-plus | Adds `ns-system-appearance` + hook so Emacs follows macOS light/dark mode |
| `round-undecorated-frame.patch` | emacs-plus | Rounded corners on undecorated frames |
| `ns_color_cache_0001.patch` | emacs-devel | Caches `NSColor` by packed pixel value - avoids a per-glyph allocation + colorspace conversion |
| `frame-transparency.patch` | emacs-plus (community) | Adds `ns-background-blur` / `ns-alpha-elements` / `ns-transparent-titlebar` frame params via CGS APIs - prerequisite for the glass patch |
| `ns-glass-effect.patch` | emacs-liquid-glass | Ghostty-like macOS glass frame (`NSGlassEffectView`) via `ns-glass-*` frame params |

The three core emacs-plus patches are vendored from
[`d12frosted/homebrew-emacs-plus`](https://github.com/d12frosted/homebrew-emacs-plus/tree/master/patches/emacs-31)
(the `emacs-32` dir symlinks to `emacs-31`). They apply in the order listed
above; `nsterm.m` / `frame.h` are touched by several, so order is preserved.

`ns_color_cache_0001.patch` is from Przemysław Alexander Kamiński's emacs-devel
post ["[PATCH] [macOS] Add NSColor
cache"](https://lists.gnu.org/archive/html/emacs-devel/2026-06/msg00515.html).

`frame-transparency.patch` is the community patch by
[aaratha](https://github.com/aaratha), vendored from
[`d12frosted/homebrew-emacs-plus`](https://github.com/d12frosted/homebrew-emacs-plus/blob/master/community/patches/frame-transparency/emacs-31.patch).
`ns-glass-effect.patch` is from
[`larrasket/emacs-liquid-glass`](https://github.com/larrasket/emacs-liquid-glass/blob/master/patches/ns-glass-effect.patch)
and **must** be applied after `frame-transparency.patch`, whose
`ns-background-blur` / `ns-alpha-elements` symbols it builds on. The glass
effect needs the macOS 26 SDK; on older SDKs the patch falls back to
`NSVisualEffectView` (no true glass).


```
packages.aarch64-darwin.emacs       # the patched emacs-git (also `.default`)
packages.aarch64-darwin.emacs-gpu   # experimental Metal GPU backend (see below)
```

## Cache

Binary cache lives on cachix:

```nix
nix.settings.substituters = [ "https://snglth.cachix.org" ];
nix.settings.trusted-public-keys = [
  "snglth.cachix.org-1:XDPcXVEs97RJQ1SVmjf7cnZHcrE9pH7tE1TYJhKKJ1U="
];
```

## Experimental: Metal GPU backend

`packages.aarch64-darwin.emacs-gpu` builds [`tanrax/emacs-gpu`](https://github.com/tanrax/emacs-gpu)
— a full Emacs 31.0.90 fork by Andros Fenollosa adding a Metal GPU display
backend ([RFC, emacs-devel 2026-06](https://lists.gnu.org/archive/html/emacs-devel/2026-06/msg00177.html)).
Because it's a whole fork (not a patch on master), it's built from the fork's
own source with `--with-mtl` added to the overlay's `emacs-git` recipe, rather
than stacked onto the patched `emacs` above.

Shaders are embedded and compiled at runtime (`newLibraryWithSource:`), so no
offline Metal toolchain is needed — only the macOS SDK frameworks that
`--with-mtl` links. It's independent of `emacs`/`.default`; build it explicitly:

```sh
nix build .#emacs-gpu -L
```
