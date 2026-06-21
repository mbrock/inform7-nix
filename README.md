# Inform 7 Nix Flake

A Nix flake for building the Inform 7 interactive fiction compiler suite from source.

```bash
nix build .#inweb    # The literate programming tool
nix build .#intest   # The testing framework
nix build .#inform   # The full Inform 7 compiler suite
```

## Authoring loop

The default package includes a few small command-line helpers:

```bash
nix run .#i7-check -- story.ni        # translate/check an Inform 7 source file
nix run .#i7-build -- story.ni        # build story.z8 for the Z-machine
nix run .#i7-build -- --glulx story.ni # build story.ulx for Glulx
nix run .#i7-play -- story.z8         # play Z-code with Frotz
nix run .#i7-play -- story.ulx        # play Glulx with Glulxe/CheapGlk
nix run .#i7-release-web -- story.ni webroot # build a playable static site
```

Or enter the shell and run them directly:

```bash
nix develop
i7-check story.ni
i7-build story.ni
i7-build --glulx story.ni
i7-play story.z8
i7-play story.ulx
i7-release-web story.ni webroot
```

`inform7` itself is also wrapped to work from the command line. It copies
Inform's `Internal` resources into a writable cache before compiling, because
Inform wants to refresh built kit files while translating a story and the Nix
store is read-only.

`i7-release-web` defaults to a Glulx/Quixe website. Use `--zcode` for a
Z-machine/Parchment website, or `--force` to replace a non-empty output
directory:

```bash
i7-release-web --zcode story.ni webroot
i7-release-web --force story.ni webroot
```
