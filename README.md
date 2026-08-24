# darwin-emacs-flake

A flake that gives a patched emacs package for **aarch64-darwin**, with this set
of NS patches:

| Patch | Source | Effect |
|-------|--------|--------|
| `fix-ns-x-colors.patch` | emacs-plus | Makes the NS `x-colors` list correct (`lisp/term/ns-win.el`) |
| `system-appearance.patch` | emacs-plus | Adds `ns-system-appearance` and a hook. Emacs then changes with the macOS light mode and dark mode |
| `round-undecorated-frame.patch` | emacs-plus | Gives a corner radius to frames that have the `undecorated` parameter |
| `ns_color_cache_0001.patch` | emacs-devel | Keeps `NSColor` objects in a cache, with the packed pixel value as the key. Emacs then does not make a new object and does not do a colorspace conversion for each glyph |
| `frame-transparency.patch` | emacs-plus (community) | Adds the `ns-background-blur`, `ns-alpha-elements` and `ns-transparent-titlebar` frame parameters through the CGS APIs |
| `ns-glass-effect.patch` | emacs-liquid-glass | Gives a Ghostty-like macOS glass frame (`NSGlassEffectView`) through the `ns-glass-*` frame parameters |

The first three emacs-plus patches come from
[`d12frosted/homebrew-emacs-plus`](https://github.com/d12frosted/homebrew-emacs-plus/tree/master/patches/emacs-31)
(the `emacs-32` directory is a symlink to `emacs-31`). The flake applies them in
the sequence of the table. Some of them change `nsterm.m` and `frame.h`, thus
the sequence must not change.

`ns_color_cache_0001.patch` comes from the emacs-devel post of Przemysław
Alexander Kamiński, ["[PATCH] [macOS] Add NSColor
cache"](https://lists.gnu.org/archive/html/emacs-devel/2026-06/msg00515.html).

`frame-transparency.patch` is the community patch of
[aaratha](https://github.com/aaratha). It comes from
[`d12frosted/homebrew-emacs-plus`](https://github.com/d12frosted/homebrew-emacs-plus/blob/master/community/patches/frame-transparency/emacs-31.patch).
`ns-glass-effect.patch` comes from
[`larrasket/emacs-liquid-glass`](https://github.com/larrasket/emacs-liquid-glass/blob/master/patches/ns-glass-effect.patch).
It must come after `frame-transparency.patch`, because it uses the
`ns-background-blur` and `ns-alpha-elements` parameters of that patch.

The macOS 26 SDK **and** a macOS 26 deployment target are necessary for the
glass effect. The patch uses the condition
`MAC_OS_X_VERSION_MAX_ALLOWED >= 260000` for each glass path.
`AvailabilityMacros.h` calculates that value from the deployment target, not
from the SDK.

If you increase only the SDK version, the preprocessor removes each glass path.
The build then uses `NSVisualEffectView`, and there is no glass. Thus the flake
sets the two values `apple-sdk_26` and `darwinMinVersionHook "26.0"`. As a
result, **the build operates only on macOS 26 or a subsequent version**.

```
packages.aarch64-darwin.emacs       # the patched emacs-git (also `.default`)
packages.aarch64-darwin.emacs-gpu   # Metal GPU backend, a test package
```

## Glass frame configuration

The `frame-transparency` and `ns-glass-effect` patches add only the frame
*parameters*. You must set the parameters.
[`lisp/macos-glass.el`](lisp/macos-glass.el) sets them for you. Load this file
from your init file:

```elisp
(add-to-list 'load-path "/path/to/darwin-emacs-flake/lisp")
(require 'macos-glass)            ; auto-enables on macOS
(macos-glass-set-style 'regular)  ; or 'clear
```

The file sets the glass parameters on `default-frame-alist`. Then it sets them
again on each new frame, and on each `emacsclient` frame and daemon frame. On an
Emacs that does not have the glass patch, the file uses transparency and
background blur. Only `frame-transparency` is necessary for these two effects.

The file finds this condition with a probe. It sets an incorrect
`ns-glass-material` value on a graphic frame. The patched C handler gives an
error, but an Emacs without the patch stores the value and gives no error. The
probe cannot show the difference between glass and blur. The patch always
adds `ns-glass-material`, and it always makes sure that the value is correct.
Thus a patched build with the incorrect deployment target gives no error in the
probe, but it shows `NSVisualEffectView`.

You can also write the parameters in your init file. These are the frame
parameters of the two presets:

```elisp
;; 'regular preset
(dolist (p '((ns-transparent-titlebar  . t)
             (alpha-background         . 0.01)
             (ns-background-blur       . 0)
             (ns-alpha-elements        . (ns-alpha-all))
             (ns-glass-material        . regular)   ; or 'clear
             (ns-glass-tint-opacity    . 0.05)
             (ns-glass-saturation      . 1.4)
             (ns-glass-inactive-opacity . 0.05)
             (ns-glass-corner-radius   . 2)))
  (add-to-list 'default-frame-alist p)
  (set-frame-parameter nil (car p) (cdr p)))
```

The macOS 26 SDK *and* a macOS 26 deployment target at build time are necessary
for the `NSGlassEffectView` material. If one of the two is missing, the patch
compiles to `NSVisualEffectView`, which gives blur, not glass.

## Cache

> **macOS 26 or a subsequent version is necessary.** The flake builds `emacs` at
> deployment target 26.0 to get the glass effect. Thus the binary in the cache
> does not start on a macOS version before 26. This does not apply to
> `emacs-gpu`, which keeps the nixpkgs default.

The binary cache is on cachix:

```nix
nix.settings.substituters = [ "https://snglth.cachix.org" ];
nix.settings.trusted-public-keys = [
  "snglth.cachix.org-1:XDPcXVEs97RJQ1SVmjf7cnZHcrE9pH7tE1TYJhKKJ1U="
];
```

## Metal GPU backend (a test package)

`packages.aarch64-darwin.emacs-gpu` builds
[`tanrax/emacs-gpu`](https://github.com/tanrax/emacs-gpu). This is a full Emacs
31.0.90 fork of Andros Fenollosa that adds a Metal GPU display backend
([RFC, emacs-devel 2026-06](https://lists.gnu.org/archive/html/emacs-devel/2026-06/msg00177.html)).
It is a full fork, not a patch on master. Thus the flake builds it from the
source of the fork, with `--with-mtl` added to the `emacs-git` recipe of the
overlay. The flake does not apply it to the patched `emacs`.

The source includes the shaders, and Emacs compiles them when it operates
(`newLibraryWithSource:`). Thus a Metal toolchain before the build is not
necessary. Only the macOS SDK frameworks that `--with-mtl` uses are necessary.
This package operates independently of `emacs` and `.default`. Build it with
this command:

```sh
nix build .#emacs-gpu -L
```
