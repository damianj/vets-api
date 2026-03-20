#!/usr/bin/env bash

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

# Broad runtime/spec boundary audit.
# - Errors: runtime files that reference spec paths without a test-env guard.
# - Warnings: runtime files that reference spec paths but are test-gated.

errors=()
warnings=()
files_to_check=()

collect_files() {
  if (($# > 0)); then
    files_to_check=("$@")
    return
  fi

  if [[ -n "${CHANGED_FILES_FILE:-}" && -f "${CHANGED_FILES_FILE}" ]]; then
    mapfile -t files_to_check < "$CHANGED_FILES_FILE"
    return
  fi

  # Fallback for local/manual runs.
  while IFS= read -r file; do
    files_to_check+=("$file")
  done < <(git ls-files)
}

is_runtime_file() {
  local file="$1"

  # Match top-level and engine runtime directories (arbitrary depth).
  if ! [[ "$file" =~ ^(app|config|lib)/ || "$file" =~ ^modules/[^/]+/(app|config|lib)/ ]]; then
    return 1
  fi

  # Exclude spec/test trees and generator templates.
  if [[ "$file" =~ ^(spec|test)/ || "$file" =~ ^modules/[^/]+/spec/ || "$file" =~ ^lib/generators/ ]]; then
    return 1
  fi

  # Limit to executable/config source files where runtime dependencies are meaningful.
  case "$file" in
    *.rb|*.rake|*.erb|*.yml|*.yaml|Dockerfile|docker-compose*.yml)
      ;;
    *)
      return 1
      ;;
  esac

  return 0
}

collect_files "$@"

if ((${#files_to_check[@]} == 0)); then
  echo "No files to check; runtime/spec dependency boundary check passed"
  exit 0
fi

scanned_count=0

for file in "${files_to_check[@]}"; do
  # Ignore deleted/nonexistent entries that can appear in diffs.
  if [[ ! -f "$file" ]]; then
    continue
  fi

  if ! is_runtime_file "$file"; then
    continue
  fi

  ((scanned_count += 1))

  has_test_guard=false
  if grep -Eq 'Rails\.env\.test\?|Dir\.exist\?' "$file"; then
    has_test_guard=true
  fi

  # Explicit FactoryBot definitions should not be in runtime files.
  if grep -Eq 'FactoryBot\.(define|modify)\b' "$file"; then
    errors+=("$file: defines/modifies factories in runtime code")
  fi

  # Dependency-like references to spec paths in runtime files are suspicious.
  if grep -Eq '(require|require_relative|load)[[:space:]]+["'"'"'][^"'"'"']*spec/|File\.(expand_path|join)\([^)]*spec/|Dir\[[^]]*spec/|autoload_paths[^\n]*spec/|eager_load_paths[^\n]*spec/' "$file"; then
    if [[ "$has_test_guard" == true ]]; then
      warnings+=("$file: has test-gated dependency-style reference to spec paths")
    else
      errors+=("$file: has dependency-style reference to spec paths without Rails.env.test? guard")
    fi
  fi

  # Keep explicit checks readable in output for common patterns.
  if grep -Eq 'FactoryBot\.definition_file_paths\s*<<' "$file"; then
    if [[ "$has_test_guard" == true ]]; then
      warnings+=("$file: appends FactoryBot definition_file_paths (test-gated)")
    else
      errors+=("$file: appends FactoryBot definition_file_paths without Rails.env.test? guard")
    fi
  fi
done

if ((scanned_count == 0)); then
  echo "No runtime files matched in selected file set; runtime/spec dependency boundary check passed"
  exit 0
fi

if ((${#warnings[@]} > 0)); then
  echo "Runtime/spec dependency boundary warnings:"
  for warning in "${warnings[@]}"; do
    echo "- $warning"
  done
fi

if ((${#errors[@]} > 0)); then
  echo "Runtime/spec dependency boundary check failed:" >&2
  for error in "${errors[@]}"; do
    echo "- $error" >&2
  done
  exit 1
fi

echo "Runtime/spec dependency boundary check passed (scanned ${scanned_count} runtime files)"
