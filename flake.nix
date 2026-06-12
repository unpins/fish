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
  # What makes fish special in this catalog: upstream's 4.x Rust rewrite ALREADY
  # compiles the entire share/fish data tree (every function, completion, prompt
  # and theme — ~1000 .fish scripts, 12 MB) straight into the binary as embedded
  # assets, reachable via the `status get-file`/`embedded:` mechanism. So unlike
  # zsh (whose function tree we had to mount via a --wrap VFS), fish needs no VFS
  # at all: `env -i fish -c '...'` runs with no share/fish on disk, resolving
  # `fish_prompt` and friends from `embedded:functions/...`, and strace shows
  # zero /nix/store reads at runtime. stock pkgsStatic.fish is already a single
  # self-contained binary.
  #
  # What we add over upstream's own binary, then, is purely the alternate builds:
  # static-musl on every Linux arch (i686/aarch64/armv7l/ppc64le/riscv64, which
  # upstream does not publish) and a libSystem-only macOS build, all in the
  # unpins catalog shape with the man page embedded as unpin/man/*.
  #
  # No Windows target: fish is Rust and deeply Unix (fork, termios, PTY, Unix
  # signals) with no upstream Windows port, and cosmocc is a C toolchain that
  # does not apply to a Rust binary. Omitting `windowsBuild` drops the
  # windows-x86_64 attr; fish still runs on macOS, so this is NOT `linuxOnly`.
  #
  # fish installs three byte-identical binaries — `fish`, `fish_indent`,
  # `fish_key_reader` — because the 4.x binary is a native argv[0] multicall:
  # run under any of those names it dispatches accordingly (`src/builtins/
  # fish_indent.rs`, `.../fish_key_reader.rs`). We keep one physical `fish` and
  # re-expose the other two as install-time alias names via `withAliases` (the
  # same one-binary-plus-aliases shape as lua's lua/luac and quickjs's qjs/qjsc,
  # except fish does the dispatch itself so no merge step is needed). Nothing is
  # lost: `fish_indent` is also an internal builtin, so in-shell reformat works
  # with no sibling on disk, and `unpin install fish` materializes the
  # `fish_indent`/`fish_key_reader` symlinks for external/editor use.
  #
  # Build deltas vs nixpkgs, all in service of a portable single binary:
  #
  #  1. doCheck = false — fish's CMake check compiles a helper C program
  #     (tests/fish_test_helper.c) with `cc`, absent from the static cross
  #     stdenv, so the otherwise-fine static binary fails at checkPhase. Tests
  #     are upstream CI's job.
  #
  #  2. propagatedBuildInputs = [ ] — nixpkgs declares coreutils/gnugrep/gnused/
  #     gettext/man-db as "required runtime binaries" and bakes their store
  #     paths into fish's closure for NixOS purity. A relocatable binary must
  #     resolve those helpers from the user's PATH instead (every system has
  #     them). Dropping them also removes man-db-static from the closure, whose
  #     cross build is itself broken for ppc64le/riscv64 — so this is what makes
  #     those targets build at all.
  #
  #  3. -DWITH_DOCS=OFF + man graft — the Sphinx man-page step builds a
  #     build-host `xtask` helper that nixpkgs cross-links against the *target*
  #     pcre2 (`-lpcre2-8` not found), breaking every cross target. Skip it and
  #     graft the arch-independent pages from the cached glibc fish
  #     (pkgs.buildPackages.fish), exactly the nixpkgs-graft the catalog's
  #     Windows path already uses — giving identical man across every target.
  #
  #  4. Embedded-script store-path strip — see the postPatch comment below.
  outputs = { self, unpins-lib }:
    unpins-lib.lib.mkStandaloneFlake {
      inherit self;
      name = "fish";
      license = "GPL-2.0-only";

      # fish has -c; a green `-c` smoke also proves the embedded asset bundle is
      # reachable (the parser/executor are driven entirely from embedded:*).
      smoke = [ "-c" "echo unpins-smoke-ok" ];
      smokePattern = "unpins-smoke-ok";

      build = pkgs:
        let
          # The build-platform cc wrapper reads its link flags from the
          # platform-salted variable NIX_LDFLAGS_<suffixSalt> (e.g.
          # NIX_LDFLAGS_x86_64_apple_darwin when the build host is Intel,
          # NIX_LDFLAGS_arm64_apple_darwin on an Apple-Silicon CI runner), not
          # the friendly NIX_LDFLAGS_FOR_BUILD alias. Derive the salt from the
          # build stdenv's cc so the libiconv fix below targets the right var on
          # whichever host does the cross.
          buildSalt = pkgs.buildPackages.stdenv.cc.suffixSalt;

          # The libiconv fix is CROSS-ONLY. On a cross the build salt differs
          # from the target salt, so the build-host -L lands only on the
          # build-script link. On a NATIVE darwin build the two salts are equal,
          # so the same -L would leak into the *target* link and pull the dynamic
          # libiconv.2.dylib into the final binary — which the portability gate
          # rejects (the "libiconv catch"). Native build-host links resolve
          # -liconv on their own, so they need nothing here.
          isDarwinCross = pkgs.stdenv.hostPlatform.isDarwin
            && pkgs.stdenv.buildPlatform.config != pkgs.stdenv.hostPlatform.config;

          # usePython = false drops nixpkgs' generated __fish_anypython.fish,
          # which hardcodes ${python3.interpreter} (a store path) — NixOS purity
          # again, and on x86_64-darwin the pkgsStatic python3 is marked broken,
          # so even referencing it fails at eval. Upstream's own __fish_anypython
          # (which searches PATH for python) stays instead — the portable choice.
          #
          # procps/coreutils overridden to the build-PLATFORM tools: fish's
          # postPatch interpolates ${procps}/${coreutils} to patch TEST files
          # (highlight.rs test code, tests/checks/jobs.fish, ...). Under
          # pkgsStatic that pulls procps-static, and on darwin procps depends on
          # system_cmds, whose static/cross build fails (meson "objc compiler
          # not defined in cross file") — both on native x86_64-darwin (static)
          # and on the aarch64-darwin cross (arm64 system_cmds). These tools are
          # only used at build time to write path strings into files we never
          # run (doCheck = false), so buildPackages.* (always a native build of
          # the build host) satisfies the interpolation on every target without
          # dragging in a static or cross system_cmds.
          base = (pkgs.pkgsStatic.fish.override {
            usePython = false;
            procps = pkgs.buildPackages.procps;
            coreutils = pkgs.buildPackages.coreutils;
          }).overrideAttrs (o: {
            doCheck = false;
            # fish sets doInstallCheck = true, which pulls nativeCheckInputs
            # (procps, system_cmds, ...) as static deps — and procps-static /
            # system_cmds-static fail to build on darwin. They are test-only;
            # drop the whole check apparatus.
            doInstallCheck = false;
            nativeCheckInputs = [ ];
            propagatedBuildInputs = [ ];

            # On a Darwin *cross*, cargo compiles the fish-common crate's build
            # SCRIPT for the build host, and rustc links it against the build
            # platform's libiconv (`-liconv`) via the unprefixed build cc
            # wrapper. fish's buildInputs.libiconv is the *target* libiconv, so
            # the build-host link fails with "library not found for -liconv".
            # This bites CI, which builds x86_64-darwin from an arm64 runner
            # (GitHub retired native Intel macOS runners), and symmetrically the
            # local Intel->arm64 cross-check. Point the build cc at the
            # build-platform libiconv's lib output (its dylib lives in `out`,
            # not the `-dev` output a plain depsBuildBuild entry surfaces) via
            # the build-salted NIX_LDFLAGS var. Cross-only — see isDarwinCross.
            preBuild = (o.preBuild or "")
              + pkgs.lib.optionalString isDarwinCross ''
                export NIX_LDFLAGS_${buildSalt}="''${NIX_LDFLAGS_${buildSalt}:-} -L${pkgs.lib.getLib pkgs.buildPackages.libiconv}/lib"
              '';
            cmakeFlags = (o.cmakeFlags or [ ]) ++ [ "-DWITH_DOCS=OFF" ];

            # nixpkgs bakes absolute /nix/store tool paths into fish's embedded
            # completion/function scripts (awk -> ${gawk}/bin/awk, plus grep,
            # getent, python) for NixOS purity — the 4.x Rust build compiles the
            # whole share/ tree into the binary, so those store paths travel
            # inside it (~60 of them). A portable single binary must instead
            # resolve those helpers from the user's PATH: off-Nix the store
            # paths don't exist, which would break every completion that shells
            # out. Strip the store-path prefix back to the bare command name
            # across the embedded tree, before the Rust build embeds it. (The
            # only /nix/store strings left afterwards are fish-static's own
            # SYSCONFDIR/DATADIR self-references, which ENOENT off-Nix and fall
            # back to the embedded assets — behaviourally self-contained.)
            postPatch = (o.postPatch or "") + ''
              find share -name '*.fish' -exec sed -i -E \
                's@/nix/store/[a-z0-9]{32}-[^/]+/bin/@@g' {} +
            '';

            # Drop the two redundant copies; they come back as alias symlinks.
            postInstall = (o.postInstall or "") + ''
              rm -f "$out/bin/fish_indent" "$out/bin/fish_key_reader"
            '';
          });

          aliased = unpins-lib.lib.withAliases pkgs {
            primary = "fish";
            aliases = [ "fish_indent" "fish_key_reader" ];
          } base;
        in
        # Graft the man pages (we built with WITH_DOCS=OFF). Setting man here
        # marks passthru.unpinEmbedsMan so mkStandaloneFlake skips its own
        # harvest-own-share/man step (which would find none).
        unpins-lib.lib.withMan pkgs {
          primary = "fish";
          manRoot = "${pkgs.buildPackages.fish}";
        } aliased;
    };
}
