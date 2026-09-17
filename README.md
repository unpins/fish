# fish

[fish](https://fishshell.com/) — the friendly interactive shell, with autosuggestions, syntax highlighting and tab completions that work out of the box. A single self-contained binary, built natively for Linux and macOS.

[![CI](https://github.com/unpins/fish/actions/workflows/fish.yml/badge.svg)](https://github.com/unpins/fish/actions)
![Linux](https://img.shields.io/badge/Linux-✓-success?logo=linux&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-✓-success?logo=apple&logoColor=white)

Part of the [unpins](https://unpins.org) catalog; install it with [`unpin`](https://github.com/unpins/unpin): `unpin install fish`.

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

`unpin install fish` creates the `fish`, `fish_indent` and `fish_key_reader`
commands.

| command           | what it does                                    |
| ----------------- | ----------------------------------------------- |
| `fish`            | the shell                                       |
| `fish_indent`     | reformat fish scripts (`fish_indent -w file.fish`) |
| `fish_key_reader` | show the sequence your terminal sends for a key |

## Man pages

fish's manual is embedded in the binary. Read it with `unpin man fish`, or a
command's page with `unpin man fish string` — likewise `fish-tutorial`,
`fish-language`, `fish-interactive`, `fish-completions`, and a page for every
builtin and function. Inside fish, `string --help` or `man string` shows the
same page.

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

- **Built like upstream's own static release.** fish carries its functions,
  completions, themes and manual inside the binary; system-wide settings are
  read from `/etc/fish` as usual. Upstream publishes Linux binaries for x86_64
  and aarch64 only; this adds i686, armv7l, ppc64le, riscv64 and macOS.
- **`fish_indent` and `fish_key_reader` are the same binary** under another
  name, as upstream ships them.
- **`fish_config browse`** needs Python, as upstream.
- **No Windows build:** fish has no Windows port (it relies on `fork`, terminal
  control and Unix signals).
