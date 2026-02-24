#!/usr/bin/env bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin
# This script builds meta packages for PHP using easy configuration files.

set -euo pipefail

# Enter the directory of the script to ensure config files are ready correctly.
cd -- "$(dirname "$0")" >/dev/null 2>&1 || exit 1

# Logging helpers.
log_debug() { echo "[DEBUG] $*" >&2; }
log_info()  { echo "[INFO]  $*"; }
log_error() { echo "[ERROR] $*" >&2; }

# Detect the OS to read the config for exclusions, default to EL9.
EL_VERSION="9"

if [[ -f /etc/os-release ]]; then
    source /etc/os-release

    if [[ -n "${VERSION_ID:-}" ]]; then
        # Take only the major version (e.g., "7.9" -> "7").
        EL_VERSION="${VERSION_ID%%.*}"
    fi
fi
log_info "Detected EL Version: ${EL_VERSION}"

# Configuration.
CONFIG_FILE="config.yaml"
CHANGELOG_FILE="changelog.txt"
SPEC_DIR="SPECS"

# Global variables for configuration values.
declare -a base_requirements
declare -a php_versions
declare -a php_base_packages
declare -a php_pecl_modules
declare -a php_extra_base_packages
declare -a php_extra_pecl_modules
declare -a el_excluded_packages
declare -a skip_versions
SPEC_VERSION=""
SPEC_RELEASE=""

# Parses YAML list format and populates Bash arrays with values.
parse_yaml_array() {
    local key=$1 dest=$2
    local -a values=()
    local in_section=0

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Remove a possible Windows CR.
        line=${line%$'\r'}

        # Start of the requested top‑level key.
        if [[ $line =~ ^[[:space:]]*${key}:[[:space:]]*$ ]]; then
            in_section=1
            continue
        fi

        # Leaving the section – a new top‑level key ends it.
        if (( in_section )) && [[ $line =~ ^[[:alpha:]_][a-zA-Z0-9_-]*: ]]; then
            break
        fi

        # List items: dash followed by optional quotes.
        if (( in_section )) && [[ $line =~ ^[[:space:]]*-[[:space:]]*(\"([^\"\\]*?)\"|([^[:space:]]*)) ]]; then
            local val=""
            if [[ ${BASH_REMATCH[2]} ]]; then
                # Quoted value.
                val="${BASH_REMATCH[2]}"
            else
                # Unquoted value.
                val="${BASH_REMATCH[3]}"
            fi
            val=${val//$'\r'/} # Strip stray CR.

            # If non-empty value, add to the list of values.
            [[ -n $val ]] && values+=("$val")
        fi
    done < "$CONFIG_FILE"

    # Assign the collected values to the caller-provided array
    # Using indirect reference to create a global array with the given name.
    declare -g -a "$dest"

    # The eval safely expands the array contents (quoting each element).
    if (( ${#values[@]} > 0 )); then
        eval "$dest=( \"\${values[@]}\" )"
    fi
}

# Reads changelog to extract version and release, then parses
# all package lists from the configuration file.
read_config() {
    # Verify that a changelog exists.
    if [[ ! -f $CHANGELOG_FILE ]]; then
        log_error "Missing $CHANGELOG_FILE"
        exit 1
    fi

    # Get the first release heading from the changelog, its expected to have the current version.
    local first_entry
    first_entry=$(grep -m1 '^\*' "$CHANGELOG_FILE")

    # Parse the entry for the version number.
    # Expected: “… - 2026.1.26-01”
    if [[ $first_entry =~ -[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+)-([0-9]+) ]]; then
        SPEC_VERSION="${BASH_REMATCH[1]}"
        SPEC_RELEASE="${BASH_REMATCH[2]}"
        log_info "Using VERSION=$SPEC_VERSION RELEASE=$SPEC_RELEASE from changelog"
    else
        log_error "Cannot parse version/release from $CHANGELOG_FILE"
        exit 1
    fi

    # Load the configurations that apply to every PHP version.
    parse_yaml_array "base_requirements"       base_requirements
    parse_yaml_array "php_versions"            php_versions
    parse_yaml_array "php_base_packages"       php_base_packages
    parse_yaml_array "php_pecl_modules"        php_pecl_modules
    parse_yaml_array "php_extra_base_packages" php_extra_base_packages
    parse_yaml_array "php_extra_pecl_modules"  php_extra_pecl_modules

    # Load exclusions for the detected EL version (e.g., el7_exclude_packages).
    parse_yaml_array "el${EL_VERSION}_exclude_packages" el_excluded_packages

    # Each version may have specific packages defined in the config,
    # try and find those.
    # Use loop with default empty expansion to prevent crash if php_versions is empty.
    for ver in "${php_versions[@]:-}"; do
        # Ensure the version is not empty.
        [[ -n $ver ]] || continue
        local key="${ver}_specific_packages"

        # Ensure the key is safe for BASH variables.
        if [[ $key =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
            declare -g -a "$key"
            parse_yaml_array "$key" "$key"
        else
            log_debug "Skipping invalid identifier '$key'"
        fi
    done

    # Each version may have specific package excludes defined in the config.
    for ver in "${php_versions[@]:-}"; do
        [[ -n $ver ]] || continue
        local key="${ver}_exclude_packages"
        if [[ $key =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
            declare -g -a "$key"
            parse_yaml_array "$key" "$key"
        else
            log_debug "Skipping invalid identifier '$key'"
        fi
    done
}

# Constructs the complete list of package requirements for a PHP version
# including base packages, PECL modules, version‑specific packages, and base requirements.
build_requires() {
    local ver=$1
    local prefix="${ver}-"
    local -a reqs=()

    # Load version-specific excludes if defined.
    local ver_exclude_key="${ver}_exclude_packages"
    local -a ver_excluded=()
    if declare -p "$ver_exclude_key" &>/dev/null; then
        eval "ver_excluded=( \"\${$ver_exclude_key[@]:-}\" )"
    fi

    # Add base requirements first to satisfy system-level dependencies.
    for pkg in "${base_requirements[@]:-}"; do
        [[ -n "$pkg" ]] || continue

        # Skip if package is excluded.
        if [[ " ${el_excluded_packages[*]:-} " == *" $pkg "* ]]; then
            log_debug "Skipping $pkg (Excluded on EL${EL_VERSION})"
            continue
        fi

        # Skip if package is excluded for this version.
        if [[ " ${ver_excluded[*]:-} " == *" $pkg "* ]]; then
            log_debug "Skipping $pkg (Excluded for $ver)"
            continue
        fi

        reqs+=("$pkg")
    done

    # Add php base packages.
    for pkg in "${php_base_packages[@]:-}" "${php_extra_base_packages[@]:-}"; do
        [[ -n "$pkg" ]] || continue

        # Skip if package is excluded.
        if [[ " ${el_excluded_packages[*]:-} " == *" $pkg "* ]]; then
            log_debug "Skipping $pkg (Excluded on EL${EL_VERSION})"
            continue
        fi

        # Skip if package is excluded for this version.
        if [[ " ${ver_excluded[*]:-} " == *" $pkg "* ]]; then
            log_debug "Skipping $pkg (Excluded for $ver)"
            continue
        fi

        reqs+=("${prefix}${pkg}")
    done

    # Add php PECL modules.
    for pkg in "${php_pecl_modules[@]:-}" "${php_extra_pecl_modules[@]:-}"; do
        [[ -n "$pkg" ]] || continue

        # Skip if package is excluded.
        if [[ " ${el_excluded_packages[*]:-} " == *" $pkg "* ]]; then
            log_debug "Skipping $pkg (Excluded on EL${EL_VERSION})"
            continue
        fi

        # Skip if package is excluded for this version.
        if [[ " ${ver_excluded[*]:-} " == *" $pkg "* ]]; then
            log_debug "Skipping $pkg (Excluded for $ver)"
            continue
        fi

        reqs+=("${prefix}${pkg}")
    done

    # Add version-specific packages.
    local specific_key="${ver}_specific_packages"
    if declare -p "$specific_key" &>/dev/null; then
        # 'local -n' is Bash 4.3+. We use eval to copy the array content safely in Bash 4.2.
        local -a specific_arr
        eval "specific_arr=( \"\${$specific_key[@]:-}\" )"

        for pkg in "${specific_arr[@]:-}"; do
            [[ -n "$pkg" ]] || continue

            # Skip if package is excluded.
            if [[ " ${el_excluded_packages[*]:-} " == *" $pkg "* ]]; then
                log_debug "Skipping $pkg (Excluded on EL${EL_VERSION})"
                continue
            fi

            reqs+=("${prefix}${pkg}")
        done
    fi

    local IFS=,
    # Use :- to handle case where reqs array is empty
    echo "${reqs[*]:-}"
}

# Removes all content from the spec directory to prepare for new generation.
clean() {
    log_info "Cleaning $SPEC_DIR"
    rm -rf "${SPEC_DIR:?}/"* SRPMS SPECS RPMS BUILD
    mkdir -p "$SPEC_DIR"
}

# Creates individual spec files for each PHP version with appropriate
# package requirements and metadata.
make_specs() {
    read_config
    clean
    log_info "Generating spec files in $SPEC_DIR"
    for ver in "${php_versions[@]:-}"; do
        # Ignore any empty versions.
        [[ -n $ver ]] || continue

        # Skip versions supplied via -s/--skip.
        # Use :- to handle empty skip_versions array
        if [[ " ${skip_versions[*]:-} " == *" $ver "* ]]; then
            log_debug "Skipping spec for $ver (requested by --skip)."
            continue
        fi

        # Write the RPM SPEC file.
        local spec_file="${SPEC_DIR}/nexcess-php-meta-${ver}.spec"
        local requires
        requires=$(build_requires "$ver")
        cat > "$spec_file" <<EOF
Name:           nexcess-php-meta-${ver}
Version:        ${SPEC_VERSION}
Release:        ${SPEC_RELEASE}%{?dist}
Summary:        Meta package for PHP ${ver}
License:        MIT
BuildArch:      noarch
Requires:       $requires
%description
Meta package that pulls in the base, PECL and version-specific PHP
packages required for PHP ${ver}.
%files
%doc
%changelog
$(cat "$CHANGELOG_FILE")
EOF
        log_debug "Created $spec_file"
    done
}

# Executes rpmbuild on all generated spec files in the spec directory.
# Skips any spec whose PHP version appears in the global skip_versions array.
build() {
    if [[ ! -d "$SPEC_DIR" ]] || [[ -z "$(ls -A "$SPEC_DIR")" ]]; then
        log_error "No spec files in $SPEC_DIR – run '$0 make' first."
        exit 1
    fi

    log_info "Building RPMs from spec files."

    # Iterate over every spec file and build it unless its version was skipped.
    for spec in "$SPEC_DIR"/*.spec; do
        # Derive the PHP version from the file name.
        spec_name=$(basename "$spec" .spec)
        ver=${spec_name##*-}

        # If the version is in the skip list, log and continue to the next file.
        # Use :- to handle empty skip_versions array
        if [[ " ${skip_versions[*]:-} " == *" $ver "* ]]; then
            log_debug "Skipping build for $ver (requested by --skip)."
            continue
        fi

        # Run the rpmbuild.
        log_debug "rpmbuild -bb --define '_topdir $PWD' $spec"
        rpmbuild -bb --define "_topdir $PWD" "$spec"
    done
}

# Shows available commands and script usage.
print_help() {
    # Load php_versions only for help example; ignore errors if config missing.
    local -a help_versions=()
    if [[ -f $CONFIG_FILE ]]; then
        parse_yaml_array "php_versions" help_versions
    fi
    local example_list
    if (( ${#help_versions[@]} )); then
        # Use :- to handle empty array safely
        example_list=$(IFS=,; echo "${help_versions[*]:-}")
    else
        example_list="php56,php70"
    fi

    cat <<EOF
Usage: $0 [options] <command>

Options:
  -s, --skip <list>   Skip building specs for the comma‑separated PHP versions.
                      Example: -s "$example_list"
Commands:
  clean   – remove all generated spec files.
  make    – clean then create a spec file for each PHP version (excluding skips).
  build   – build RPMs from the spec files (requires prior 'make').
  help    – display this message.

If no command is supplied, this help is shown.
EOF
}

# If no command provided, show help.
if [[ $# -eq 0 ]]; then
    print_help
fi

# Parse arguments.
while (( $# > 0 )); do
    case "$1" in
        -h|help|--help)
            print_help
            exit 0
        ;;

        # Add PHP version(s) to the skip list.
        -s|--skip)
            if [[ -z ${2-} ]]; then
                log_error "Missing version list after $1."
                exit 1
            fi
            IFS=',' read -ra parts <<< "$2"
            for part in "${parts[@]}"; do
                part=${part//[[:space:]]/}
                [[ -n $part ]] && skip_versions+=("$part")
            done
            shift 2
        ;;

        clean)
            clean
            exit 0
        ;;

        make)
            make_specs
            exit 0
        ;;

        build)
            build
            exit 0
        ;;

        -*)
            echo "Unknown option '$1'"
            echo
            print_help
            exit 1
        ;;

        *)
            echo "Unknown command '$1'"
            echo
            print_help
            exit 1
        ;;
    esac
done
