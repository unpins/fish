# fish

[fish](https://fishshell.com/) — the friendly interactive shell: smart and user-friendly, with autosuggestions, syntax highlighting, and tab completions that work out of the box, no configuration required. A single self-contained binary, built natively for Linux and macOS.

[![CI](https://github.com/unpins/fish/actions/workflows/fish.yml/badge.svg)](https://github.com/unpins/fish/actions)
![Linux](https://img.shields.io/badge/Linux-✓-success?logo=linux&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-✓-success?logo=apple&logoColor=white)

Part of the [unpins](https://unpins.org) catalog; install it with [`unpin`](https://github.com/unpins/unpin): `unpin install fish`.

## What this adds

fish's own 4.x release is already a self-contained binary — the Rust rewrite
compiles the entire `share/fish` tree (every function, completion, prompt and
theme) straight into the executable, so there is nothing to mount or unpack.
What this catalog entry adds is the **alternate builds upstream doesn't
publish**: static-musl binaries for every Linux architecture
(x86_64, i686, aarch64, armv7l, ppc64le, riscv64) and a `libSystem`-only macOS
build, each in the unpins shape with the man pages embedded.

## Usage

Run `fish` with [unpin](https://github.com/unpins/unpin):

```bash
unpin fish                        # start an interactive shell
unpin fish script.fish            # run a script
unpin fish -c 'string upper hi'
```

To install it onto your PATH:

```bash
unpin install fish
```

This also materializes the `fish_indent` and `fish_key_reader` companion
commands as symlinks, for editors and external tools:

```bash
fish_indent < messy.fish          # reformat a script
fish_key_reader                   # identify terminal key sequences
```

(They share one physical binary with `fish`, which dispatches on `argv[0]` — the
same native multicall upstream ships.)

## Man pages

The fish manual pages are embedded, so `unpin man fish` works offline.

## Build locally

```bash
nix build github:unpins/fish
./result/bin/fish -c 'echo hello from fish'
```

Or run directly:

```bash
nix run github:unpins/fish -- -c 'echo hello from fish'
```

The first invocation will offer to add the [unpins.cachix.org](https://unpins.cachix.org) substituter so most pulls come pre-built.

## Manual download

The [Releases](https://github.com/unpins/fish/releases) page has standalone binaries for manual download.

## Build notes

- **No VFS needed — fish embeds its own data tree.** fish 4.x compiles every
  `.fish` script under `share/fish` into the binary as embedded assets, reached
  through the `status get-file` builtin / `embedded:` scheme. So unlike zsh
  (whose function tree the catalog mounts through a `--wrap` VFS), fish runs with
  no `share/fish` on disk at all — `strace` shows zero `/nix/store` reads at
  runtime, and prompts/completions resolve from `embedded:functions/...`.

- **Native `argv[0]` multicall.** fish installs three byte-identical binaries
  (`fish`, `fish_indent`, `fish_key_reader`); the 4.x binary dispatches on its
  invocation name. We keep one physical `fish` and re-expose the other two as
  install-time alias symlinks. `fish_indent` is also an internal builtin, so
  in-shell reformatting works even without the sibling on disk.

- **No Windows.** fish is Rust and deeply Unix (fork, termios, PTY, Unix
  signals) with no upstream Windows port, and Cosmopolitan's `cosmocc` is a C
  toolchain that doesn't apply to a Rust binary — so there is no Windows target.

- **Static linking, every Linux arch.** Linux is static-musl across all six
  architectures; the macOS build links only `libSystem` (`otool -L` confirms).
  The man pages are grafted in (the Sphinx doc build is skipped because its
  build-host helper cross-links against the target's pcre2), giving identical
  manuals on every target.

- **Portability over NixOS purity.** nixpkgs bakes absolute `/nix/store` tool
  paths into fish's embedded completion scripts (e.g. `awk` →
  `${gawk}/bin/awk`) and declares coreutils/grep/sed/man-db as closure
  dependencies — both correct for NixOS, wrong for a relocatable binary. The
  build strips those store-path prefixes back to bare command names (resolved
  from the user's PATH) and drops the propagated runtime closure (which also
  unblocks the ppc64le/riscv64 cross builds, whose `man-db` static cross is
  broken).
