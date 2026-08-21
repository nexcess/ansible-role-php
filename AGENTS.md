# ansible-role-php

Ansible role that installs and configures Remi's SCL-packaged PHP on EL6/EL7 hosts, so multiple PHP versions can run side by side on the same server.

## Architecture in a paragraph

Nexcess hosting needs several PHP versions installed concurrently on one box, so this role targets Remi's Software Collections (SCL) packages rather than the distro's single-version PHP. `tasks/main.yml` is the entry point: it installs PHP either package-by-package (`php_base_packages`, `php_pecl_modules`, and a `{{ php_prefix }}_specific_packages` list keyed by version) or as one `nexcess-php-meta-{{ php_prefix }}` RPM when `use_meta_php_package` is set, then symlinks the SCL binaries and `php.ini` into the normal system paths so callers don't need to know SCL's `/opt/remi` layout. It always includes `tasks/opcache.yml` to reconcile the OpCache ini file, and conditionally includes `tasks/fpm.yml` to install and configure PHP-FPM pools when `php_fpm_enabled` is true. The role depends on `nexcess.repo-remi` (declared in `meta/main.yml`) to have already configured the Remi repository on the target host. The `nexcess-php-meta/` directory is a separate, self-contained tool: a bash script plus RPM spec config that builds the `nexcess-php-meta-<version>` packages this role installs when `use_meta_php_package: true` — it has no dependency on the Ansible task tree and is run by hand on a build host, not by the role itself.

## File map

```
.gitignore
defaults/
  main.yml                  # role variables: PHP prefix/version package lists, FPM and OpCache settings
handlers/
  main.yml                  # php-fpm service handlers (start/stop/restart/reload); every handler is a no-op unless php_fpm_enabled
LICENSE
meta/
  main.yml                  # Galaxy metadata; declares nexcess.repo-remi as a dependency
nexcess-php-meta/            # standalone RPM meta-package builder, independent of the role's tasks
  changelog.txt              # RPM changelog; php-meta-builder.sh parses the top entry for version/release
  config.yaml                # per-EL-version package lists and exclusions consumed by php-meta-builder.sh
  php-meta-builder.sh        # make/build/clean CLI that generates and builds the nexcess-php-meta-<version> spec files
README.md
tasks/
  fpm.yml                   # installs php-fpm, deletes the stock www.conf pool, writes pools from php_fpm_pools
  main.yml                  # entry point: installs PHP packages (or the meta-package), symlinks SCL binaries and php.ini, includes fpm.yml and opcache.yml
  opcache.yml                # reconciles OpCache ini files across php_extension_conf_paths, removing any that don't match php_opcache_conf_filename
templates/
  browscap.ini.j2           # static browscap.org database, deployed verbatim when php_install_browscap_ini is true
  opcache.ini.j2             # renders the php_opcache_* vars into an opcache ini file
  pool-template.conf.j2      # FPM pool config; reads backnet_addr, which has no role default — it must come from inventory or group_vars
```

## Commands

This repo has no CI, lint, or test configuration (no `.ansible-lint`, `.yamllint`, `molecule/`, or `.github/workflows`). The only executable tooling is the RPM meta-package builder:

```bash
cd nexcess-php-meta
./php-meta-builder.sh make    # parse config.yaml + changelog.txt, generate a SPEC file per PHP version
./php-meta-builder.sh build   # run rpmbuild against the generated SPECs (needs a working rpmbuild environment)
./php-meta-builder.sh clean   # remove generated SPEC/RPM artifacts
```

A consuming playbook pulls the role itself via Galaxy (see `README.md`) and runs it with `ansible-playbook`; there's no local playbook or inventory in this repo to run it against directly.

## Conventions

- `pool-template.conf.j2` reads `backnet_addr`, which isn't defined anywhere in `defaults/main.yml`. Any playbook enabling `php_fpm_enabled` must supply it via inventory or `group_vars`, or the FPM pool template render fails.
- `tasks/main.yml`'s `set_fact` guards for `php_opcache_conf_filename` and `php_extension_conf_paths` reference `__php_opcache_conf_filename`/`__php_extension_conf_paths`, which are undefined anywhere in the repo. Both guards are dead code in practice — `defaults/main.yml` already sets real values for both variables, so the `is not defined` condition never fires.
- Tasks use the older `key="value"` quoted-parameter style throughout, not the YAML-mapping module syntax — match it for consistency rather than mixing styles in the same file.

## See also

- [README.md](README.md) — usage from a consuming playbook, role variables pointer
