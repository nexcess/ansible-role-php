# Contributing

This repo holds the `nexcess.php` Ansible role and the `nexcess-php-meta` RPM builder that
supports it.

## Development setup

There is no build step and no test harness. See [AGENTS.md](AGENTS.md#commands) for the role's
commands and [nexcess-php-meta/AGENTS.md](nexcess-php-meta/AGENTS.md#commands) for the builder's
— not repeated here.

Read the Conventions section of whichever component you're touching before you start. Both list
constraints that aren't obvious from the code: which PHP versions each install path supports,
which variables the role expects from inventory, and how the builder's config parser behaves.

## Opening a PR

Use this repo's [pull request template](.github/PULL_REQUEST_TEMPLATE.md). Link the Jira ticket
and describe how you verified the change — there's no CI, so the test plan is the only evidence
a reviewer gets.

Changes go to [nexcess/ansible-role-php](https://github.com/nexcess/ansible-role-php) on
`master`.

## Before you open a PR

- [ ] Playbook using the role passes `ansible-playbook --syntax-check`
- [ ] Change applied against a real EL7 or EL9 host, or explained why that wasn't possible
- [ ] `bash -n nexcess-php-meta/php-meta-builder.sh` passes, if the builder changed
- [ ] Builder run on a GNU/Linux EL host (it produces nothing on macOS), if the builder or
      `config.yaml` changed
- [ ] `nexcess-php-meta/changelog.txt` has a new top entry, if the meta packages changed
- [ ] Package changes applied to both `defaults/main.yml` and `nexcess-php-meta/config.yaml`,
      or the PR says why only one applies
- [ ] Docs (`README.md`/`AGENTS.md`) updated if this changes how the role is used or built

## Spec-driven development

This repo uses [OpenSpec](https://github.com/Fission-AI/OpenSpec) for spec-driven
development. PRs need an OpenSpec change under `openspec/changes/`, or an
`sdd-exception: <reason>` line in the PR description.
