#!/usr/bin/env bash
# Prints "true" when the current change set touches any of the given paths.
#
# This exists so path filtering can live on the job (`if:`) instead of on the
# workflow trigger (`paths:`). The difference matters once a branch requires
# status checks: a workflow skipped by a `paths:` filter never reports a status
# at all, and a required check that never reports blocks the pull request
# forever. A job skipped by an `if:` condition reports "skipped", which counts
# as success.
#
# Arguments are git pathspecs. Directory names match everything beneath them,
# so `android` covers `android/src/**`.
#
# BASE_SHA must be set to the commit to compare against.
set -euo pipefail

if [ "$#" -eq 0 ]; then
  echo "usage: $0 <pathspec>..." >&2
  exit 2
fi

base="${BASE_SHA:-}"

# A new branch, a force push or a shallow clone can leave no usable base.
# Erring towards running the job is the safe direction.
if [ -z "$base" ] ||
  [ "$base" = "0000000000000000000000000000000000000000" ] ||
  ! git cat-file -e "${base}^{commit}" 2>/dev/null; then
  echo "true"
  exit 0
fi

if git diff --name-only "$base" HEAD -- "$@" | grep -q .; then
  echo "true"
else
  echo "false"
fi
