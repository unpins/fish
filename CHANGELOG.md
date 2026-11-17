# Changelog

## [Unreleased]

### Changed

- The Linux binaries now use the same PCRE2 as macOS (nixpkgs' 10.48, was the
  10.43 bundled with fish), so `string match -r` and `string replace -r`
  accept the newer regex syntax, such as `(*scan_substring:`.

## [4.7.1-1] - 2026-09-26

### Fixed

- fish ignored the system-wide configuration in `/etc/fish` (`config.fish`,
  `conf.d`, `functions`, `completions`). It now reads it, like upstream fish.
- `string --help`, `abbr --help` and the other builtins' `--help`, as well as
  `man string` inside fish, printed "missing man page". The manual is now
  embedded and shown offline.
- `unpin man fish` had only the fish overview pages; it now has a page for
  every builtin and function too (`unpin man fish string`).
- `fish_config browse` failed with "fish could not be executed at path …".
- Completing a command after `sudo` or `doas` did not offer programs from
  `/sbin`, `/usr/sbin` and `/usr/local/sbin`.
