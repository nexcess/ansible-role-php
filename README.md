# Ansible Role: Nexcess SCL PHP

Installs Remi's SCL PHP Version(s).  By default this role only installs the CLI version of PHP. PHP 7.1 is the current default version of PHP installed by this role, but you can override via 'php_prefix'.  FPM options are available (see Role Variables below).

## Role Variables

See `defaults/main.yml`.

## Dependencies

- https://github.com/nexcess/ansible-role-repo-remi

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

## Using Meta Packages with `use_meta_php_package`

When the `use_meta_php_package` variable is set to `true`, this role will install a single meta-package instead of individual PHP packages. This meta-package is named `nexcess-php-meta-{{ php_prefix }}` and includes all base, PECL, and version-specific PHP packages required for that PHP version.

### How it works

By default, the role installs individual PHP packages using `yum` (or `dnf`) as defined in the `php_base_packages`, `php_pecl_modules`, and version-specific package lists. However, when `use_meta_php_package: true` is set:

- The role skips installing individual PHP packages.
- It installs a single meta-package: `nexcess-php-meta-{{ php_prefix }}`.
- This meta-package aggregates all required PHP components into one installable unit.

### Prerequisites

To use this feature, you must have built and deployed the meta-packages using the `nexcess-php-meta` builder script. See the section below for more information.

### Example usage

```yaml
  roles:
    - { role: nexcess.php, php_prefix: "php56", use_meta_php_package: true }
```

This will install the `nexcess-php-meta-php74` package, which includes all necessary PHP packages for PHP 7.4.

## Building Meta Packages with `nexcess-php-meta`

The under the `nexcess-php-meta` folder is a bash script that generates RPM meta‑packages for each supported PHP version.
A meta‑package aggregates all required base, PECL, and version‑specific PHP packages into a single installable unit,
allowing you to pull the complete PHP stack with one `dnf`/`yum` command (e.g. `dnf install nexcess-php-meta-php74`).

### How the script works

1. **`make`** – parses the configuration, creates a clean `SPECS/` directory, and writes a SPEC file for every PHP version.  
2. **`build`** – runs `rpmbuild` on the generated SPEC files, producing the RPM meta‑packages.  
3. **`clean`** – removes all generated SPEC files and build artefacts.  

Optional **skip** logic (`-s/--skip`) lets you exclude specific PHP versions from generation or building.

### Typical usage

```bash
# Generate SPEC files for all PHP versions
./php-meta=builder.sh make

# Build the RPMs (requires a functional rpmbuild environment)
./php-meta=builder.sh build

# Install a meta‑package on a target host
sudo dnf install nexcess-php-meta-php74
```

### Skipping unwanted versions

If you only need a subset of versions, provide a comma‑separated list:
```bash
./php-meta=builder.sh -s php56,php70 make
./php-meta=builder.sh -s php56,php70 build
```

The script will still generate SPEC files for the remaining versions and ignore the skipped ones during the build step.
        
## License

MIT
