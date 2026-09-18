#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/../.." && pwd)
mkdocs_executable=${KAY_MKDOCS:-$(command -v mkdocs || true)}

if [[ -z "$mkdocs_executable" ]]; then
    echo "mkdocs is required; install requirements-docs.txt or set KAY_MKDOCS" >&2
    exit 2
fi

cd "$repo_root"
"$mkdocs_executable" build --strict
