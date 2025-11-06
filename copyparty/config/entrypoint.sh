#!/bin/sh
set -eu

log() { printf '%s %s\n' "[config]" "$*"; }
die() { printf '%s %s\n' "[config][ERROR]" "$*" >&2; exit 1; }

# ---- Locations (config volume must be mounted at /etc/copyparty) ----
CFG_DIR=${COPYPARTY_CONFIG_DIR:-/etc/copyparty}
CFG_PATH=${COPYPARTY_CONFIG:-$CFG_DIR/copyparty.conf}

DATA_ROOT=${COPYPARTY_DATA_DIR:-/data}
MNT_ROOT=${COPYPARTY_MNT_ROOT:-/mnt}

# ---- Required knobs (only used if generating) ----
ADMIN_USER=${COPYPARTY_ADMIN_USER:-}
ADMIN_PASS=${COPYPARTY_ADMIN_PASSWORD:-}

# Fast-fail if the config dir is not writable (named volume should be here)
[ -d "$CFG_DIR" ] || mkdir -p "$CFG_DIR" || die "cannot mkdir $CFG_DIR"
[ -w "$CFG_DIR" ] || die "config dir not writable: $CFG_DIR (is the volume mounted?)"

# If a config already exists and FORCE_REGENERATE!=true, just enforce RO & exit
if [ -f "$CFG_PATH" ] && [ "${FORCE_REGENERATE:-false}" != "true" ]; then
  chmod 0444 "$CFG_PATH" || true
  log "using existing config: $CFG_PATH (left read-only)"
  exit 0
fi

# When generating, require admin creds
[ -n "$ADMIN_USER" ] || die "set COPYPARTY_ADMIN_USER"
[ -n "$ADMIN_PASS" ] || die "set COPYPARTY_ADMIN_PASSWORD"

PORT=${COPYPARTY_PORT:-3923}
ALLOW_NET=${COPYPARTY_ALLOW_NET:-}
THEME=${COPYPARTY_THEME:-}
NAME=${COPYPARTY_NAME:-}
ENABLE_STATS=${COPYPARTY_ENABLE_STATS:-}
DISABLE_DUPE=${COPYPARTY_DISABLE_DUPE:-}
NO_ROBOTS=${COPYPARTY_NO_ROBOTS:-}
FORCE_JS=${COPYPARTY_FORCE_JS:-}

PUB_PATH=${COPYPARTY_VOL_PUBLIC_PATH:-$DATA_ROOT/public}
GST_PATH=${COPYPARTY_VOL_GUESTS_PATH:-$DATA_ROOT/guests}
ADM_PATH=$DATA_ROOT/admin

mkdir -p "$PUB_PATH" "$GST_PATH"
chown -R "${COPYPARTY_UID:-1000}:${COPYPARTY_GID:-1000}" "${PUB_PATH}" "${GST_PATH}"

# Helper: emit per-volume permission lines for a given volume name
emit_perms() {
  volname="$1"
  perms="${COPYPARTY_VOL_PERMISSIONS:-}"
  # perms items: name:perm:user1/user2/...
  # We may iterate multiple times; config is tiny so O(n^2) is fine.
  OLDIFS="$IFS"
  IFS=,
  for ent in $perms; do
    [ -z "$ent" ] && continue
    v=${ent%%:*}; rest=${ent#*:}
    p=${rest%%:*}; users=${rest#*:}
    [ "$v" = "$volname" ] || continue
    # validate perm letters roughly; copyparty supports r,w,m,d,a,g,G,h,A,.
    case "$p" in
      (*[!rwmdgGhaA.]*)
        die "invalid permission letters '$p' in '$ent'"
        ;;
    esac
    # users are slash-delimited; convert to comma list
    u=$(printf '%s' "$users" | tr '/' ',')
    printf '    %s: %s\n' "$p" "$u"
  done
  IFS="$OLDIFS"
}

# Parse external volumes list (name:/abs/host/path)
# We *assume* operator binds host path into app container at $MNT_ROOT/<name>
VOLS="${COPYPARTY_VOL_EXTERNAL:-}"

# Parse optional extra users: "user:pass,alice:pw2"
USERS="${COPYPARTY_USERS:-}"

# Build the config atomically
TMP="$CFG_PATH.tmp.$$"
umask 022

{
  printf '# -*- pretend-yaml -*-\n\n'
  printf '[global]\n'
  printf '  e2dsa\n'
  printf '  e2ts\n'
  printf '  ansi\n'
  printf '  xff-src: lan\n'
  printf '  xff-hdr: X-Forwarded-For\n'
  printf '  rproxy: 1\n'
  printf '  shr: /share\n'
  printf '  shr-who: a\n'
  printf '  shr-adm: admin\n'
  printf '  p: %s\n' "$PORT"
  [ -n "$ALLOW_NET" ]  && printf '  ipa: %s\n'   "$ALLOW_NET"
  [ -n "$THEME" ]      && printf '  theme: %s\n' "$THEME"
  [ -n "$NAME" ]       && printf '  name: %s\n'  "$NAME"
  [ "${ENABLE_STATS:-}" = "true" ] && printf '  stats\n'
  [ "${DISABLE_DUPE:-}" = "true" ] && printf '  nos-dup\n'
  [ "${NO_ROBOTS:-}"    = "true" ] && printf '  no-robots\n'
  [ "${FORCE_JS:-}"     = "true" ] && printf '  force-js\n'

  printf '\n[accounts]\n'
  printf '  %s: %s\n' "$ADMIN_USER" "$ADMIN_PASS"

  if [ -n "$USERS" ]; then
    OLDIFS="$IFS"; IFS=,
    for ent in $USERS; do
      [ -z "$ent" ] && continue
      u=${ent%%:*}; p=${ent#*:}
      [ -n "$u" ] && [ -n "$p" ] || die "bad COPYPARTY_USERS item '$ent'"
      case "$u$p" in (*[,:\ ]*) die "users/passwords cannot contain , : or space: '$ent'";; esac
      printf '  %s: %s\n' "$u" "$p"
    done
    IFS="$OLDIFS"
  fi

  printf '\n[/admin]\n'
  printf '  %s\n' "$ADM_PATH"
  printf '  accs:\n'
  printf '    rwmda: %s\n' "$ADMIN_USER"
  printf '\n'

  if [ "${COPYPARTY_ENABLE_PUBLIC_ACCESS:-}" = "true" ]; then
    printf '[/public]\n'
    printf '  %s\n' "$PUB_PATH"
    printf '  accs:\n'
    printf '    r: *\n'
    printf '    rwmda: %s\n\n' "$ADMIN_USER"
  fi

  if [ "${COPYPARTY_ENABLE_GUEST_ACCESS:-}" = "true" ]; then
    printf '[/guests]\n'
    printf '  %s\n' "$GST_PATH"
    printf '  accs:\n'
    printf '    w: *\n'
    printf '    rwmda: %s\n\n' "$ADMIN_USER"
  fi

  if [ -n "$VOLS" ]; then
    OLDIFS="$IFS"; IFS=,
    for ent in $VOLS; do
      [ -z "$ent" ] && continue
      name=${ent%%:*}; hpath=${ent#*:}
      [ -n "$name" ] && [ -n "$hpath" ] || die "bad COPYPARTY_VOL_EXTERNAL item '$ent' (want name:/abs/host/path)"
      case "$name$hpath" in (*[,:\ ]*) die "names/paths cannot contain , : or space: '$ent'";; esac
      case "$hpath" in (/*) : ;; (*) die "host path must be absolute: '$hpath'";; esac

      # Container mount point for this external volume:
      rpath="$MNT_ROOT/$name"
      printf '[/%s]\n' "$name"
      printf '  %s\n' "$rpath"
      printf '  accs:\n'
      emit_perms "$name"
      printf '    rwmda: %s\n\n' "$ADMIN_USER"
    done
    IFS="$OLDIFS"
  fi
} > "$TMP"

# Lock it down
chmod 0444 "$TMP"
mv -f "$TMP" "$CFG_PATH"
log "wrote config to $CFG_PATH (root:root 0444)"

# Optionally show a short preview (no secrets leak beyond existence)
log "done."
exit 0
