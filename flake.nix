{
  description = "Patched emacs-git and Aporetic Nerd Font for aarch64-darwin, prebuilt in CI";

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
        # Avoid Savannah outages; keep the overlay's revision and content hash.
        src = old.src.overrideAttrs {
          url = "https://github.com/emacs-mirror/emacs.git";
        };
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

      # Consume helper arguments so Emacs 32 batch startup cannot reopen them as files.
      consumeArgs =
        path:
        let
          source = builtins.readFile path;
          pattern = "(pcase command-line-args-left";
        in
        assert pkgs.lib.hasInfix pattern source;
        pkgs.writeText (builtins.baseNameOf path) (
          builtins.replaceStrings
            [ pattern ]
            [ "(pcase (prog1 command-line-args-left (setq command-line-args-left nil))" ]
            source
        );

      emacsPackages = (pkgs.emacsPackagesFor emacs).overrideScope (
        _final: prev: {
          melpaBuild =
            args:
            (prev.melpaBuild args).overrideAttrs (old: {
              melpa2nix = consumeArgs old.melpa2nix;
              elpa2nix = consumeArgs old.elpa2nix;
            });
          elpaBuild =
            args:
            (prev.elpaBuild args).overrideAttrs (old: {
              elpa2nix = consumeArgs old.elpa2nix;
            });

          # Pin the release with its Zig dependency hash; the overlay updates weekly.
          ghostel = prev.ghostel.overrideAttrs (
            attrs: _old: {
              version = "0.67.0";
              src = pkgs.fetchFromGitHub {
                owner = "dakra";
                repo = "ghostel";
                rev = "b0330a90b46fde82c47122add00d4440cef35711";
                hash = "sha256-GjS6SYoCwmRrP2P7SOFTtStHDPtuy6Uq52Sug8eYfYE=";
              };
              zig = pkgs.zig_0_17;
              zigDeps = attrs.zig.fetchDeps {
                inherit (attrs) src pname version;
                fetchAll = true;
                hash = "sha256-3pDE8/KCzHR08VqAHJR6rdMOGARCyH0tc5UTOeCvs14=";
              };
              files = ''
                ("lisp/*.el" "etc" "ghostel-module${pkgs.stdenv.hostPlatform.extensions.sharedLibrary}" "ghostel-module.version")
              '';
            }
          );
        }
      );

      aporetic-serif-mono-nerd-font = pkgs.stdenvNoCC.mkDerivation {
        pname = "aporetic-serif-mono-nerd-font";
        inherit (pkgs.aporetic) version;
        nativeBuildInputs = [ pkgs.nerd-font-patcher ];
        src = pkgs.aporetic;
        buildPhase = ''
          find $src/share/fonts/truetype -name 'aporetic-serif-mono-*.ttf' | while read ttf; do
            nerd-font-patcher --complete --no-progressbars "$ttf" -out ./patched
          done
        '';
        installPhase = ''
          fontdir="$out/share/fonts/truetype"
          install -d "$fontdir"
          install ./patched/*.ttf "$fontdir"
        '';
      };

    in
    {
      legacyPackages.${system} = emacsPackages;
      packages.${system} = {
        inherit (emacsPackages)
          auctex
          evil-collection
          ghostel
          magit
          agent-shell
          flycheck
          pdf-tools
          ;
        inherit emacs aporetic-serif-mono-nerd-font;
        default = emacs;
      };
    };
}
