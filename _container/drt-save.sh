## drt-save.sh - write session state back to the SOPS config.
##
## Sourced by ~/.bashrc (interactive drt sessions) and by drt-device
## (agent-driven device sessions). Installed at /usr/local/lib/drt/drt-save.sh.
##
## Expects the environment set up by entrypoint.sh when SOPS_SAVE_ON_EXIT=true:
##   SOPS_CONFIG_FILE      plaintext, user-writable copy of the decrypted config
##   _SOPS_SAVE_REQUEST    FIFO to the root save helper
##   _SOPS_SAVE_RESPONSE   FIFO for the helper's reply ("ok" or "fail")
##   _SOPS_BIND_PATH       the encrypted config bind-mounted from the host
##
## A state DIR holds:
##   DIR/initial     `d.rymcg.tech export-env` output at the last save (baseline)
##   DIR/preserved   config lines export-env doesn't reproduce (kept on save)
##   DIR/current     export-env output from the last drt_save_diff

## Serialized data keys always carried over as a safety net, in case
## export-env can't reproduce them at save time.
_drt_save_is_serialized_key() {
    case "$1" in
        __passwords__*|__doctl_config__|__aws_credentials__|__aws_config__|\
        __gh_hosts__|__rclone_config__|__mc_config__|__bashrc_local__|\
        __ssh_config__|__ssh_key__*|__wireguard__*|__gnupg__*|\
        __gumdrop_preset__*|__drt_config__*|__kube__*|__motd__)
            return 0 ;;
    esac
    return 1
}

## Print the vars and comment headers in SOPS_CONFIG_FILE that export-env
## doesn't produce (e.g. SSH_KNOWN_HOSTS, BAO_*, the "## OpenBao" header),
## plus all serialized data keys.
## Args: $1 = file with export-env output (whose keys are not preserved)
_drt_save_extract_preserved() {
    local keys_file="$1"
    local decrypted
    decrypted=$(cat "${SOPS_CONFIG_FILE}" 2>/dev/null) || return 0
    declare -A _export_keys
    local k line header key result=""
    while IFS='=' read -r k _; do
        if [[ -n "${k}" && "${k}" != "#"* ]]; then
            _export_keys["${k}"]=1
        fi
    done < "${keys_file}"
    while IFS= read -r line; do
        if [[ "${line}" == "## "* ]]; then
            header="${line#\#\# }"
            case "${header}" in
                "SSH"|.env_*|*/.env_*|*/passwords.json|"doctl config"|\
                "aws config"|"gh config"|"rclone config"|"mc config"|\
                "wireguard configs"|"gnupg config"|"bashrc.local"|\
                "ssh config"|"ssh keys"|"gumdrop presets"|\
                "drt user config"|"kube config"|"motd")
                    ;;
                *)
                    [[ -n "${result}" ]] && result+=$'\n'
                    result+="${line}"
                    ;;
            esac
        elif [[ "${line}" == *=* && "${line}" != "#"* ]]; then
            key="${line%%=*}"
            if _drt_save_is_serialized_key "${key}" || [[ -z "${_export_keys[${key}]+set}" ]]; then
                [[ -n "${result}" ]] && result+=$'\n'
                result+="${line}"
            fi
        fi
    done <<< "${decrypted}"
    echo "${result}"
}

## Merge preserved lines with fresh export-env output.
## Args: $1 = initial export-env, $2 = preserved lines, $3 = current export-env
_drt_save_merge() {
    local initial="$1" preserved="$2" export_output="$3"
    local export_keys initial_keys line key
    export_keys=$(grep -oP '^[A-Za-z_][A-Za-z_0-9]*(?==)' "${export_output}" || true)
    initial_keys=$(grep -oP '^[A-Za-z_][A-Za-z_0-9]*(?==)' "${initial}" || true)
    if [[ -s "${preserved}" ]]; then
        while IFS= read -r line || [[ -n "${line}" ]]; do
            if [[ "${line}" == *=* && "${line}" != "#"* ]]; then
                key="${line%%=*}"
                # Skip a preserved key if export-env produced a fresh version
                if echo "${export_keys}" | grep -qx "${key}"; then
                    continue
                fi
                # Skip a preserved key that was in the initial state but is no
                # longer in the current state (intentionally removed)
                if echo "${initial_keys}" | grep -qx "${key}" && \
                   ! echo "${export_keys}" | grep -qx "${key}"; then
                    continue
                fi
            fi
            echo "${line}"
        done < "${preserved}"
        echo ""
        cat "${export_output}"
    else
        cat "${export_output}"
    fi
}

## Ask the root helper to fix ownership of config dirs before serializing.
_drt_save_fix_perms() {
    if [[ -p "${_SOPS_SAVE_REQUEST:-}" ]]; then
        echo "fix-perms" > "${_SOPS_SAVE_REQUEST}"
        read -r _ < "${_SOPS_SAVE_RESPONSE}"
    fi
}

## Record the current state as the baseline for later diffs.
## Args: $1 = state dir
drt_save_snapshot() {
    local dir="$1"
    d.rymcg.tech export-env > "${dir}/initial" 2>/dev/null || true
    _drt_save_extract_preserved "${dir}/initial" > "${dir}/preserved"
}

## Compare the current state with the baseline.
## Prints a unified diff (which contains secret values) to stdout.
## Returns 0 if there are unsaved changes, 1 if not.
## Args: $1 = state dir
drt_save_diff() {
    local dir="$1"
    _drt_save_fix_perms
    d.rymcg.tech export-env > "${dir}/current" 2>/dev/null || true
    if diff -q "${dir}/initial" "${dir}/current" &>/dev/null; then
        return 1
    fi
    diff -u "${dir}/initial" "${dir}/current" || true
    return 0
}

## Print the names of keys changed since the baseline, without values.
## Lines are "+ KEY" (added), "- KEY" (removed) or "~ KEY" (changed).
## Run drt_save_diff first to refresh DIR/current.
## Args: $1 = state dir
drt_save_changed_keys() {
    local dir="$1"
    awk 'NR == FNR {
             if ($0 !~ /^#/ && (i = index($0, "=")) > 1) old[substr($0, 1, i - 1)] = substr($0, i + 1)
             next
         }
         $0 !~ /^#/ && (i = index($0, "=")) > 1 {
             k = substr($0, 1, i - 1); v = substr($0, i + 1); seen[k] = 1
             if (!(k in old)) print "+ " k
             else if (old[k] != v) print "~ " k
         }
         END { for (k in old) if (!(k in seen)) print "- " k }' \
        "${dir}/initial" "${dir}/current" | sort -k2
}

## Merge the current state and encrypt it back to the SOPS config.
## On success the saved state becomes the new baseline.
## Args: $1 = state dir
##       $2 = helper command: "save" (default; re-encrypts only changed values,
##            may need a FIDO2 touch) or "save-unattended" (never needs a touch)
## Returns 0 on success, 1 on failure.
drt_save_commit() {
    local dir="$1" helper_cmd="${2:-save}"
    local merged export_output rc=1
    merged=$(mktemp)
    export_output=$(mktemp)
    d.rymcg.tech export-env > "${export_output}" 2>/dev/null || true
    _drt_save_merge "${dir}/initial" "${dir}/preserved" "${export_output}" > "${merged}"
    if [[ -p "${_SOPS_SAVE_REQUEST:-}" ]]; then
        # Write the unencrypted merged config; the root helper encrypts and saves
        cat "${merged}" > "${SOPS_CONFIG_FILE}"
        echo "${helper_cmd}" > "${_SOPS_SAVE_REQUEST}"
        local result
        read -r result < "${_SOPS_SAVE_RESPONSE}"
        if [[ "${result}" == "ok" ]]; then
            cp "${export_output}" "${dir}/initial"
            _drt_save_extract_preserved "${dir}/initial" > "${dir}/preserved"
            rc=0
        fi
    else
        # No root helper: encrypt directly
        if sops encrypt --input-type dotenv --output-type dotenv \
               --filename-override export.env \
               --age "${SOPS_AGE_RECIPIENTS}" "${merged}" > "${SOPS_CONFIG_FILE}"; then
            cp "${export_output}" "${dir}/initial"
            rc=0
        fi
    fi
    rm -f "${merged}" "${export_output}"
    return ${rc}
}
