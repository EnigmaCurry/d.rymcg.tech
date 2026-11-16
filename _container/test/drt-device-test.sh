#!/usr/bin/env bash
## drt-device-test.sh - local test of drt device mode. No cloud, no real server.
##
## Starts drt devices on a throwaway context and checks the device
## lifecycle, request verbs, the MCP server, saving to the SOPS config,
## locking, and git commit/push. Everything runs under a scratch HOME,
## so your real ~/.config/d.rymcg.tech and ssh-agent are never used.
##
## The context's SSH host is fake (devtest.invalid), so nothing that
## needs a real Docker server (install, status of containers) is tested.
##
## Usage: _container/test/drt-device-test.sh [--image IMAGE | --full-build] [--keep]
##
##   (default)      Layer this working tree's _container/ and _scripts/ over
##                  DRT_TEST_BASE (default localhost/d-rymcg-tech:latest). Fast.
##   --full-build   Build the image from _container/Dockerfile (slow).
##   --image IMAGE  Test IMAGE as-is.
##   --keep         Keep the scratch directory and test image afterwards.
##
## Needs: bash, podman, git, script (util-linux). Exit code 0 = all passed.

# shellcheck disable=SC2319  # "[[ test ]]; verdict $? ..." checks the test on purpose
set -uo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
DRT=("bash" "${REPO}/_container/drt")
CTX=drttest
CONTAINER="drt-${CTX}"
TEST_IMAGE=localhost/drt-device-test:latest
BASE_IMAGE="${DRT_TEST_BASE:-localhost/d-rymcg-tech:latest}"
MODE=overlay
KEEP=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --image) MODE=image; TEST_IMAGE="$2"; shift 2 ;;
        --full-build) MODE=full; shift ;;
        --keep) KEEP=true; shift ;;
        -h|--help) sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^## \{0,1\}//'; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

for cmd in podman git script; do
    command -v "${cmd}" >/dev/null || { echo "Missing dependency: ${cmd}" >&2; exit 1; }
done
if podman container exists "${CONTAINER}"; then
    echo "A container named ${CONTAINER} already exists; remove it first." >&2
    exit 1
fi

T=$(mktemp -d -t drt-device-test.XXXXXX)
H="${T}/home"
CONFIG_BASE="${H}/.config/d.rymcg.tech"
SOPS_FILE="${CONFIG_BASE}/config/${CTX}.sops.env"
AGE_KEY="${CONFIG_BASE}/keys/sops/${CTX}.key"
REMOTE="${T}/remote.git"
SERVE_LOG="${T}/serve.log"

## podman keeps using the real user's storage and config while HOME points
## at the scratch dir.
export XDG_DATA_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export HOME="${H}"
export DRT_IMAGE="${TEST_IMAGE}"
export SSH_HOST=devtest.invalid
unset SSH_AUTH_SOCK DRT_NO_GIT DRT_GIT_PUSH DOCKER_CONTEXT DRT_CONTEXT

# shellcheck disable=SC2329  # called by the EXIT trap
cleanup() {
    podman rm -f -t 0 "${CONTAINER}" >/dev/null 2>&1 || true
    if [[ "${KEEP}" == true ]]; then
        echo "Kept: ${T}  (image: ${TEST_IMAGE})"
    else
        rm -rf "${T}"
        [[ "${MODE}" == overlay ]] && podman rmi -f "${TEST_IMAGE}" >/dev/null 2>&1
    fi
}
trap cleanup EXIT

PASS=0 FAIL=0
pass() { PASS=$((PASS + 1)); printf '  \e[32mPASS\e[0m %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  \e[31mFAIL\e[0m %s\n' "$1"; [[ -n "${2:-}" ]] && printf '%s\n' "$2" | sed 's/^/       | /' | head -20; }
section() { printf '\n## %s\n' "$1"; }
## verdict RC NAME [DETAIL]: pass NAME if RC (pass $?) is 0. RC is passed explicitly
## because a $(...) in DETAIL would reset $? before verdict could read it.
verdict() { if [[ "$1" -eq 0 ]]; then pass "$2"; else fail "$2" "${3:-}"; fi; }
## check NAME CMD...: pass if CMD exits 0
check() { local name="$1"; shift; local out; if out=$("$@" 2>&1); then pass "${name}"; else fail "${name}" "${out}"; fi; }
## check_rc NAME RC CMD...: pass if CMD exits with RC
check_rc() {
    local name="$1" want="$2"; shift 2; local out rc=0
    out=$("$@" 2>&1) || rc=$?
    if [[ ${rc} -eq ${want} ]]; then pass "${name}"; else fail "${name} (exit ${rc}, want ${want})" "${out}"; fi
}

## Run a command in the test image with the scratch dir mounted at /t
in_image() { podman run --rm --net=none --entrypoint "" -v "${T}:/t:z" "${TEST_IMAGE}" "$@"; }
## Decrypted SOPS config
decrypted() {
    in_image env SOPS_AGE_KEY_FILE="/t/home/.config/d.rymcg.tech/keys/sops/${CTX}.key" \
        sops decrypt --input-type dotenv --output-type dotenv \
        "/t/home/.config/d.rymcg.tech/config/${CTX}.sops.env"
}
drt_() { "${DRT[@]}" "$@" </dev/null; }

## Start a device in the background (drt --serve wants a terminal).
## DRT_NO_GIT skips the pull prompt at startup; --save, --lock and MCP
## still commit and push from their own processes.
serve() {
    : > "${SERVE_LOG}"
    DRT_NO_GIT=true script -qfec "$(printf '%q ' "${DRT[@]}" --image "${TEST_IMAGE}" --serve "${SOPS_FILE}" --age-key "${AGE_KEY}" "$@")" \
        "${SERVE_LOG}" >/dev/null 2>&1 &
    local pid=$! _
    for _ in $(seq 1 120); do
        grep -q "UNLOCKED" "${SERVE_LOG}" 2>/dev/null && return 0
        kill -0 "${pid}" 2>/dev/null || break
        sleep 1
    done
    echo "device did not unlock; log:" >&2
    tr -d '\r' < "${SERVE_LOG}" | tail -30 >&2
    return 1
}
## Wait until the device container is gone
wait_gone() {
    local _
    for _ in $(seq 1 "${1:-60}"); do
        podman container exists "${CONTAINER}" || return 0
        sleep 1
    done
    return 1
}
mcp() { printf '%s\n' "$@" | "${DRT[@]}" --mcp "${CTX}" 2>/dev/null; }
remote_commits() { git -C "${REMOTE}" rev-list --count HEAD 2>/dev/null || echo 0; }

###############################################################################
section "Image (${MODE})"
case "${MODE}" in
    overlay)
        podman image exists "${BASE_IMAGE}" || { echo "Base image ${BASE_IMAGE} not found (set DRT_TEST_BASE, or use --full-build)" >&2; exit 1; }
        mkdir -p "${T}/ctx"
        cp -a "${REPO}/_container" "${REPO}/_scripts" "${T}/ctx/"
        cat > "${T}/ctx/Containerfile" <<'EOF'
ARG BASE
FROM ${BASE}
ARG R=/home/user/git/vendor/enigmacurry/d.rymcg.tech
COPY --chown=1000:1000 _container ${R}/_container
COPY --chown=1000:1000 _scripts ${R}/_scripts
COPY --chown=1000:1000 _container/bashrc /home/user/.bashrc
RUN cd ${R} \
 && install -m 755 _container/drt /opt/drt \
 && install -m 755 _container/drt-device /usr/local/bin/drt-device \
 && mkdir -p /usr/local/lib/drt \
 && install -m 644 _container/drt-save.sh _container/drt_request.py _container/drt_mcp.py /usr/local/lib/drt/ \
 && install -m 755 _container/entrypoint.sh /entrypoint.sh
EOF
        check "overlay image builds on ${BASE_IMAGE}" \
            podman build -q --build-arg BASE="${BASE_IMAGE}" -t "${TEST_IMAGE}" -f "${T}/ctx/Containerfile" "${T}/ctx"
        ;;
    full)
        check "image builds from _container/Dockerfile" \
            podman build -q -t "${TEST_IMAGE}" -f "${REPO}/_container/Dockerfile" "${REPO}"
        ;;
    image)
        check "image ${TEST_IMAGE} exists" podman image exists "${TEST_IMAGE}" ;;
esac
podman image exists "${TEST_IMAGE}" || { echo "No test image; stopping." >&2; exit 1; }

###############################################################################
section "Fixture"
mkdir -p "${CONFIG_BASE}/config" "${CONFIG_BASE}/keys/sops"
in_image age-keygen -o "/t/home/.config/d.rymcg.tech/keys/sops/${CTX}.key" 2>/dev/null
chmod 600 "${AGE_KEY}"
PUB=$(in_image age-keygen -y "/t/home/.config/d.rymcg.tech/keys/sops/${CTX}.key")
## What each section exercises:
##   ## OpenBao        a section export-env doesn't produce: kept on save
##   traefik          DOCKER_CONTEXT has no TRAEFIK_ prefix (restore-env routing)
##   ## ssh keys       a dotted key, duplicated, as older saves left it
cat > "${T}/plain.env" <<EOF
## OpenBao
KEEP_ME=hello

## .env_${CTX}
ROOT_DOMAIN=${CTX}.example

## traefik/.env_${CTX}_default
TRAEFIK_IMAGE=traefik:drt-device-test
DOCKER_CONTEXT=${CTX}

## ssh keys
__ssh_key__known_hosts.old=ZHVtbXkK
__ssh_key__known_hosts.old=ZHVtbXkK
EOF
if in_image sops encrypt --input-type dotenv --output-type dotenv --filename-override export.env \
        --age "${PUB}" /t/plain.env > "${SOPS_FILE}" && [[ -s "${SOPS_FILE}" ]]; then
    pass "encrypt fixture config"
else
    fail "encrypt fixture config"; exit 1
fi

git init -q --bare -b master "${REMOTE}"
git -C "${CONFIG_BASE}" init -q -b master
git -C "${CONFIG_BASE}" config user.email drt-device-test@localhost
git -C "${CONFIG_BASE}" config user.name drt-device-test
git -C "${CONFIG_BASE}" remote add origin "${REMOTE}"
printf 'net-mode\nkeys/*\ngumdrop-presets/*\ne2e/\n' > "${CONFIG_BASE}/.gitignore"
git -C "${CONFIG_BASE}" add -A && git -C "${CONFIG_BASE}" commit -q -m init
check "config repo pushes to local remote" git -C "${CONFIG_BASE}" push -q -u origin master

###############################################################################
section "Before unlock"
check_rc "--exec with no device exits 3" 3 drt_ --exec "${CTX}" -- true
check_rc "--status with no device exits 3" 3 drt_ --status "${CTX}"
check_rc "--serve rejects a bad duration" 1 drt_ --serve "${SOPS_FILE}" --lease 5x

###############################################################################
section "Unlock"
if ! serve --lease 1h --idle 0; then
    fail "device unlocks"
    echo; echo "PASS ${PASS}  FAIL ${FAIL}"; exit 1
fi
pass "device unlocks"
check "--status reports unlocked" bash -c "$(printf '%q ' "${DRT[@]}") --status ${CTX} </dev/null | grep -q 'lease remaining'"
check "--exec runs a command" bash -c "[[ \$($(printf '%q ' "${DRT[@]}") --exec ${CTX} -- echo hi </dev/null) == hi ]]"
check_rc "--exec passes the exit code" 7 drt_ --exec "${CTX}" -- bash -c 'exit 7'
check "--exec maps d to d.rymcg.tech" bash -c "$(printf '%q ' "${DRT[@]}") --exec ${CTX} -- d list </dev/null | grep -q '^whoami '"
check "restore put DOCKER_CONTEXT in traefik's config" \
    bash -c "$(printf '%q ' "${DRT[@]}") --exec ${CTX} -- request get traefik DOCKER_CONTEXT </dev/null | grep -q '\"stdout\": \"${CTX}'"

###############################################################################
section "Request verbs"
REQ=(drt_ --exec "${CTX}" -- request)
check "request list" bash -c "$(printf '%q ' "${DRT[@]}") --exec ${CTX} -- request list </dev/null | grep -q '\"whoami\"'"
check "request config-dist whoami" "${REQ[@]}" config-dist whoami
check_rc "config-dist over an existing config is refused" 64 "${REQ[@]}" config-dist whoami
check "request reconfigure whoami" "${REQ[@]}" reconfigure whoami WHOAMI_TRAEFIK_HOST=whoami.${CTX}.example
check_rc "reconfigure of an unknown var is refused" 64 "${REQ[@]}" reconfigure whoami WHOAMI_NOT_A_VAR=x
check_rc "lifecycle verb on an unconfigured project is refused" 64 "${REQ[@]}" install datetime
check_rc "unknown verb is refused" 64 "${REQ[@]}" frobnicate whoami
check_rc "unknown project is refused" 64 "${REQ[@]}" get no-such-project VAR
check "request get returns the new value" \
    bash -c "$(printf '%q ' "${DRT[@]}") --exec ${CTX} -- request get whoami WHOAMI_TRAEFIK_HOST </dev/null | grep -q 'whoami.${CTX}.example'"
## make would expand $ in values; reconfigure and get must not go through it (#782)
check "reconfigure stores \$ verbatim" "${REQ[@]}" reconfigure whoami 'WHOAMI_HTTP_AUTH=u:$$apr1$$s$$h'
check "request get returns \$ verbatim" \
    bash -c "$(printf '%q ' "${DRT[@]}") --exec ${CTX} -- request get whoami WHOAMI_HTTP_AUTH </dev/null | grep -qF 'u:\$\$apr1\$\$s\$\$h'"
check_rc "reconfigure refuses a newline in a value" 64 "${REQ[@]}" reconfigure whoami $'WHOAMI_HTTP_AUTH=a\nB=1'
check "reset WHOAMI_HTTP_AUTH" "${REQ[@]}" reconfigure whoami WHOAMI_HTTP_AUTH=
check "config-render includes Traefik labels (fresh session)" \
    bash -c "$(printf '%q ' "${DRT[@]}") --exec ${CTX} -- request config-render whoami </dev/null | grep -q 'traefik.http.routers'"

###############################################################################
section "Diff and save"
DIFF=$(drt_ --exec "${CTX}" -- drt-device diff 2>&1)
if grep -q '~ WHOAMI_TRAEFIK_HOST\|+ WHOAMI_TRAEFIK_HOST' <<< "${DIFF}"; then pass "diff lists the changed key"; else fail "diff lists the changed key" "${DIFF}"; fi
if grep -q "whoami.${CTX}.example" <<< "${DIFF}"; then fail "diff shows no values" "${DIFF}"; else pass "diff shows no values"; fi
BEFORE=$(remote_commits)
check "--save" drt_ --save "${CTX}"
PLAIN=$(decrypted 2>&1)
grep -qx "WHOAMI_TRAEFIK_HOST=whoami.${CTX}.example" <<< "${PLAIN}"; verdict $? "saved value is in the SOPS config"
grep -qx "KEEP_ME=hello" <<< "${PLAIN}" && grep -qx "## OpenBao" <<< "${PLAIN}"; verdict $? "save keeps sections export-env doesn't produce" "${PLAIN}"
grep -qx "DOCKER_CONTEXT=${CTX}" <<< "${PLAIN}"; verdict $? "save keeps traefik's DOCKER_CONTEXT" "$(grep '^DOCKER_CONTEXT=' <<< "${PLAIN}")"
n=$(grep -c '^__ssh_key__known_hosts.old=' <<< "${PLAIN}")
[[ ${n} -eq 1 ]]; verdict $? "save writes a dotted key once (was 2)" "save writes a dotted key once (found ${n})"
grep -qx "ROOT_DOMAIN=${CTX}.example" <<< "${PLAIN}"; verdict $? "root config survives"
[[ $(remote_commits) -gt ${BEFORE} ]]; verdict $? "save commits and pushes with no terminal"
check "nothing unsaved after save" bash -c "$(printf '%q ' "${DRT[@]}") --exec ${CTX} -- drt-device diff </dev/null | grep -q 'No unsaved changes'"

###############################################################################
section "MCP"
INIT='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18"}}'
OUT=$(mcp "${INIT}" '{"jsonrpc":"2.0","method":"notifications/initialized"}' '{"jsonrpc":"2.0","id":2,"method":"tools/list"}')
grep -q '"id": 1, "result": {"protocolVersion"' <<< "${OUT}"; verdict $? "initialize" "${OUT}"
n=$(grep -o '"inputSchema"' <<< "${OUT}" | wc -l)
[[ ${n} -eq 21 ]]; verdict $? "tools/list has 21 tools" "tools/list has 21 tools (found ${n})"
OUT=$(mcp '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"get_config","arguments":{"project":"whoami","var":"WHOAMI_TRAEFIK_HOST"}}}')
grep -q "whoami.${CTX}.example" <<< "${OUT}" && grep -q '"isError": false' <<< "${OUT}"; verdict $? "tools/call get_config" "${OUT}"
OUT=$(mcp '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"reconfigure","arguments":{"project":"whoami","vars":{"WHOAMI_NOPE":"x"}}}}')
grep -q '"isError": true' <<< "${OUT}"; verdict $? "tools/call refusal is an error" "${OUT}"
OUT=$(mcp '{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"reconfigure","arguments":{"project":"whoami","vars":{"WHOAMI_TRAEFIK_HOST":"mcp.'"${CTX}"'.example"}}}}')
grep -q '"isError": false' <<< "${OUT}"; verdict $? "tools/call reconfigure" "${OUT}"
BEFORE=$(remote_commits)
OUT=$(mcp '{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"save","arguments":{}}}')
grep -q 'WHOAMI_TRAEFIK_HOST' <<< "${OUT}"; verdict $? "tools/call save" "${OUT}"
[[ $(remote_commits) -gt ${BEFORE} ]]; verdict $? "MCP save commits and pushes"
OUT=$(mcp '{"jsonrpc":"2.0","id":7,"method":"no/such"}')
grep -q '"code": -32601' <<< "${OUT}"; verdict $? "unknown method is -32601" "${OUT}"

###############################################################################
section "Lock"
drt_ --exec "${CTX}" -- request reconfigure whoami WHOAMI_TRAEFIK_HOST=lock.${CTX}.example >/dev/null 2>&1
check "--lock" drt_ --lock "${CTX}"
wait_gone 30; verdict $? "device is gone after --lock"
decrypted 2>/dev/null | grep -qx "WHOAMI_TRAEFIK_HOST=lock.${CTX}.example"; verdict $? "--lock saves unsaved changes"
OUT=$(mcp "${INIT}" '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"status","arguments":{}}}')
grep -q '"id": 1, "result"' <<< "${OUT}" && grep -q 'locked' <<< "${OUT}"; verdict $? "MCP answers 'locked' while the device is locked" "${OUT}"

section "Idle timeout"
if serve --lease 0 --idle 5s; then
    drt_ --exec "${CTX}" -- request reconfigure whoami WHOAMI_TRAEFIK_HOST=idle.${CTX}.example >/dev/null 2>&1
    wait_gone 40; verdict $? "device locks after the idle timeout"
    decrypted 2>/dev/null | grep -qx "WHOAMI_TRAEFIK_HOST=idle.${CTX}.example"; verdict $? "idle lock saves"
else
    fail "device unlocks (idle)"
fi

section "Lease"
if serve --lease 8s --idle 0; then
    wait_gone 40; verdict $? "device locks when the lease ends"
    tr -d '\r' < "${SERVE_LOG}" | grep -qi "lease"; verdict $? "console says why it locked" "$(tr -d '\r' < "${SERVE_LOG}" | tail -5)"
else
    fail "device unlocks (lease)"
fi

section "SIGTERM"
if serve --lease 1h --idle 0; then
    OUT=$(mcp '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"device_status","arguments":{}}}')
    grep -q 'lease remaining' <<< "${OUT}"; verdict $? "MCP picks the device back up after a re-serve" "${OUT}"
    drt_ --exec "${CTX}" -- request reconfigure whoami WHOAMI_TRAEFIK_HOST=sigterm.${CTX}.example >/dev/null 2>&1
    podman stop -t 30 "${CONTAINER}" >/dev/null 2>&1
    wait_gone 30
    decrypted 2>/dev/null | grep -qx "WHOAMI_TRAEFIK_HOST=sigterm.${CTX}.example"; verdict $? "SIGTERM saves before stopping"
else
    fail "device unlocks (SIGTERM)"
fi

###############################################################################
echo
if [[ ${FAIL} -eq 0 ]]; then
    printf '\e[32mAll %d checks passed.\e[0m\n' "${PASS}"
    exit 0
fi
printf '\e[31m%d of %d checks failed.\e[0m\n' "${FAIL}" "$((PASS + FAIL))"
exit 1
