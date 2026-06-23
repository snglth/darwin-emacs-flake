{
  description = "Patched emacs-git for aarch64-darwin (NSColor pixel cache), prebuilt in CI";

  # Revisions are pinned to match the ws-flake build this was extracted from, so
  # `nix build .#emacs` reproduces the exact store path already validated there.
  # To move to a newer Emacs: bump these revs (or switch to branch refs + a
  # flake.lock and `nix flake update`), push, and let CI rebuild + repopulate the
  # cache.
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/0590cd39f728e129122770c029970378a79d076a";
    emacs-overlay = {
      url = "github:nix-community/emacs-overlay/e6a5046f8912da3298289fd4a5c6b7a1746e721d";
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
      # The three emacs-plus patches are vendored from
      # d12frosted/homebrew-emacs-plus (patches/emacs-31, symlinked from emacs-32).
      emacs = pkgs.emacs-git.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          ./patches/fix-ns-x-colors.patch
          ./patches/system-appearance.patch
          ./patches/round-undecorated-frame.patch
          ./patches/ns_color_cache_0001.patch
        ];
      });
    in
    {
      packages.${system} = {
        inherit emacs;
        default = emacs;
      };
    };
}
