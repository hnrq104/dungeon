#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" != "client" && "${1:-}" != "server" && "${1:-}" != "link" ]]; then
  echo "Usage: $0 {client|server|link} [--debug|--release] [--] [arguments...]" >&2
  exit 1
fi
target="$1"
shift

# Default to debug builds; select the mode immediately after the target.
build_flags=(-debug -o:none)
case "${1:-}" in
  --debug)
    shift
    ;;
  --release)
    build_flags=(-o:speed)
    shift
    ;;
esac
if [[ "${1:-}" == "--" ]]; then
  shift
fi

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$project_root"

mkdir -p bin
if [[ "$target" == "link" ]]; then
  odin build src/server -out:bin/server "${build_flags[@]}"
  odin build src/client -out:bin/client "${build_flags[@]}"

  "$project_root/bin/server" "$@" &
  server_pid=$!
  cleanup() {
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
  }
  trap cleanup EXIT INT TERM

  set +e
  "$project_root/bin/client" "$@"
  client_status=$?
  set -e
  exit "$client_status"
else
  odin build "src/$target" "-out:bin/$target" "${build_flags[@]}"
  exec "$project_root/bin/$target" "$@"
fi
