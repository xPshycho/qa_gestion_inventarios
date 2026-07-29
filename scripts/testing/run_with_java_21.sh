#!/usr/bin/env bash

set -euo pipefail

java_major_version() {
  "$1/bin/java" -version 2>&1 \
    | awk -F'"' 'NR == 1 {split($2, version, "."); print version[1]}'
}

declare -a candidates=()
if [[ -n "${JAVA_HOME:-}" ]]; then
  candidates+=("$JAVA_HOME")
fi
candidates+=(
  /usr/lib/jvm/java-21-openjdk-amd64
  /usr/lib/jvm/java-1.21.0-openjdk-amd64
)

for candidate in "${candidates[@]}"; do
  if [[ -x "$candidate/bin/java" ]] \
    && [[ "$(java_major_version "$candidate")" == "21" ]]; then
    export JAVA_HOME="$candidate"
    export PATH="$JAVA_HOME/bin:$PATH"
    exec "$@"
  fi
done

printf 'Java 21 is required, but no supported JDK 21 installation was found.\n' >&2
exit 1
