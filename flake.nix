{
  description = "Patched emacs-git for aarch64-darwin (NSColor pixel cache), prebuilt in CI";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    emacs-overlay = {
      url = "github:nix-community/emacs-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      emacs-overlay,
    }:
    let
      system = "aarch64-darwin";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ emacs-overlay.overlays.default ];
      };

      # emacs-git (32.0.50, master) built from source with a stack of NS patches.
      #
      # Patch order matters — fix-ns-x-colors is lisp-only; system-appearance and
      # round-undecorated-frame both touch nsterm.m/frame.h and are applied in the
      # same order emacs-plus uses; ns_color_cache is the local color cache.
      # The emacs-plus patches are vendored from d12frosted/homebrew-emacs-plus
      # (patches/emacs-31, symlinked from emacs-32).
      #
      # frame-transparency + ns-glass-effect add the Ghostty-like macOS glass
      # frame (NSGlassEffectView) from github:larrasket/emacs-liquid-glass.
      # frame-transparency (emacs-plus community patch) is the prerequisite: it
      # introduces ns-background-blur / ns-alpha-elements / ns-transparent-titlebar,
      # which ns-glass-effect builds on, so it MUST precede ns-glass-effect.
      # NSGlassEffectView needs the macOS 26 SDK; on older SDKs the patch falls
      # back to NSVisualEffectView (no true glass).
      emacs = pkgs.emacs-git.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          ./patches/fix-ns-x-colors.patch
          ./patches/system-appearance.patch
          ./patches/round-undecorated-frame.patch
          ./patches/ns_color_cache_0001.patch
          ./patches/frame-transparency.patch
          ./patches/ns-glass-effect.patch
        ];
      });

      # Experimental: Emacs with the Metal GPU display backend from
      # github:tanrax/emacs-gpu (RFC, emacs-devel 2026-06 msg00177, Andros
      # Fenollosa). It's a full Emacs 31.0.90 fork, so we build its tree directly
      # rather than apply a 7400-line diff against emacs-git (32.0.50). Shaders
      # are embedded and compiled at runtime via newLibraryWithSource:, so no
      # offline Metal toolchain (Xcode) is required — only the SDK frameworks,
      # which configure links via MTL_LIBS when given `--with-mtl`. We keep the
      # overlay's native-comp patch + configureFlags and just add the flag.
      emacs-gpu = pkgs.emacs-git.overrideAttrs (old: {
        pname = "emacs-gpu";
        version = "31.0.90-gpu-unstable-2026-06-18";
        src = pkgs.fetchFromGitHub {
          owner = "tanrax";
          repo = "emacs-gpu";
          rev = "db296675d856f924c80671428565ed377314caea";
          hash = "sha256-+mFtRJvvIQPjac2U6hkxx+2vXtEKg58PQyhwKiubB0Y=";
        };
        # OBJC=clang: the --with-mtl check does AC_LANG_PUSH([Objective C]),
        # which makes autoconf pick `gcc` for Objective-C — and that compiler
        # lacks the Apple framework search path, so `Metal/Metal.h` isn't found
        # even though clang finds it. Pin OBJC to the same wrapped clang as CC.
        configureFlags = (old.configureFlags or [ ]) ++ [
          "--with-mtl"
          "OBJC=clang"
        ];
      });
    in
    {
      packages.${system} = {
        inherit emacs emacs-gpu;
        default = emacs;
      };
    };
}
