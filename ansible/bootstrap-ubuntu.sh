#!/bin/sh
set -eu

. /etc/os-release

if [ "${ID:-}" != ubuntu ]; then
    printf '%s\n' 'This bootstrap script supports Ubuntu only.' >&2
    exit 1
fi

if [ "$(id -u)" -eq 0 ]; then
    sudo=
else
    command -v sudo >/dev/null 2>&1 || {
        printf '%s\n' 'sudo is required when running as a non-root user.' >&2
        exit 1
    }
    sudo=sudo
fi

$sudo apt-get update
$sudo apt-get install -y \
    ca-certificates \
    git \
    openssh-client \
    python3-venv

ansible_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(dirname "$ansible_dir")
venv_dir="$repo_dir/.venv"

python3 -m venv "$venv_dir"
"$venv_dir/bin/python" -m pip install --upgrade pip
"$venv_dir/bin/python" -m pip install \
    ansible-core==2.17.14 \
    ansible-lint==24.12.2
"$venv_dir/bin/ansible-galaxy" collection install \
    --requirements-file "$ansible_dir/requirements.yml"
