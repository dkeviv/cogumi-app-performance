REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURES="$REPO/tests/fixtures"
export REPO FIXTURES

sandbox() {
  SANDBOX="$(mktemp -d)"
  cd "$SANDBOX" || exit 1
  export PATH="$REPO/tests/bin:$PATH"
  export FAKE_LHCI_FIXTURES="$FIXTURES"
}

assert_eq() {
  if [ "$1" != "$2" ]; then
    echo "  assert_eq failed: $3: expected '$2', got '$1'"
    exit 1
  fi
}

assert_contains() {
  case "$1" in
    *"$2"*) ;;
    *) echo "  assert_contains failed: $3: '$2' not found"; exit 1 ;;
  esac
}

assert_not_contains() {
  case "$1" in
    *"$2"*) echo "  assert_not_contains failed: $3: '$2' found"; exit 1 ;;
  esac
}

assert_exit() {
  local want="$1"; shift
  set +e
  "$@" >/dev/null 2>&1
  local got=$?
  set -e
  if [ "$got" != "$want" ]; then
    echo "  assert_exit failed: '$*' exited $got, expected $want"
    exit 1
  fi
}
