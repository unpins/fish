{
  description = "fish (the friendly interactive shell) as a single self-contained binary";

  nixConfig = {
    extra-substituters = [ "https://unpins.cachix.org" ];
    extra-trusted-public-keys = [ "unpins.cachix.org-1:DDaShjbZ8VvcqxeTcAU3kV9vxZQBlyb7V/uLBHfTynI=" ];
  };

  inputs.unpins-lib.url = "github:unpins/nix-lib";

  # fish (the friendly interactive shell) as a single self-contained static
  # binary.
  #
  # fish 4.x is Rust and already compiles its whole share/fish tree (functions,
  # completions, themes) and its man pages into the executable. Upstream's own
  # static Linux release is plain `cargo build --release --target
  # <arch>-unknown-linux-musl --bin fish` with Sphinx and gettext on the build
  # host. We build it the same way, for every Linux arch upstream does not
  # publish plus macOS, in the catalog shape.
  #
  # Why cargo and not nixpkgs' fish (CMake): the CMake build bakes its install
  # directories into the binary. Ours pointed at store paths that do not exist
  # off Nix, so the shell ignored /etc/fish (config.fish, conf.d, functions,
  # completions), `<builtin> --help` said "missing man page" (CMake builds
  # without the embed-manpages feature), and `fish_config browse` looked for
  # the executable in the store. Built with cargo and no PREFIX/DATADIR/BINDIR/
  # DOCDIR, fish uses /etc/fish, its embedded data and man pages, and the
  # directory of the running executable — exactly as upstream's binary does.
  # It also drops nixpkgs' NixOS-only script edits (store paths for awk, grep,
  # getent and python, the NIX_PROFILES hook, trimmed sudo completions).
  #
  # No Windows target: fish is deeply Unix (fork, termios, Unix signals) and
  # has no upstream Windows port.
  #
  # fish dispatches on argv[0]: run as `fish_indent` or `fish_key_reader` it is
  # that tool. We ship one `fish` and announce the other two as alias names
  # (`multicall.programs` below; there is nothing to fold).
  outputs = { self, unpins-lib }:
    unpins-lib.lib.mkStandaloneFlake {
      inherit self;
      name = "fish";
      license = "GPL-2.0-only";

      # fish dispatches on argv[0] itself; this only announces the two names
      # to `unpin install`. The man pages come from $out/share/man.
      multicall = {
        programs = [ { name = "fish"; aliases = [ "fish_indent" "fish_key_reader" ]; } ];
      };

      # Runs a command, reads an embedded man page (what `<builtin> --help`
      # shows) and prints the system config dir. A build that bakes install
      # directories, or lacks the embedded pages, fails the pattern.
      smoke = [ "-c" "status get-file man/man1/string.1 >/dev/null; and echo unpins-smoke-ok sysconf=$__fish_sysconf_dir" ];
      smokePattern = "unpins-smoke-ok sysconf=/etc/fish";

      # Linux: nix-lib's engine Rust route (no gcc: prebuilt rustc, linked by
      # the engine cc against the engine musl). darwin: nixpkgs' rustPlatform.
      build = pkgs:
        let
          sp = pkgs.pkgsStatic;
          lib = pkgs.lib;
          ulib = unpins-lib.lib;
          linux = sp.stdenv.hostPlatform.isLinux;
          # Linux: the vendored crates from the build machine's set (the musl
          # set's vendoring runs nixpkgs' musl cargo, gcc-built), and pcre2
          # from the engine set.
          upstream = if linux then pkgs.buildPackages.fish else sp.fish;
          pcre2 =
            if linux then
              (ulib.enginePkgsStaticFor {
                inherit pkgs;
                toolchain = ulib.unpinToolchain pkgs.stdenv.buildPlatform.system;
              }).pcre2
            else sp.pcre2;

          common = {
            pname = "fish";
            inherit (upstream) version src cargoDeps;

            nativeBuildInputs = [
              pkgs.buildPackages.gettext # msgfmt, for the localize-messages feature
              (pkgs.buildPackages.python3.withPackages (ps: [ ps.sphinx ])) # man pages
              (if linux then pkgs.buildPackages.pkg-config else sp.buildPackages.pkg-config) # sees the target pcre2
            ];
            buildInputs = [ pcre2 ] ++ lib.optional sp.stdenv.hostPlatform.isDarwin sp.libiconv;

            # fish-config-bin-path.patch: `fish_config browse` runs the
            # executable itself, not a `fish` beside it.
            patches = [ ./patches/fish-config-bin-path.patch ];
            postPatch = ''
              patchShebangs build_tools/git_version_gen.sh
            '';

            preBuild = ''
              export HOME=$TMPDIR
            '';

            postInstall = ''
              man1=$(find target -type d -path '*/fish-docs/man/man1' | head -1)
              [ -n "$man1" ] && [ -f "$man1/fish.1" ] || { echo "fish: no man pages built" >&2; exit 1; }
              mkdir -p $out/share/man
              cp -r "$man1" $out/share/man/man1
              # The vendored PCRE2 (10.43) predates `(*scan_substring:`.
              grep -q scan_substring $out/bin/fish \
                || { echo "fish: vendored PCRE2 linked, not nixpkgs'" >&2; exit 1; }
            '';

            doInstallCheck = pkgs.stdenv.buildPlatform.canExecute sp.stdenv.hostPlatform;
            installCheckPhase = ''
              runHook preInstallCheck
              f=$out/bin/fish
              export HOME=$TMPDIR
              [ "$($f -c 'echo $__fish_sysconf_dir')" = /etc/fish ] \
                || { echo "installCheck: sysconf is not /etc/fish" >&2; exit 1; }
              [ -z "$($f -c 'echo $__fish_data_dir $__fish_help_dir')" ] \
                || { echo "installCheck: a data/doc dir is baked in" >&2; exit 1; }
              # Through files: under pipefail `grep -q` closing the pipe early
              # would fail the check on fish's SIGPIPE, not on the content.
              $f -c 'status get-file man/man1/string.1' > $TMPDIR/string.1
              grep -q '^\.TH "STRING"' $TMPDIR/string.1 \
                || { echo "installCheck: string.1 is not embedded" >&2; exit 1; }
              $f -c 'status get-file functions/fish_config.fish' > $TMPDIR/fish_config.fish
              grep -q '__fish_bin_path (status fish-path)' $TMPDIR/fish_config.fish \
                || { echo "installCheck: fish_config patch not embedded" >&2; exit 1; }
              $f -c 'string match -rq "(a)(*scan_substring:(1)a)" a' \
                || { echo "installCheck: PCRE2 lacks (*scan_substring:" >&2; exit 1; }
              ln -s $f $TMPDIR/fish_indent
              [ "$(printf 'if true;echo x;end\n' | $TMPDIR/fish_indent)" = "$(printf 'if true\n    echo x\nend')" ] \
                || { echo "installCheck: argv[0] fish_indent dispatch failed" >&2; exit 1; }
              runHook postInstallCheck
            '';

            meta = upstream.meta // { mainProgram = "fish"; };
          };

          env = {
            # Sphinx missing is then an error, not a build without man pages.
            FISH_BUILD_DOCS = "1";
            # pcre2-sys builds its own vendored PCRE2 on any musl target;
            # link nixpkgs' pcre2 instead, as nixpkgs' fish does.
            PCRE2_SYS_STATIC = "0";
          };
        in
        if linux then
          unpins-lib.lib.mkEngineRust pkgs (common // {
            bins = [ "fish" ];
            cargoBuildFlags = [ "--bin" "fish" ];
            # The target is never the build machine's (musl), so the pkg-config
            # crate wants the cross go-ahead to use the target's pcre2.
            env = env // { PKG_CONFIG_ALLOW_CROSS = "1"; };
          })
        else
          sp.rustPlatform.buildRustPackage (common // {
            inherit env;
            cargoBuildFlags = [ "--bin" "fish" ];
            # The upstream suite needs a pty, procps and a helper built with
            # `cc`; installCheck below covers what this build changes.
            doCheck = false;
          });
    };
}
