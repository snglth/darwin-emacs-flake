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

      # emacs-git (32.0.50, master), built from source with a set of NS
      # patches. The sequence of the patches is important. fix-ns-x-colors
      # changes only lisp. system-appearance and round-undecorated-frame
      # change nsterm.m and frame.h, thus they keep the sequence that
      # emacs-plus uses. ns_color_cache is the local color cache. The
      # emacs-plus patches come from d12frosted/homebrew-emacs-plus
      # (patches/emacs-31, with a symlink from emacs-32).
      #
      # frame-transparency and ns-glass-effect add the Ghostty-like macOS glass
      # frame (NSGlassEffectView) from github:larrasket/emacs-liquid-glass.
      # frame-transparency (an emacs-plus community patch) is necessary first.
      # It adds ns-background-blur, ns-alpha-elements and
      # ns-transparent-titlebar, and ns-glass-effect uses them. Thus it MUST
      # come before ns-glass-effect.
      #
      # The macOS 26 SDK *and* a 26.0 deployment target are necessary for
      # NSGlassEffectView. This is the problem: the patch uses the condition
      # MAC_OS_X_VERSION_MAX_ALLOWED >= 260000 for each glass path, but
      # AvailabilityMacros.h calculates that value as
      # max(MAC_OS_X_VERSION_MIN_REQUIRED, 140000). That is the *deployment
      # target*, not the SDK. The nixpkgs default darwinMinVersion = "14.0"
      # keeps it at 140000. If you increase only the SDK version, the
      # preprocessor removes the glass paths. The build then uses
      # NSVisualEffectView blur and gives no error. Thus we add
      # darwinMinVersionHook "26.0".
      #
      # The two SDK mechanisms are necessary. The apple-sdk setup hook reads
      # buildInputs to select the compile SDK, and it selects the SDK with the
      # highest version number in buildInputs. The .override gives the SDK to
      # the native-comp-driver-options patch that the overlay makes. If we do
      # not do this, that patch writes an incorrect 14.4 SDK path into the
      # runtime closure.
      # We set apple-sdk_26 in the code and do not calculate it at build
      # time. 260000 is a minimum, and the flake.lock update each week must
      # not change the compile SDK. As a result, the binaries operate only on
      # macOS 26 or a subsequent version.
      emacs = (pkgs.emacs-git.override { apple-sdk = pkgs.apple-sdk_26; }).overrideAttrs (old: {
        buildInputs = (old.buildInputs or [ ]) ++ [
          pkgs.apple-sdk_26
          (pkgs.darwinMinVersionHook "26.0")
        ];
        patches = (old.patches or [ ]) ++ [
          ./patches/fix-ns-x-colors.patch
          ./patches/system-appearance.patch
          ./patches/round-undecorated-frame.patch
          ./patches/ns_color_cache_0001.patch
          ./patches/frame-transparency.patch
          ./patches/ns-glass-effect.patch
        ];
      });

      # A test package: Emacs with the Metal GPU display backend from
      # github:tanrax/emacs-gpu (RFC, emacs-devel 2026-06 msg00177, Andros
      # Fenollosa). It is a full Emacs 31.0.90 fork. Thus we build its tree
      # directly, and do not apply a 7400-line diff to emacs-git (32.0.50).
      # The source includes the shaders, and Emacs compiles them when it
      # operates with newLibraryWithSource:. Thus a Metal toolchain (Xcode)
      # before the build is not necessary. Only the SDK frameworks are
      # necessary, and configure connects them with MTL_LIBS when it gets
      # `--with-mtl`. We keep the native-comp patch and the configureFlags of
      # the overlay, and add only the flag.
      emacs-gpu = pkgs.emacs-git.overrideAttrs (old: {
        pname = "emacs-gpu";
        version = "31.0.90-gpu-unstable-2026-06-18";
        src = pkgs.fetchFromGitHub {
          owner = "tanrax";
          repo = "emacs-gpu";
          rev = "db296675d856f924c80671428565ed377314caea";
          hash = "sha256-+mFtRJvvIQPjac2U6hkxx+2vXtEKg58PQyhwKiubB0Y=";
        };
        # OBJC=clang: the --with-mtl test does AC_LANG_PUSH([Objective C]),
        # which makes autoconf select `gcc` for Objective-C. That compiler does
        # not have the Apple framework search path. Thus it does not find
        # `Metal/Metal.h`, but clang does find it. We set OBJC to the same
        # wrapped clang as CC.
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
