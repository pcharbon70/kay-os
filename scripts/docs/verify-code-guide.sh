#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/../.." && pwd)
coverage_file="$repo_root/docs/code-guide/coverage.tsv"
mkdocs_executable=${KAY_MKDOCS:-$(command -v mkdocs || true)}

fail() {
    printf 'code guide verification failed: %s\n' "$*" >&2
    exit 1
}

required_files=(
    AGENTS.md
    .github/pull_request_template.md
    docs/index.md
    docs/code-guide/index.md
    docs/code-guide/glossary.md
    docs/code-guide/module-guide-template.md
    docs/code-guide/m0-build-and-abi.md
    docs/code-guide/coverage.tsv
    mkdocs.yml
    requirements-docs.txt
    scripts/docs/build.sh
    scripts/docs/preview.sh
    scripts/docs/serve.sh
    scripts/docs/verify-code-guide.sh
)

for required_file in "${required_files[@]}"; do
    [[ -f "$repo_root/$required_file" ]] || fail "missing required file: $required_file"
done

required_headings=(
    '## Problem'
    '## Mental model'
    '## Important files'
    '## Execution flow'
    '## Data structures'
    '## Ownership and lifetime'
    '## Privilege and trust boundaries'
    '## Failure behavior'
    '## Tests and evidence'
    '## What this does not demonstrate'
    '## Language and OS concepts'
    '## Revision and maintenance'
)

mapfile -t module_guides < <(
    awk -F '\t' '!/^#/ && NF {print $2}' "$coverage_file" | sort -u
)
module_guides+=(docs/code-guide/module-guide-template.md)

for guide_path in "${module_guides[@]}"; do
    [[ -f "$repo_root/$guide_path" ]] || fail "coverage references missing guide: $guide_path"
    for heading in "${required_headings[@]}"; do
        grep -Fxq "$heading" "$repo_root/$guide_path" ||
            fail "$guide_path is missing required heading: $heading"
    done
done

declare -A coverage_count=()
while IFS=$'\t' read -r source_path guide_path role extra; do
    [[ -z "$source_path" || "$source_path" == \#* ]] && continue
    [[ -z "$extra" ]] || fail "coverage row has more than three fields: $source_path"
    [[ -n "$guide_path" && -n "$role" ]] || fail "incomplete coverage row: $source_path"
    [[ -f "$repo_root/$source_path" ]] || fail "coverage references missing source: $source_path"
    [[ -f "$repo_root/$guide_path" ]] || fail "coverage references missing guide: $guide_path"
    grep -Fq "\`$source_path\`" "$repo_root/$guide_path" ||
        fail "$guide_path does not name mapped source $source_path in backticks"
    coverage_count["$source_path"]=$(( ${coverage_count["$source_path"]:-0} + 1 ))
done < "$coverage_file"

while IFS= read -r source_path; do
    count=${coverage_count["$source_path"]:-0}
    [[ "$count" -eq 1 ]] || fail "$source_path must have exactly one coverage row; found $count"
done < <(
    cd "$repo_root"
    find src -type f \( -name '*.zig' -o -name '*.c' -o -name '*.h' -o -name '*.S' -o -name '*.s' \) -print | sort
)

pr_headings=(
    '### Why this change exists'
    '### Execution flow'
    '### Files to read, in order'
    '### Important data structures'
    '### New C/Zig/assembly concepts'
    '### Invariants and safety assumptions'
    '### Failure paths'
    '### Tests and what they prove'
    '### What this change does not prove'
)

for heading in "${pr_headings[@]}"; do
    grep -Fxq "$heading" "$repo_root/.github/pull_request_template.md" ||
        fail "pull request template is missing: $heading"
done

grep -Fq 'code-guide/m0-build-and-abi.md' "$repo_root/mkdocs.yml" ||
    fail "mkdocs navigation omits the M0 build and ABI guide"
grep -Fq 'docs/code-guide/coverage.tsv' "$repo_root/AGENTS.md" ||
    fail "AGENTS.md omits the coverage-manifest rule"

if [[ -z "$mkdocs_executable" ]]; then
    fail "mkdocs is required; install requirements-docs.txt or set KAY_MKDOCS"
fi

site_dir=$(mktemp -d /tmp/kay-code-companion-site.XXXXXX)
trap 'rm -rf -- "$site_dir"' EXIT

cd "$repo_root"
"$mkdocs_executable" build --strict --site-dir "$site_dir"

echo "Kay OS Code Companion verification passed"
