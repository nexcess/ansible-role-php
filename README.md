# Ansible Role: Nexcess SCL PHP

Ansible role that installs and configures Remi's SCL-packaged PHP on EL6/EL7 hosts, so multiple PHP versions can run side by side on the same server. By default it installs a broad set of PHP extensions (`php_base_packages` and `php_pecl_modules`) but does not enable or configure PHP-FPM pools, since `php_fpm_enabled` defaults to `false`. PHP 7.1 is the current default version, overridable via `php_prefix`. FPM options are available — see Role Variables below.

See [AGENTS.md](AGENTS.md) for the architecture, the full file map, and available commands.

## Dependencies

- [nexcess/ansible-role-repo-remi](https://github.com/nexcess/ansible-role-repo-remi) — must configure the Remi repository before this role runs.

## Role Variables

See `defaults/main.yml` for the full list, including package selections per PHP version, FPM settings, and OpCache settings.

## Add to Requirements

```yaml
- src: https://github.com/nexcess/ansible-role-php.git
  name: nexcess.php
```

## Example Playbook

```yaml
- hosts: php_hosts
  roles:
    - nexcess.php
```

## Using meta packages with `use_meta_php_package`

Setting `use_meta_php_package: true` installs a single `nexcess-php-meta-{{ php_prefix }}` package instead of the individual PHP, PECL, and version-specific packages this role would otherwise install one at a time.

```yaml
roles:
  - { role: nexcess.php, php_prefix: "php74", use_meta_php_package: true }
```

The meta-packages themselves aren't published anywhere by default — someone has to build and deploy them first with the `nexcess-php-meta` builder script. See [AGENTS.md](AGENTS.md#commands) for the build commands.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT
