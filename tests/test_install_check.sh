fake_tools() {
  mkdir -p tools
  for t in "$@"; do
    printf '#!/bin/sh\nexit 0\n' > "tools/$t"
    chmod +x "tools/$t"
  done
}

test_install_check_passes_with_all_tools() {
  sandbox
  fake_tools node lhci jq bc google-chrome
  env PATH="$PWD/tools:/bin" bash "$REPO/plugin/scripts/install-check.sh" >/dev/null
}

test_install_check_requires_bc() {
  sandbox
  fake_tools node lhci jq google-chrome
  assert_exit 1 env PATH="$PWD/tools:/bin" bash "$REPO/plugin/scripts/install-check.sh"
}
