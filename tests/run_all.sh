#!/usr/bin/env bash
set -euo pipefail
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "$TESTS_DIR/_common.sh"
SKIP_TESTS=(); while [[ $# -gt 0 ]]; do case "$1" in --skip) shift; SKIP_TESTS+=("$1"); shift ;; *) echo "Unknown: $1"; exit 1 ;; esac; done
should_skip() { local n="$1"; for s in "${SKIP_TESTS[@]+"${SKIP_TESTS[@]}"}"; do [[ "$n" == "$s" ]] && return 0; done; return 1; }

echo ""; echo "${BOLD}=========================================${RESET}"; echo "${BOLD}  ssh-lab — Automated Test Suite${RESET}"; echo "${BOLD}=========================================${RESET}"; echo ""
log_info "Server port: $SERVER_PORT"; log_info "Client port: $CLIENT_PORT"
assert "Server VM reachable" ssh_server "echo ok"; assert "Client VM reachable" ssh_client "echo ok"
s_ci=$(ssh_server "cloud-init status 2>/dev/null || echo done") || true; assert_contains "Server cloud-init done" "$s_ci" "done"
c_ci=$(ssh_client "cloud-init status 2>/dev/null || echo done") || true; assert_contains "Client cloud-init done" "$c_ci" "done"
# Backup sshd_config if not already backed up
ssh_server "test -f /etc/ssh/sshd_config.bak || sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak" >/dev/null 2>&1
cleanup_ssh

TOTAL_PASS=0; TOTAL_FAIL=0; TESTS_RUN=0; TESTS_SKIPPED=0; FAILED_EXERCISES=()
run_test() { local n="$1"; local f=($TESTS_DIR/test_${n}_*.sh); [[ ! -f "${f[0]}" ]] && return; should_skip "$n" && { log_info "Skipping $n"; TESTS_SKIPPED=$((TESTS_SKIPPED+1)); return; }; cleanup_ssh >/dev/null 2>&1; local e=0; bash "${f[0]}" || e=$?; TESTS_RUN=$((TESTS_RUN+1)); if [[ "$e" -ne 0 ]]; then TOTAL_FAIL=$((TOTAL_FAIL+1)); FAILED_EXERCISES+=("$n"); else TOTAL_PASS=$((TOTAL_PASS+1)); fi; }

run_test "01"; run_test "02"; run_test "03"; run_test "04"; run_test "05"; run_test "06"

echo ""; echo "${BOLD}=========================================${RESET}"; echo "${BOLD}  Final Report${RESET}"; echo "${BOLD}=========================================${RESET}"; echo ""
echo "  Exercises run:     $TESTS_RUN"; echo "  Exercises passed:  $TOTAL_PASS"; echo "  Exercises failed:  $TOTAL_FAIL"; echo "  Exercises skipped: $TESTS_SKIPPED"
if [[ "$TOTAL_FAIL" -gt 0 ]]; then printf "\n${RED}${BOLD}  FAILED exercises: %s${RESET}\n" "${FAILED_EXERCISES[*]}"; exit 1; else printf "\n${GREEN}${BOLD}  All exercises passed!${RESET}\n"; exit 0; fi
