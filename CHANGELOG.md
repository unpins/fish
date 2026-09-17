# Changelog

## [Unreleased]

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
