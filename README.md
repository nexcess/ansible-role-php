# Ansible Role: Nexcess SCL PHP

Installs Remi's SCL PHP on EL7 and EL9 hosts, so several PHP versions can live on one
server without conflicting with the distro PHP. Each run installs one version, selected by
`php_prefix` (default `php71`). PHP-FPM pools and OpCache tuning are available but off or
defaulted unless you set them.

For architecture, the full command list, and the gotchas worth knowing before editing, see
[AGENTS.md](AGENTS.md).

## Requirements

- An EL7 or EL9 host (`yum`/`dnf`)
- [nexcess.repo-remi](https://github.com/nexcess/ansible-role-repo-remi), which provides the
  Remi repository this role installs from. It is declared as a dependency in `meta/main.yml`,
  so `ansible-galaxy` pulls it in automatically.

## Add to Requirements

```yaml
- src: https://github.com/nexcess/ansible-role-php.git
  name: nexcess.php
```

```bash
ansible-galaxy install -r requirements.yml
```

## Example Playbook

```yaml
- hosts: php_hosts
  become: true
  roles:
    - nexcess.php
```

The role sets no `become` of its own and every task needs root, so the play has to provide it.

Pick a version and enable FPM. `backnet_addr` is the address the pool listens on; this role
never defines it, so it has to come from the play, inventory, or group_vars:

```yaml
- hosts: php_hosts
  become: true
  vars:
    backnet_addr: "10.0.0.10"
  roles:
    - role: nexcess.php
      php_prefix: "php74"
      php_fpm_enabled: true
      php_fpm_pools:
        - name: "example"
          user: "example"
          group: "example"
          config:
            error_log: "/var/log/php-fpm/example-error.log"
            slow_log: "/var/log/php-fpm/example-slow.log"
```

Every pool listens on `{{ backnet_addr }}:{{ php_fpm_port }}` — the port is global, with no
per-pool override, so a second pool would collide with the first. Change
`templates/pool-template.conf.j2` if you need more than one.

## Role Variables

See [`defaults/main.yml`](defaults/main.yml) for every variable and its default. The ones you
will reach for most:

| Variable | Default | Purpose |
|---|---|---|
| `php_prefix` | `php71` | Which SCL PHP version to install |
| `use_meta_php_package` | `false` | Install one meta RPM instead of the individual packages |
| `php_extra_base_packages` | `[]` | Extra packages appended to `php_base_packages` |
| `php_extra_pecl_modules` | `[]` | Extra PECL modules appended to `php_pecl_modules` |
| `php_package_state` | `present` | Passed to every `yum` task — set `latest` to upgrade |
| `php_fpm_enabled` | `false` | Write FPM pool configs and enable the service at boot (the `php-fpm` package itself installs either way) |
| `php_fpm_pools` | `[]` | One pool config per entry |
| `php_fpm_port` | `9000` | Port every pool listens on |
| `php_single_version` | `true` | Symlink this version's `php.ini` to `/etc/php.ini` |
| `php_symlink_scl_bins` | `true` | Symlink the SCL binaries into `/usr/bin` |
| `php_ini_config` | `[]` | `name`/`value` pairs applied to the `[PHP]` section of `php.ini` |
| `php_install_browscap_ini` | `true` | Write the bundled browscap snapshot to `/etc/browscap.ini` |

`php_extra_*` apply to the individual-package path only — the meta RPM's contents are fixed when
it is built.

OpCache is configured on every run, whether or not you set anything: the role writes
`10-opcache.ini` into `{{ php_config_root }}/php.d` with `force`, overwriting the file the Remi
`php-opcache` package ships, and deletes any other file there that loads `opcache.so`. Set the
`php_opcache_*` variables to tune it; see [`defaults/main.yml`](defaults/main.yml).

## Using Meta Packages

Setting `use_meta_php_package: true` replaces the dozens of individual `yum` installs with a
single `nexcess-php-meta-{{ php_prefix }}` RPM that requires all base, PECL, and
version-specific packages for that version:

```yaml
  roles:
    - { role: nexcess.php, php_prefix: "php74", use_meta_php_package: true }
```

This installs `nexcess-php-meta-php74`.

The meta packages have to be built and published to a repository the host can reach first. The
builder — `nexcess-php-meta/php-meta-builder.sh` — lives in this repo; see
[nexcess-php-meta/README.md](nexcess-php-meta/README.md).

This path is also the only way to install anything outside `php56`, `php70`–`php74`, and
`php80`. The individual-package lists in `defaults/main.yml` stop there, while the builder
covers `php54u` through `php85`.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT
