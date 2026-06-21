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
nix run .#i7-build -- story.ni        # build story.z8
nix run .#i7-play -- story.z8         # play it in the terminal with Frotz
```

Or enter the shell and run them directly:

```bash
nix develop
i7-check story.ni
i7-build story.ni
i7-play story.z8
```

`inform7` itself is also wrapped to work from the command line. It copies
Inform's `Internal` resources into a writable cache before compiling, because
Inform wants to refresh built kit files while translating a story and the Nix
store is read-only.
