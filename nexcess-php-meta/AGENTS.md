# nexcess-php-meta

Builds one `nexcess-php-meta-<version>` RPM per PHP version, each of which requires the whole
base + PECL + version-specific package set for that version.

## Architecture in a paragraph

Installing thirty-odd individual RPMs per PHP version is slow and drifts between hosts, so this
builder collapses each version into a single noarch RPM whose only content is its `Requires:`
line. `php-meta-builder.sh` is the entire tool — Bash with no dependency beyond `rpmbuild`, and
it `cd`s to its own directory on startup so it always reads the config next to it. `read_config`
takes the RPM Version and Release from the first `*` heading in `changelog.txt` and loads every
package list from `config.yaml` through `parse_yaml_array`, a line-based parser that recognizes
a `key:` alone on a line followed by `- item` lines and nothing else. `build_requires` then
assembles one version's requirement list: `base_requirements` verbatim, then each entry of
`php_base_packages`, `php_extra_base_packages`, `php_pecl_modules`, `php_extra_pecl_modules`,
and `<ver>_specific_packages` prefixed with `<ver>-`, dropping anything in
`el<N>_exclude_packages` — plus, for every list except `<ver>_specific_packages`, anything in
`<ver>_exclude_packages` (see Conventions). N comes from `VERSION_ID` in
`/etc/os-release` at runtime, defaulting to 9. `make` writes one SPEC per version into `SPECS/`;
`build` runs `rpmbuild -bb` over them with `_topdir` pointed at this directory, so `BUILD/
RPMS/ SPECS/ SRPMS/` are produced here and are gitignored. The resulting RPMs are what the
parent [Ansible role](../AGENTS.md) installs when `use_meta_php_package: true`.

## File map

```
nexcess-php-meta/
├── php-meta-builder.sh   # the whole tool: make | build | clean | help, plus -s/--skip
├── config.yaml           # package lists per PHP version, plus EL-level and version-level exclusions
├── changelog.txt         # sole source of the RPM Version/Release; newest entry first
└── SPECS/                # generated, gitignored — wiped by both `clean` and `make`
```

## Commands

Run on a GNU/Linux host — see the first convention below; this script does not work on macOS.
Options must come **before** the command: each command case exits immediately, so
`./php-meta-builder.sh make -s php74` silently ignores the skip list.

```bash
./php-meta-builder.sh help          # usage, with the configured version list as the --skip example
./php-meta-builder.sh make          # clean, then write one SPEC per version into SPECS/
./php-meta-builder.sh build         # rpmbuild -bb every SPEC in SPECS/ (run `make` first)
./php-meta-builder.sh clean         # remove SPECS/, BUILD/, RPMS/, SRPMS/

# Restrict to a subset — pass the same --skip list to both steps
./php-meta-builder.sh -s php54u,php55u make
./php-meta-builder.sh -s php54u,php55u build

# Check after editing (no linter is configured in the repo)
bash -n php-meta-builder.sh
shellcheck php-meta-builder.sh   # exits non-zero: SC1087 twice on the deliberate eval-based
                                 # array indirection, plus SC1091 on `source /etc/os-release`
```

Building requires the `rpm-build` package. Finished RPMs land in `RPMS/noarch/`, named with the
`%{?dist}` suffix `rpmbuild` supplies (`...el9.noarch.rpm`). On a target host, once published to
a reachable repository:

```bash
dnf install nexcess-php-meta-php74
```

## Conventions

- **This runs on GNU/Linux only, not macOS.** The list-item regex in `parse_yaml_array` contains
  a `*?` that glibc's `regcomp` accepts but BSD's rejects. On macOS every call returns an empty
  array, so `make` emits `regular expression ... repetition-operator operand invalid` to stderr
  and then generates zero specs without failing. Bash 4.2 or newer is also required (`declare
  -g`), but a newer Bash on macOS does not help.
- **Build on the EL release you are building for — EL7 and EL9 are the two targets.** The
  exclusion set comes from `VERSION_ID` in `/etc/os-release`, falling back to EL9 when that file
  or the variable is missing. `config.yaml` defines `el7_exclude_packages` only, so an EL7 build
  drops `php-sourceguardian-loader` and an EL9 build applies no EL-level exclusions at all.
  Build EL7 packages anywhere else and you silently get the EL9 `Requires:` rather than an
  error. Adding an EL-level exclusion for EL9 means adding an `el9_exclude_packages` key.
- **Bump `changelog.txt` before every build, and know that it re-versions everything.** One
  entry sets Version and Release for all the meta packages at once. The newest entry goes on
  top; `read_config` greps the first line starting with `*` and matches a hyphen followed by
  `N.N.N-N`, so the date-shaped `2026.6.25-01` is convention rather than a requirement, but a
  line with no match aborts the run. Match the existing format exactly, including the absent
  space after the `*`. The whole file is inlined into each SPEC's `%changelog`.
- **Adding a PHP version is config-only.** Add it to `php_versions` and add a matching
  `<ver>_specific_packages` block. Nothing in the script hardcodes a version, and the `help`
  output builds its example from `php_versions`. The version string must be a valid Bash
  identifier — `read_config` derives `<ver>_specific_packages` and `<ver>_exclude_packages` from
  it and skips both with a debug message if it isn't, so a name like `php8.5` still gets a spec,
  just one missing all its version-specific packages.
- **`config.yaml` is not real YAML to this script.** `parse_yaml_array` opens a section on
  `<key>:` alone on a line at any indentation, then collects every `- value` line until a line
  that starts a new key **in column 0**. An indented sub-key does not close the section, so list
  items nested under it are silently folded into the enclosing array. Inline lists, anchors, and
  multi-line scalars are ignored. Keep the file flat.
- **The two exclusion levels are not applied uniformly.** `base_requirements`,
  `php_base_packages`, `php_pecl_modules`, and their `php_extra_*` counterparts are filtered by
  both `el<N>_exclude_packages` and `<ver>_exclude_packages`. `<ver>_specific_packages` is
  filtered by the EL list only — a version-level exclusion will not remove a package listed
  there.
- **`php_extra_base_packages` and `php_extra_pecl_modules` are read but unused here.**
  `read_config` parses both and `build_requires` honors them, but `config.yaml` defines neither,
  so they are always empty. The similarly named variables in `../defaults/main.yml` belong to
  the role's direct-install path and have no effect on what a meta package contains.
- **The script hardcodes `PATH`.** It sets
  `PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin` before anything else, and
  that applies to `rpmbuild` and every other child process. An `rpmbuild` outside those six
  directories will not be found however the caller's environment is set up.
- **`base_requirements` entries are not prefixed.** They land in `Requires:` verbatim, which is
  how `remi-release` gets in; everything else is emitted as `<ver>-<package>`.
- **`make` destroys previous output.** It calls `clean` before generating, which removes
  `BUILD/`, `RPMS/`, and `SRPMS/` as well as `SPECS/`. Copy RPMs out before regenerating.
- **This package list is independent of the role's.** `../defaults/main.yml` has its own
  `php_base_packages`/`php_pecl_modules`/`<ver>_specific_packages` for the direct-install path,
  and the two have already diverged. Changing one does not change the other.

## See also

- [README.md](README.md) — build and publish walkthrough
- [../AGENTS.md](../AGENTS.md) — the Ansible role that installs these packages
- [../CONTRIBUTING.md](../CONTRIBUTING.md) — how to propose a change
