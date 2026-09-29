**Ticket:** <!-- Hyperlink the issue, e.g. [SOS-1234](https://liquidweb.atlassian.net/browse/SOS-1234) — required, or state why there isn't one -->

## Why

<!-- What problem does this solve, or what requirement does it fulfill? One sentence is usually
enough if there's a ticket — it should contain the details. -->

## What

<!-- What changed? Bullet points of the approach taken. -->

### Blast radius

<!-- Which PHP versions, which EL releases (EL7, EL9, both), and which install path (individual
packages vs. `use_meta_php_package`)? Does this change what gets installed on already-provisioned
hosts? -->

### Deviations from spec

<!-- Bullet points: what, if anything, changed between the ticket's description and the final
implementation, and why. Delete this section if there's no spec to deviate from. -->

## Reading guide

<!-- Optional for a small change. For anything touching more than one file, map it for reviewers
before they read the diff. -->

| File | What to look at | Why |
|---|---|---|
| `` | … | … |

## Test plan

There is no CI on this repo — the reviewer has only what you write here.

**Verification performed:**
- [ ] `ansible-playbook --syntax-check` on a playbook using the role
- [ ] Applied against a real EL host (state which EL release and which `php_prefix`)
- [ ] `./php-meta-builder.sh make` on a GNU/Linux EL host, and inspected the generated
      `Requires:` line, if the builder or `config.yaml` changed
- [ ] `./php-meta-builder.sh build` produced an installable RPM, if the builder changed

**Manual verification steps:**
1. …

## Deploy notes

<!-- Delete this section if not needed. -->

**Repository changes:** <!-- do new/rebuilt meta RPMs need publishing before this role change lands? -->
**Rollout order:** <!-- any sequencing required (e.g. publish RPMs, then merge)? -->
**Rollback:** <!-- how to revert if this breaks provisioning in production? -->

## Checklist

- [ ] `bash -n nexcess-php-meta/php-meta-builder.sh` passes, if the builder changed
- [ ] `nexcess-php-meta/changelog.txt` has a new top entry, if the meta packages changed
- [ ] Package changes applied to both `defaults/main.yml` and `nexcess-php-meta/config.yaml`, or
      this PR says why only one applies
- [ ] Existing task-file style (`key=value` module syntax) followed, or converted deliberately
      and completely
- [ ] Docs updated (`README.md`/`AGENTS.md`) if this changes how the project is built, run, or used
- [ ] No secrets, tokens, or real customer/financial data included
- [ ] Includes an OpenSpec change under openspec/changes/, or the description has an sdd-exception: <reason> line near the top
