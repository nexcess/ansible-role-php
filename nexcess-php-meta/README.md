# nexcess-php-meta

Generates one RPM per PHP version — `nexcess-php-meta-php74`, `nexcess-php-meta-php85`, and so
on — that pulls in the complete PHP stack for that version in a single `dnf install`. The
[parent Ansible role](../README.md) installs these instead of dozens of individual packages when
`use_meta_php_package: true`.

For how the script and its config work, see [AGENTS.md](AGENTS.md).

## Requirements

- **A GNU/Linux host.** The config parser relies on a GNU regex extension; on macOS and other
  BSD-derived systems every package list comes back empty and the build produces nothing.
- **An EL host matching the release you are building for.** EL7 and EL9 are the two targets;
  the script reads `/etc/os-release` to pick which package exclusions apply, and defaults to EL9
  when it can't. Build EL7 packages on an EL7 host.
- `rpm-build` (provides `rpmbuild`)
- Bash 4.2 or newer

## Building

```bash
cd nexcess-php-meta
./php-meta-builder.sh make     # writes SPECS/nexcess-php-meta-<version>.spec for every version
./php-meta-builder.sh build    # rpmbuild -bb each spec; output lands in RPMS/noarch/
```

To build only some versions, skip the rest. Options go before the command, and the same list has
to be passed to both steps:

```bash
./php-meta-builder.sh -s php54u,php55u,php56u make
./php-meta-builder.sh -s php54u,php55u,php56u build
```

`./php-meta-builder.sh clean` empties `SPECS/` and removes `BUILD/`, `RPMS/`, and `SRPMS/`. So
does `make`, before it regenerates — copy finished RPMs out first.

Publish the RPMs from `RPMS/noarch/` to a repository the target hosts can reach, then:

```bash
dnf install nexcess-php-meta-php74
```

## Adding a PHP version

1. Add the version string to `php_versions` in `config.yaml`. It has to be a valid Bash
   identifier — `php85`, not `php8.5`. Otherwise its version-specific lists are skipped with a
   `[DEBUG]` line on stderr and a spec is still written, producing a shipped package missing
   every version-specific requirement.
2. Add a `<version>_specific_packages:` block for anything not in the shared
   `php_base_packages` / `php_pecl_modules` lists.
3. Add `<version>_exclude_packages:` if a shared package doesn't exist for that version. Note
   that this only filters the shared lists — it will **not** remove something you also put in
   `<version>_specific_packages`. See the exclusion asymmetry in [AGENTS.md](AGENTS.md#conventions).
4. Add a new entry at the **top** of `changelog.txt`, matching the existing format. It is the
   only source of the RPM version and release, and it applies to every meta package, so this
   bumps all of them.
5. Rebuild and verify: `./php-meta-builder.sh make && grep Requires SPECS/nexcess-php-meta-<version>.spec`

If the version should also be installable without a meta package, add matching lists to
[`../defaults/main.yml`](../defaults/main.yml) — the two configs are separate.

## Contributing

See [../CONTRIBUTING.md](../CONTRIBUTING.md).
