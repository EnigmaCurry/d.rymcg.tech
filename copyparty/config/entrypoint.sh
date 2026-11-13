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

HOME_ROOT=$DATA_ROOT/home

mkdir -p "$PUB_PATH" "$GST_PATH"
chown -R "${COPYPARTY_UID:-1000}:${COPYPARTY_GID:-1000}" "${PUB_PATH}" "${GST_PATH}"

# Pre-create per-user home folders (copyparty expands [/home/${u}] for
# every account at startup; create the dirs here so they are owned by
# the copyparty UID/GID):
if [ "${COPYPARTY_ENABLE_USER_HOMES:-}" = "true" ]; then
  mkdir -p "$HOME_ROOT/$ADMIN_USER"
  OLDIFS="$IFS"; IFS=,
  for ent in ${COPYPARTY_USERS:-}; do
    [ -z "$ent" ] && continue
    u=${ent%%:*}
    case "$u" in (""|*/*|.|..) die "invalid username for home folder: '$u'";; esac
    mkdir -p "$HOME_ROOT/$u"
  done
  IFS="$OLDIFS"
  # Only chown the top level of each home, not user content:
  chown "${COPYPARTY_UID:-1000}:${COPYPARTY_GID:-1000}" "$HOME_ROOT" "$HOME_ROOT"/*
fi

# Parse external volumes list (name:/abs/host/path)
# We *assume* operator binds host path into app container at $MNT_ROOT/<name>
VOLS="${COPYPARTY_VOL_EXTERNAL:-}"

# is_external <name>: true if <name> is an external volume name
is_external() {
  _ifs="$IFS"; IFS=,
  for _v in $VOLS; do
    if [ "${_v%%:*}" = "$1" ]; then IFS="$_ifs"; return 0; fi
  done
  IFS="$_ifs"; return 1
}

# first_segment </a/b/c>: prints "a"
first_segment() { _s=${1#/}; printf '%s' "${_s%%/*}"; }

# norm_path <path>: validate a copyparty URL path and print it without
# trailing slashes:
norm_path() {
  _p=$1
  while [ "$_p" != "/" ] && [ "$_p" != "${_p%/}" ]; do _p=${_p%/}; done
  case "$_p" in (/*) : ;; (*) die "path must start with '/': '$1'";; esac
  [ "$_p" != "/" ] || die "cannot set permissions on the root path '/'"
  case "$_p" in
    (*//*|*/.*|*[!A-Za-z0-9._/-]*)
      die "invalid path '$1' (use letters, numbers, '.', '_', '-' and '/'; no empty or dot-prefixed segments)";;
  esac
  case "$(first_segment "$_p")" in
    (admin|public|guests|home|share)
      die "path '$_p' is reserved for copyparty's built-in volumes";;
  esac
  printf '%s' "$_p"
}

# ---- Path permissions ----
# COPYPARTY_PERMISSIONS is a comma separated list of
# /path:permission:user1/user2 entries. A path under an external volume
# name is stored on that volume (/mnt/<name>/...); any other path is
# stored on the data volume (/data/<path>).
PERMS=${COPYPARTY_PERMISSIONS:-}
OLD_PERMS=${COPYPARTY_VOL_PERMISSIONS:-}
if [ -n "$OLD_PERMS" ]; then
  if [ -z "$PERMS" ]; then
    log "WARNING: COPYPARTY_VOL_PERMISSIONS is deprecated; converting it to COPYPARTY_PERMISSIONS (run 'make config-volumes' to update your .env file)"
    # name:perm:users -> /name:perm:users
    PERMS=$(printf '%s' "$OLD_PERMS" | awk 'BEGIN { RS = "," } { sub(/\n$/, "") } $0 != "" { sub(/^\/*/, "/"); printf "%s%s", (n++ ? "," : ""), $0 }')
  else
    log "WARNING: ignoring deprecated COPYPARTY_VOL_PERMISSIONS because COPYPARTY_PERMISSIONS is set"
  fi
fi

# Validate and normalize every entry; collect the distinct paths:
NPERMS=""
PATHS=""
NL='
'
OLDIFS="$IFS"; IFS=,
for ent in $PERMS; do
  [ -z "$ent" ] && continue
  case "$ent" in (*:*:*) : ;; (*) die "bad COPYPARTY_PERMISSIONS item '$ent' (want /path:perm:user1/user2)";; esac
  path=${ent%%:*}; rest=${ent#*:}
  p=${rest%%:*}; users=${rest#*:}
  # copyparty supports r,w,m,d,a,g,G,h,A,.
  case "$p" in (""|*[!rwmdgGhaA.]*) die "invalid permission letters '$p' in '$ent'";; esac
  case "$users" in (""|*[:\ ]*|/*|*/|*//*) die "invalid user list '$users' in '$ent'";; esac
  path=$(norm_path "$path")
  NPERMS="$NPERMS${NPERMS:+,}$path:$p:$users"
  case "$NL$PATHS$NL" in
    (*"$NL$path$NL"*) : ;;
    (*) PATHS="$PATHS${PATHS:+$NL}$path";;
  esac
done
IFS="$OLDIFS"

# real_path </path>: the container directory a path is stored in
real_path() {
  if is_external "$(first_segment "$1")"; then
    printf '%s%s' "$MNT_ROOT" "$1"
  else
    printf '%s%s' "$DATA_ROOT" "$1"
  fi
}

# Create the data volume folders (each level owned by the copyparty
# user, not recursively). Folders on external volumes are created by
# copyparty itself:
OLDIFS="$IFS"; IFS=$NL
for path in $PATHS; do
  is_external "$(first_segment "$path")" && continue
  d=$DATA_ROOT
  IFS=/
  for seg in ${path#/}; do
    d="$d/$seg"
    mkdir -p "$d"
    chown "${COPYPARTY_UID:-1000}:${COPYPARTY_GID:-1000}" "$d"
  done
  IFS=$NL
done
IFS="$OLDIFS"

# emit_perms </path>: print the accs lines for a path
emit_perms() {
  _ifs="$IFS"; IFS=,
  for _ent in $NPERMS; do
    [ "${_ent%%:*}" = "$1" ] || continue
    _rest=${_ent#*:}
    # users are slash-delimited; convert to comma list
    printf '    %s: %s\n' "${_rest%%:*}" "$(printf '%s' "${_rest#*:}" | tr '/' ',')"
  done
  IFS="$_ifs"
}

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

  if [ "${COPYPARTY_ENABLE_USER_HOMES:-}" = "true" ]; then
    # Parent volume restricted to the admin, so per-user homes never
    # inherit looser permissions from a parent:
    printf '[/home]\n'
    printf '  %s\n' "$HOME_ROOT"
    printf '  accs:\n'
    printf '    rwmda: %s\n\n' "$ADMIN_USER"
    # copyparty expands ${u} into one volume per account:
    printf '[/home/${u}]\n'
    printf '  %s/${u}\n' "$HOME_ROOT"
    printf '  accs:\n'
    printf '    rwmda: ${u}, %s\n\n' "$ADMIN_USER"
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
      emit_perms "/$name"
      printf '    rwmda: %s\n\n' "$ADMIN_USER"
    done
    IFS="$OLDIFS"
  fi

  # Every other permission path becomes its own volume. copyparty
  # volumes don't inherit permissions from a parent volume, so each one
  # gets its full list (plus the admin):
  OLDIFS="$IFS"; IFS=$NL
  for path in $PATHS; do
    first=$(first_segment "$path")
    if is_external "$first" && [ "$path" = "/$first" ]; then
      continue  # already emitted above
    fi
    printf '[%s]\n' "$path"
    printf '  %s\n' "$(real_path "$path")"
    printf '  accs:\n'
    emit_perms "$path"
    printf '    rwmda: %s\n\n' "$ADMIN_USER"
  done
  IFS="$OLDIFS"
} > "$TMP"

# Lock it down
chmod 0444 "$TMP"
mv -f "$TMP" "$CFG_PATH"
log "wrote config to $CFG_PATH (root:root 0444)"

# Optionally show a short preview (no secrets leak beyond existence)
log "done."
exit 0
