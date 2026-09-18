#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/../.." && pwd)
mkdocs_executable=${KAY_MKDOCS:-$(command -v mkdocs || true)}
python_executable=${KAY_PYTHON:-$(command -v python3 || true)}

if [[ -z "$mkdocs_executable" ]]; then
    echo "mkdocs is required; install requirements-docs.txt or set KAY_MKDOCS" >&2
    exit 2
fi
if [[ -z "$python_executable" ]]; then
    echo "python3 is required to serve the static preview or set KAY_PYTHON" >&2
    exit 2
fi

cd "$repo_root"
"$mkdocs_executable" build --strict
exec "$python_executable" -m http.server 8000 --bind 127.0.0.1 --directory "$repo_root/site"
