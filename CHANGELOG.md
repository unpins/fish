# Changelog

## [Unreleased]

### Changed

- The Linux binaries now use the same PCRE2 as macOS (nixpkgs' 10.48, was the
  10.43 bundled with fish), so `string match -r` and `string replace -r`
  accept the newer regex syntax, such as `(*scan_substring:`.

## [4.7.1-1] - 2026-09-26

Initial release — `fish` 4.7.1 as a single self-contained binary, built
natively for Linux and macOS.

### Added

- Builds for Linux (x86_64, aarch64, i686, armv7l, ppc64le, riscv64) and macOS
  (x86_64, aarch64).
- The fish manual is embedded in the binary — read it with `unpin man fish`,
  or `unpin man fish <command>` for a builtin or function.
- `unpin install fish` also creates the `fish_indent` and `fish_key_reader`
  commands.
