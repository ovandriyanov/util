# Workstation Base Playbook

The playbook provisions the connecting user's Linux home and installs system
build dependencies with privilege escalation. It supports Debian, Red Hat, and
Arch Linux families on x86_64 and aarch64. Ansible Core 2.17 requires Python
3.7 through 3.12 on managed hosts.

## Local Machine

On Ubuntu, install the local prerequisites after cloning the repository:

```sh
./ansible/bootstrap-ubuntu.sh
```

Then validate and apply the playbook:

```sh
.venv/bin/ansible-lint
.venv/bin/ansible-playbook \
  -i ansible/inventory/localhost.yml \
  --ask-become-pass \
  ansible/site.yml
```

## Remote Machine

Ensure the target has Python installed, then run the same playbook from a
controller with SSH agent forwarding enabled:

```sh
.venv/bin/ansible-playbook \
  -i 'hostname,' \
  ansible/site.yml
```

Use `--ask-become-pass` only when the target does not have passwordless sudo.
GitHub authentication is performed over SSH as the connecting user.
Only forward the agent to a trusted target, and scope forwarding to that host.
An existing workstation checkout is not updated or switched automatically;
update it explicitly before applying when you want newer base dotfiles.
Hosts with custom package priorities can provide `package`, `pin`, and
`priority` entries through `workstation_apt_preferences` in their private
inventory.

## Private Extension

A private entry point can import this playbook and add another play:

```yaml
---
- import_playbook: "{{ lookup('env', 'HOME') }}/github/ovandriyanov/workstation/ansible/site.yml"

- name: Apply private configuration
  hosts: all
  roles:
    - private_workstation
```

The base chezmoi invocation uses `~/.config/chezmoi/base.toml` and its own
cache and persistent state. The private role should use separate paths and run
a second `chezmoi apply` after this playbook finishes.

## Managed Neovim Build

The writable fork is cloned to `~/github/ovandriyanov/neovim`. Ansible does not
reset or check out an existing clone. It fetches refs, creates a detached build
worktree for the pinned commit under `~/.cache/workstation/neovim`, installs the
result under `~/.local/opt/neovim`, and updates `~/bin/nvim`.

## Vim And Neovim Configuration

The base chezmoi source manages `~/.vimrc`, `~/.config/nvim`, and the personal
files under `~/.vim`. Ansible pins Vundle itself and asks Vundle and vim-plug to
install missing plugins; it does not update existing plugin checkouts.

CodeDiff and DBExt remain local-only. Their existing checkouts and DBExt's local
configuration are used when present, but are not installed or modified by this
playbook. Language servers are also enabled only when their executables are
available.
