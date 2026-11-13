## platform.sh - shared services that other apps need, sourced by e2e.sh.
##
## Some apps can't be tested alone: mosquitto and nats need a step-ca server
## (and a one-time token) for their TLS certificates, and oauth2-proxy needs an
## OIDC provider (Forgejo) with an OAuth2 app registered in it. This file:
##
##   * sets up those providers after they install (app_post_setup): step-ca's
##     fingerprint; Forgejo's test users, org/team, and OAuth2 app,
##   * prepares the apps that use them (app_platform_pre_install): one-time
##     step-ca tokens, the mosquitto ACL,
##   * runs functional tests once an app's route verifies (app_functional_tests):
##     MQTT/NATS publish/subscribe with step-ca client certificates, and the
##     full OAuth2 login flow through oauth2-proxy and Forgejo.
##
## Values the platform produces (fingerprint, client id/secret, test user
## passwords) are kept in a 0600 dotenv file on the droplet (PLATFORM_ENV), not
## in the local .state file. An app's test vars read them as @platform:<VAR>.

PLATFORM_ENV='$HOME/.config/d.rymcg.tech/e2e-platform.env'

## Test accounts in Forgejo: an admin (drives the API), a member of the
## authorized team, and an outsider (a valid login, but not in the team):
E2E_OIDC_ADMIN=e2e-admin
E2E_OIDC_MEMBER=e2e-member
E2E_OIDC_OUTSIDER=e2e-outsider
E2E_OIDC_ORG=e2e
E2E_OIDC_TEAM=allowed
E2E_OIDC_APP=e2e-oauth2-proxy
## The whoami instance protected by OAuth2 (separate from the plain whoami):
E2E_OAUTH2_INSTANCE=oauth
E2E_OAUTH2_HOST() { echo "whoami-oauth.${E2E_ROOT_DOMAIN}"; }

## The whoami instance published as a Tor hidden service (by the tor app):
E2E_TOR_INSTANCE=tor
E2E_TOR_HOST() { echo "whoami-tor.${E2E_ROOT_DOMAIN}"; }
## The hidden service's name in TOR_HIDDEN_SERVICES (its HiddenServiceDir):
E2E_TOR_SERVICE=whoami

## copyparty's external volume (e2e-ext) is this directory on the droplet:
E2E_COPYPARTY_EXT_DIR=/srv/e2e-copyparty-ext

## The Let's Encrypt staging roots, trusted by oauth2-proxy when the test uses
## the staging CA (it fetches Forgejo's OIDC discovery doc server-side):
LE_STAGING_ROOTS="https://letsencrypt.org/certs/staging/letsencrypt-stg-root-x1.pem,https://letsencrypt.org/certs/staging/letsencrypt-stg-root-x2.pem"

## S3 buckets in the platform minio, one per consumer (each gets its own
## user, limited to its bucket): "<bucket> <VAR_PREFIX>"
E2E_S3_BUCKETS=("e2e-s3-proxy S3PROXY" "e2e-nextcloud NEXTCLOUD")
## The minio client, run on the droplet (it talks to minio via Traefik):
MC_IMAGE=docker.io/pgsty/mc:latest

## Docker's address pools on the droplet (see remote_bootstrap.sh). Containers
## that call another app through the droplet's public IP (oauth2-proxy ->
## Forgejo, step-cli -> step-ca) arrive at Traefik from these addresses:
DOCKER_POOL_CIDR=172.16.0.0/12

platform_remote_prelude() {
    ## Shell helpers for remote snippets: pget/pset (platform dotenv),
    ## stepca (exec in the step-ca container), fj (forgejo CLI):
    cat <<EOF
pf=${PLATFORM_ENV}
mkdir -p "\$(dirname "\${pf}")"; touch "\${pf}"; chmod 600 "\${pf}"
pget() { _scripts/dotenv -f "\${pf}" get "\$1" 2>/dev/null || true; }
pset() { _scripts/dotenv -f "\${pf}" set "\$1=\$2"; }
container_of() { docker ps -q --filter label=com.docker.compose.project=\$1 --filter label=com.docker.compose.service=\$2 | head -n 1; }
stepca() { docker exec "\$(container_of step-ca step-ca)" "\$@"; }
STEP_ARGS="--ca-url https://localhost:9000 --root /home/step/certs/root_ca.crt"
## The admin provisioner's password is only printed once, by init-ca (see
## step_ca_init_snippet); stepca_pw puts it in a temp file in the container:
STEP_PW=/tmp/e2e-provisioner-password
stepca_pw() { pget STEP_CA_PROVISIONER_PASSWORD | docker exec -i "\$(container_of step-ca step-ca)" sh -c "umask 077; cat > \${STEP_PW}"; }
fj() { docker exec "\$(container_of forgejo forgejo)" forgejo "\$@"; }
EOF
}

platform_get() {
    ## platform_get <VAR> - print a value from the droplet's platform env:
    e2e_remote_sh "_scripts/dotenv -f ${PLATFORM_ENV} get $1 2>/dev/null || true" 2>/dev/null
}

app_platform_sourcerange() {
    ## app_platform_sourcerange <app> - extra CIDRs (beyond the test's source
    ## range) for providers that other containers reach via the public IP:
    case "$1" in
        step-ca|forgejo) echo "${DROPLET_IP}/32,${DOCKER_POOL_CIDR}" ;;
    esac
}

app_host_ports() {
    ## app_host_ports <app> - print "PORT PROTO" for ports the app publishes
    ## on the host directly (not through Traefik), to open in the firewall:
    case "$1" in
        mosquitto) echo "8883 tcp" ;;
        nats)      echo "4222 tcp" ;;
    esac
}

## -------------------------------------------------------------------------
## Provider setup (after install, every run; idempotent)
## -------------------------------------------------------------------------

app_post_setup() {
    ## app_post_setup <app> - run after the app installs (or is found
    ## already verified), to set up what other apps need from it:
    case "$1" in
        step-ca) platform_setup_step_ca ;;
        forgejo) platform_setup_forgejo ;;
        oauth2-proxy) platform_setup_oauth2_whoami ;;
        minio) platform_setup_minio ;;
        tor) platform_setup_tor_whoami ;;
    esac
}

platform_setup_step_ca() {
    echo "Recording the step-ca root fingerprint ..."
    e2e_remote_sh "$(platform_remote_prelude)
fp=\$(stepca step certificate fingerprint /home/step/certs/root_ca.crt)
test -n \"\${fp}\"
pset STEP_CA_FINGERPRINT \"\${fp}\"
pset STEP_CA_URL https://step-ca.${E2E_ROOT_DOMAIN}
echo \"step-ca fingerprint: \${fp}\""
    platform_setup_traefik_step_ca
}

platform_setup_traefik_step_ca() {
    ## Have Traefik trust the platform step-ca (TRAEFIK_STEP_CA_*), as a
    ## user would for mTLS. Step-CA is served by this same Traefik, so the
    ## restarted Traefik can't bootstrap at startup: it starts without the
    ## CA, retries in the background, and restarts itself once it has it.
    ## oauth2-proxy's 'make config' copies these settings (configure_step_ca.sh).
    echo "Configuring Traefik to trust the platform step-ca ..."
    e2e_remote_sh "$(platform_remote_prelude)
tenv=traefik/.env_${E2E_NAME}_default
url=https://step-ca.${E2E_ROOT_DOMAIN}
fp=\$(pget STEP_CA_FINGERPRINT)
if [ \"\$(_scripts/dotenv -f \${tenv} get TRAEFIK_STEP_CA_ENABLED)\" = true ] && \\
   [ \"\$(_scripts/dotenv -f \${tenv} get TRAEFIK_STEP_CA_ENDPOINT)\" = \"\${url}\" ] && \\
   [ \"\$(_scripts/dotenv -f \${tenv} get TRAEFIK_STEP_CA_FINGERPRINT)\" = \"\${fp}\" ]; then
  echo 'Traefik already trusts the platform step-ca.'
else
  _scripts/reconfigure \${tenv} TRAEFIK_STEP_CA_ENABLED=true TRAEFIK_STEP_CA_ENDPOINT=\${url} TRAEFIK_STEP_CA_FINGERPRINT=\${fp}
  make -C traefik install instance=default
fi
## Wait for the (background) bootstrap and Traefik's self-restart:
for i in \$(seq 1 60); do
  c=\$(container_of traefik traefik)
  if [ -n \"\${c}\" ] && docker exec \${c} test -s /certs/step_ca_intermediate.crt 2>/dev/null && \\
     [ \"\$(docker inspect -f '{{.State.Health.Status}}' \${c} 2>/dev/null)\" = healthy ] && \\
     curl -sfk -o /dev/null --max-time 5 \${url}/health; then
    echo 'Traefik has bootstrapped step-ca and is serving again.'; exit 0
  fi
  sleep 5
done
echo 'ERROR: Traefik did not bootstrap step-ca within 5 minutes:'
docker logs --tail 30 \$(container_of traefik traefik) 2>&1 | grep -i 'step-ca\\|restart' || true
exit 1"
}

platform_setup_forgejo() {
    echo "Setting up Forgejo as the OIDC provider (users, org/team, OAuth2 app) ..."
    local host="forgejo.${E2E_ROOT_DOMAIN}"
    local redirect="https://oauth2-proxy.${E2E_ROOT_DOMAIN}/oauth2/callback"
    e2e_remote_sh "$(platform_remote_prelude)
## Wait for the CLI (the database may still be migrating):
for i in \$(seq 1 30); do fj admin user list >/dev/null 2>&1 && break; sleep 2; done
ensure_user() {
  ## ensure_user <name> <PASSWORD_VAR> [--admin] - create or re-sync a user:
  local name=\$1 var=\$2 admin=\${3:-} pw
  pw=\$(pget \${var})
  if [ -z \"\${pw}\" ]; then pw=\$(openssl rand -hex 16); pset \${var} \"\${pw}\"; fi
  if fj admin user list | awk 'NR>1 {print \$2}' | grep -qxF \"\${name}\"; then
    fj admin user change-password --username \"\${name}\" --password \"\${pw}\" --must-change-password=false >/dev/null
  else
    fj admin user create \${admin} --username \"\${name}\" --email \"\${name}@${E2E_ROOT_DOMAIN}\" \\
       --password \"\${pw}\" --must-change-password=false >/dev/null
  fi
  echo \"Forgejo user ready: \${name}\"
}
ensure_user ${E2E_OIDC_ADMIN} OIDC_ADMIN_PASSWORD --admin
ensure_user ${E2E_OIDC_MEMBER} OIDC_MEMBER_PASSWORD
ensure_user ${E2E_OIDC_OUTSIDER} OIDC_OUTSIDER_PASSWORD

## Forgejo API as the e2e admin (setup only: the staging cert is fine here):
api() {
  ## api <METHOD> <PATH> [JSON] - prints the body; fails on HTTP >= 400:
  curl -sS -k --fail-with-body --resolve ${host}:443:${DROPLET_IP} \\
       -u ${E2E_OIDC_ADMIN}:\"\$(pget OIDC_ADMIN_PASSWORD)\" \\
       -H 'Content-Type: application/json' -X \"\$1\" \"https://${host}/api/v1\$2\" \${3:+-d \"\$3\"}
}
## Org + team. Forgejo's OIDC 'groups' claim lists the user's orgs and
## <org>:<team> memberships:
api GET /orgs/${E2E_OIDC_ORG} >/dev/null 2>&1 || \\
  api POST /orgs '{\"username\":\"${E2E_OIDC_ORG}\",\"visibility\":\"public\"}' >/dev/null
team_id=\$(api GET /orgs/${E2E_OIDC_ORG}/teams | jq -r '.[] | select(.name==\"${E2E_OIDC_TEAM}\") | .id')
if [ -z \"\${team_id}\" ]; then
  team_id=\$(api POST /orgs/${E2E_OIDC_ORG}/teams \\
    '{\"name\":\"${E2E_OIDC_TEAM}\",\"permission\":\"read\",\"units\":[\"repo.code\"]}' | jq -r .id)
fi
api PUT /teams/\${team_id}/members/${E2E_OIDC_MEMBER} >/dev/null
echo \"Team ${E2E_OIDC_ORG}:${E2E_OIDC_TEAM} (id \${team_id}) has member ${E2E_OIDC_MEMBER}.\"

## OAuth2 apps. Forgejo shows a secret only at creation, so keep an app
## only if its client id matches the one we saved with its secret:
oauth_app() {
  ## oauth_app <name> <redirect-uri> <VAR_PREFIX> - saves <VAR_PREFIX>_CLIENT_ID
  ## and <VAR_PREFIX>_CLIENT_SECRET in the platform env:
  local name=\$1 redirect=\$2 var=\$3 app app_id client_id created
  app=\$(api GET /user/applications/oauth2 | jq -c --arg n \"\${name}\" '.[] | select(.name==\$n)')
  app_id=\$(echo \"\${app}\" | jq -r '.id // empty')
  client_id=\$(echo \"\${app}\" | jq -r '.client_id // empty')
  if [ -z \"\${client_id}\" ] || [ \"\${client_id}\" != \"\$(pget \${var}_CLIENT_ID)\" ] || [ -z \"\$(pget \${var}_CLIENT_SECRET)\" ]; then
    if [ -n \"\${app_id}\" ]; then api DELETE /user/applications/oauth2/\${app_id} >/dev/null; fi
    created=\$(api POST /user/applications/oauth2 \"\$(jq -nc --arg n \"\${name}\" --arg r \"\${redirect}\" \\
      '{name:\$n, redirect_uris:[\$r], confidential_client:true}')\")
    pset \${var}_CLIENT_ID \"\$(echo \"\${created}\" | jq -r .client_id)\"
    pset \${var}_CLIENT_SECRET \"\$(echo \"\${created}\" | jq -r .client_secret)\"
    echo \"Registered OAuth2 app \${name} (client id \$(pget \${var}_CLIENT_ID)).\"
  else
    echo \"OAuth2 app \${name} already registered (client id \${client_id}).\"
  fi
}
oauth_app ${E2E_OIDC_APP} ${redirect} OIDC
oauth_app e2e-woodpecker https://woodpecker.${E2E_ROOT_DOMAIN}/authorize WOODPECKER"
}

minio_prelude() {
    ## mc() on the droplet, with the minio root account as alias 'e2e'
    ## (MC_HOST_<alias> = https://<user>:<password>@<host>):
    local insecure=""
    [[ "${E2E_ACME_CA}" == *staging* ]] && insecure="--insecure"
    cat <<EOF
envf=minio/.env_${E2E_NAME}_default
mc_host="https://\$(_scripts/dotenv -f \${envf} get MINIO_ROOT_USER):\$(_scripts/dotenv -f \${envf} get MINIO_ROOT_PASSWORD)@minio.${E2E_ROOT_DOMAIN}"
mc() { docker run --rm --network host -e MC_HOST_e2e="\${mc_host}" \${MC_VOLUME:-} ${MC_IMAGE} ${insecure} "\$@"; }
EOF
}

platform_setup_minio() {
    echo "Setting up minio buckets and users for S3 consumers ..."
    local entry bucket var buckets=""
    for entry in "${E2E_S3_BUCKETS[@]}"; do buckets+="${entry};"; done
    e2e_remote_sh "$(platform_remote_prelude)
$(minio_prelude)
pdir=\$(mktemp -d); chmod 755 \${pdir}
MC_VOLUME=\"-v \${pdir}:/policy:ro\"
## Wait for the S3 API through Traefik:
for i in \$(seq 1 30); do mc admin info e2e >/dev/null 2>&1 && break; sleep 2; done
IFS=';' read -ra entries <<< '${buckets}'
for entry in \"\${entries[@]}\"; do
  [ -n \"\${entry}\" ] || continue
  read -r bucket var <<< \"\${entry}\"
  secret=\$(pget \${var}_S3_SECRET)
  if [ -z \"\${secret}\" ]; then secret=\$(openssl rand -hex 20); pset \${var}_S3_SECRET \"\${secret}\"; fi
  pset \${var}_S3_KEY \${bucket}
  pset \${var}_S3_BUCKET \${bucket}
  mc mb --ignore-existing e2e/\${bucket} >/dev/null
  cat > \${pdir}/\${bucket}.json <<POLICY
{\"Version\":\"2012-10-17\",\"Statement\":[
 {\"Effect\":\"Allow\",\"Action\":[\"s3:ListBucket\",\"s3:GetBucketLocation\"],\"Resource\":[\"arn:aws:s3:::\${bucket}\"]},
 {\"Effect\":\"Allow\",\"Action\":[\"s3:PutObject\",\"s3:GetObject\",\"s3:DeleteObject\"],\"Resource\":[\"arn:aws:s3:::\${bucket}/*\"]}]}
POLICY
  ## add/create overwrite an existing user/policy; attach fails if attached:
  mc admin user add e2e \${bucket} \"\${secret}\" >/dev/null
  mc admin policy create e2e \${bucket} /policy/\${bucket}.json >/dev/null
  mc admin policy attach e2e \${bucket} --user \${bucket} >/dev/null 2>&1 || true
  echo \"S3 bucket ready: \${bucket} (user \${bucket})\"
done
pset S3_HOST minio.${E2E_ROOT_DOMAIN}
rm -rf \${pdir}"
}

install_whoami_instance() {
    ## install_whoami_instance <instance> <host> [VAR=value ...] - an extra
    ## whoami instance for a test (the plain whoami instance is unchanged):
    local inst="$1" host="$2"; shift 2
    local envf="whoami/.env_${E2E_NAME}_${inst}" vars="" v
    for v in "$@"; do vars+=" $(printf '%q' "${v}")"; done
    echo "Installing whoami instance '${inst}' (${host}) ..."
    e2e_remote_sh "test -f ${envf} || make -C whoami config-dist instance=${inst}
_scripts/reconfigure ${envf} WHOAMI_TRAEFIK_HOST=${host} WHOAMI_INSTANCE=${inst}${vars}
make -C whoami override instance=${inst}
make -C whoami install instance=${inst}
make -C whoami wait TIMEOUT=${E2E_TIMEOUT} instance=${inst}"
}

platform_setup_oauth2_whoami() {
    ## whoami with OAuth2 turned on, authorized for the e2e team only:
    install_whoami_instance "${E2E_OAUTH2_INSTANCE}" "$(E2E_OAUTH2_HOST)" \
        WHOAMI_OAUTH2=true "WHOAMI_OAUTH2_AUTHORIZED_GROUP=${E2E_OIDC_ORG}:${E2E_OIDC_TEAM}" \
        "WHOAMI_IP_SOURCERANGE=${APP_SOURCERANGE}"
}

platform_setup_tor_whoami() {
    ## whoami published as a Tor hidden service. The tor project's nginx
    ## proxies onion traffic to Traefik from 127.0.0.1, so this instance
    ## admits loopback as well as the test's source range:
    install_whoami_instance "${E2E_TOR_INSTANCE}" "$(E2E_TOR_HOST)" \
        "WHOAMI_IP_SOURCERANGE=${APP_SOURCERANGE},127.0.0.1/32"
}

## -------------------------------------------------------------------------
## Consumer preparation (just before 'make install')
## -------------------------------------------------------------------------

step_ca_init_snippet() {
    ## Initialize the CA once (init-ca refuses if its volume exists), and
    ## keep the admin provisioner password it prints (it is shown only then):
    cat <<EOF
$(platform_remote_prelude)
if ! make -C step-ca check-volume instance=default; then
  log=\$(mktemp)
  make -C step-ca init-ca instance=default 2>&1 | tee \${log}
  pw=\$(sed 's/\x1b\[[0-9;]*m//g' \${log} | grep -oP 'CA administrative password is: \K\S+' | tail -n 1)
  rm -f \${log}
  test -n "\${pw}" || { echo "ERROR: init-ca printed no admin password"; exit 1; }
  pset STEP_CA_PROVISIONER_PASSWORD "\${pw}"
fi
test -n "\$(pget STEP_CA_PROVISIONER_PASSWORD)" || { echo "ERROR: the step-ca admin password is unknown (destroy the step-ca volume to re-init)"; exit 1; }
EOF
}

app_platform_pre_install() {
    ## app_platform_pre_install <app> - print a remote snippet that prepares
    ## an app for the platform services it uses:
    local app="$1" host="$1.${E2E_ROOT_DOMAIN}"
    case "${app}" in
        ## The Step-CA trust step of its 'make config' (config-dist skips the
        ## hook): copy Traefik's TRAEFIK_STEP_CA_* settings:
        oauth2-proxy) echo "(cd oauth2-proxy && ENV_FILE=.env_${E2E_NAME}_default ROOT_DIR=.. bash ./configure_step_ca.sh)" ;;
        step-ca) step_ca_init_snippet ;;
        mosquitto)
            ## Per-context ACL (gitignored): the e2e client may use e2e/#:
            cat <<EOF
mkdir -p mosquitto/config/template/context/${E2E_NAME}
printf 'user e2e.clients.${host}\ntopic readwrite e2e/#\n' > mosquitto/config/template/context/${E2E_NAME}/acl.conf
EOF
            step_ca_token_snippet mosquitto MOSQUITTO "${host}" ;;
        nats)
            step_ca_token_snippet nats NATS "${host}" ;;
    esac
}

step_ca_token_snippet() {
    ## step_ca_token_snippet <app> <PREFIX> <host> - mint a fresh one-time
    ## token, but only if the app's certs volume has no key yet (the token is
    ## only used to create the first certificate, and expires in 30m):
    local app="$1" prefix="$2" host="$3"
    cat <<EOF
$(platform_remote_prelude)
## (Check without creating the volume: compose should create it.)
if docker volume inspect ${app}_certs >/dev/null 2>&1 && \
   docker run --rm -v ${app}_certs:/c alpine test -f /c/${host}.key 2>/dev/null; then
  echo "${app}: certificate already issued; no new step-ca token needed."
else
  ## The app's step-cli redeems the token once, with no retry: make sure
  ## step-ca answers on its public URL (through Traefik) first:
  for i in \$(seq 1 30); do
    curl -sfk -o /dev/null --max-time 5 https://step-ca.${E2E_ROOT_DOMAIN}/health && break
    echo "Waiting for https://step-ca.${E2E_ROOT_DOMAIN}/health ..."; sleep 2
  done
  echo "${app}: minting a one-time step-ca token for ${host} ..."
  stepca_pw
  ## The token's audience is the CA URL it is minted for, and the app's
  ## step-cli redeems it there, so use the public URL (not localhost):
  token=\$(stepca step ca token ${host} --provisioner admin --password-file \${STEP_PW} \
    --ca-url https://step-ca.${E2E_ROOT_DOMAIN} --root /home/step/certs/root_ca.crt)
  _scripts/reconfigure ${app}/.env_${E2E_NAME}_default ${prefix}_STEP_CA_TOKEN="\${token}" >/dev/null
fi
EOF
}

## -------------------------------------------------------------------------
## Functional tests (after an app's route verifies)
## -------------------------------------------------------------------------

app_functional_tests() {
    ## app_functional_tests <app> - append extra result rows to RESULTS:
    case "$1" in
        mosquitto) test_mosquitto ;;
        nats) test_nats ;;
        oauth2-proxy) test_oauth2 oauth2-proxy "https://$(E2E_OAUTH2_HOST)/"
                      test_oauth2_proxy_step_ca ;;
        woodpecker) test_oauth2 woodpecker "https://woodpecker.${E2E_ROOT_DOMAIN}/" ;;
        s3-proxy) test_s3_proxy ;;
        copyparty) test_copyparty ;;
        nextcloud) test_nextcloud_backup ;;
        sysbox-systemd) test_sysbox_systemd ;;
        tor) test_tor ;;
        step-ca) test_traefik_step_ca ;;
    esac
}

## Apps that are themselves a database, kept on UTC on purpose:
TZ_EXEMPT_APPS="postgresql"

test_containers() {
    ## test_containers <app> - per-container checks of every running container
    ## of the app (all instances), in one remote call:
    ##  * OOM: a container the kernel killed for memory records an <app>:oom
    ##    FAIL row (only when found). Many apps share one droplet, so memory
    ##    pressure otherwise shows up as an unrelated-looking failure.
    ##  * timezone: the container follows the root DEFAULT_TIMEZONE
    ##    (E2E_TIMEZONE); always records an <app>:timezone row.
    ## Per container:
    ##   ok      - TZ env matches, and `date +%z` inside gives the expected offset
    ##   na      - TZ env matches, but the image has no `date` to confirm it
    ##   missing - no TZ env at all (database/cache sidecars stay on UTC)
    ##   bad     - TZ env differs, or the image ignores it (no tzdata)
    ## Records FAIL if any is bad, or if no container has TZ at all (unless
    ## the app is in TZ_EXEMPT_APPS); SKIP if the app has no running
    ## containers; else PASS. Returns 1 on any FAIL.
    local app="$1" url="tz://${E2E_TIMEZONE}" out
    out=$(e2e_remote_sh "app=$(printf '%q' "${app}") tz=$(printf '%q' "${E2E_TIMEZONE}")
$(cat <<'EOF'
set +e; trap - ERR
want=$(TZ="${tz}" date +%z)
ok=0; na=0; missing=0; bad=""; oom=""
for c in $(docker ps --format '{{.Names}}|{{.Label "com.docker.compose.project"}}' \
           | awk -F'|' -v p="${app}" '$2==p || index($2, p"_")==1 {print $1}'); do
    [ "$(docker inspect -f '{{.State.OOMKilled}}' "${c}")" = true ] && oom="${oom} ${c}"
    ctz=$(docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "${c}" | sed -n 's/^TZ=//p')
    if [ -z "${ctz}" ]; then missing=$((missing+1)); continue; fi
    if [ "${ctz}" != "${tz}" ]; then bad="${bad} ${c}:TZ=${ctz}"; continue; fi
    off=$(docker exec "${c}" date +%z 2>/dev/null) || off=
    case "${off}" in [+-][0-9][0-9][0-9][0-9]) ;; *) off= ;; esac
    if [ -z "${off}" ]; then na=$((na+1))
    elif [ "${off}" = "${want}" ]; then ok=$((ok+1))
    else bad="${bad} ${c}:${off}"; fi
done
echo "TZCHECK ${ok} ${na} ${missing} want=${want}${bad}"
echo "OOMCHECK${oom}"
EOF
)" 2>/dev/null || true)
    local oom
    oom=$(grep -m1 '^OOMCHECK' <<< "${out}" | sed 's/^OOMCHECK *//' || true)
    out=$(grep -m1 '^TZCHECK ' <<< "${out}" || true)
    local rc=0
    if [[ -n "${oom}" ]]; then
        record_test FAIL "${app}:oom" "oom://${app}" "OOM-killed: ${oom:0:90}"
        rc=1
    fi
    if [[ -z "${out}" ]]; then
        record_test FAIL "${app}:timezone" "${url}" "timezone check failed to run"
        return 1
    fi
    local _ ok na missing rest
    read -r _ ok na missing rest <<< "${out}"
    local detail="ok=${ok} na=${na} missing=${missing} ${rest}"
    detail="${detail:0:100}"
    ## rest is "want=<offset>" followed by any bad containers:
    if [[ "${rest}" == *" "* ]]; then
        record_test FAIL "${app}:timezone" "${url}" "${detail}"
        return 1
    elif (( ok + na + missing == 0 )); then
        record_test SKIP "${app}:timezone" "${url}" "no running containers"
    elif (( ok + na == 0 )) && [[ " ${TZ_EXEMPT_APPS} " != *" ${app} "* ]]; then
        record_test FAIL "${app}:timezone" "${url}" "no TZ configured (${detail})"
        return 1
    else
        record_test PASS "${app}:timezone" "${url}" "${detail}"
    fi
    return ${rc}
}

record_test() {
    ## record_test <STATUS> <app:check> <url> <detail>
    RESULTS+=("$1|$2|$3|$4|-")
    echo "$1 $2 ($4)"
}

run_remote_checks() {
    ## run_remote_checks <app> <url> <snippet> - run a snippet that prints
    ## "CHECK <name> <PASS|FAIL> <detail>" lines; record each one:
    local app="$1" url="$2" out name st detail
    out=$(e2e_remote_sh "$3" 2>/dev/null || true)
    if ! grep -q '^CHECK ' <<< "${out}"; then
        record_test FAIL "${app}:tests" "${url}" "test script failed"
        return
    fi
    while read -r _ name st detail; do
        record_test "${st}" "${app}:${name}" "${url}" "${detail}"
    done < <(grep '^CHECK ' <<< "${out}")
}

client_certs_snippet() {
    ## client_certs_snippet <dir> <cn...> - issue short-lived client certs
    ## from step-ca into <dir> (<name>.crt/.key, name = first CN label):
    local dir="$1"; shift
    local cn name
    echo "$(platform_remote_prelude)"
    echo "mkdir -p ${dir}; chmod 755 ${dir}"
    echo "stepca_pw"
    echo "stepca cat /home/step/certs/root_ca.crt > ${dir}/root_ca.crt"
    for cn in "$@"; do
        name="${cn%%.*}"
        cat <<EOF
stepca step ca certificate ${cn} /tmp/${name}.crt /tmp/${name}.key --provisioner admin \\
  --provisioner-password-file \${STEP_PW} \${STEP_ARGS} --not-after 1h --force >/dev/null
stepca cat /tmp/${name}.crt > ${dir}/${name}.crt
stepca cat /tmp/${name}.key > ${dir}/${name}.key
stepca rm -f /tmp/${name}.crt /tmp/${name}.key
EOF
    done
    echo "chmod 644 ${dir}/*"
}

test_mosquitto() {
    local host="mosquitto.${E2E_ROOT_DOMAIN}" d='$HOME/.cache/e2e-mqtt'
    run_remote_checks mosquitto "mqtts://${host}:8883" "$(client_certs_snippet "${d}" "e2e.clients.${host}" "outsider.clients.${host}")
## Checks may fail; report them instead of aborting:
set +e; trap - ERR
check() { if [ \"\$2\" = 0 ]; then echo \"CHECK \$1 PASS \$3\"; else echo \"CHECK \$1 FAIL \$3\"; fi; }
mq() { docker run --rm --network host -v ${d}:/c:ro eclipse-mosquitto:2 \"\$@\"; }
srv='-h ${host} -p 8883 --cafile /c/root_ca.crt'
as_e2e='--cert /c/e2e.crt --key /c/e2e.key'
as_out='--cert /c/outsider.crt --key /c/outsider.key'
## 1. Publish/subscribe on an ACL-allowed topic:
mq mosquitto_sub \${srv} \${as_e2e} -t e2e/test -C 1 -W 20 > ${d}/got 2>&1 & pid=\$!
sleep 3
mq mosquitto_pub \${srv} \${as_e2e} -t e2e/test -m hello-e2e >/dev/null 2>&1 || true
wait \${pid} || true
grep -qx hello-e2e ${d}/got; check pubsub \$? \"e2e/test round trip\"
## 2. No client certificate: the TLS handshake must be refused:
rc=0; mq mosquitto_pub \${srv} -t e2e/test -m nocert >/dev/null 2>&1 || rc=\$?
[ \${rc} -ne 0 ]; check no-cert-rejected \$? \"exit \${rc}\"
## 3. A valid cert not in the ACL can connect, but its messages are dropped:
mq mosquitto_sub \${srv} \${as_e2e} -t e2e/test -C 1 -W 8 > ${d}/got 2>&1 & pid=\$!
sleep 3
mq mosquitto_pub \${srv} \${as_out} -t e2e/test -m from-outsider >/dev/null 2>&1 || true
wait \${pid} || true
! grep -qx from-outsider ${d}/got; check acl-denies-outsider \$? \"outsider publish not delivered\""
}

test_nats() {
    local host="nats.${E2E_ROOT_DOMAIN}" d='$HOME/.cache/e2e-nats'
    run_remote_checks nats "tls://${host}:4222" "$(client_certs_snippet "${d}" "e2e.clients.${host}" "outsider.clients.${host}")
## Checks may fail; report them instead of aborting:
set +e; trap - ERR
check() { if [ \"\$2\" = 0 ]; then echo \"CHECK \$1 PASS \$3\"; else echo \"CHECK \$1 FAIL \$3\"; fi; }
nb() { docker run --rm --network host -v ${d}:/c:ro natsio/nats-box:latest timeout 20 \"\$@\"; }
srv='--server tls://${host}:4222 --tlsca /c/root_ca.crt'
as_e2e='--tlscert /c/e2e.crt --tlskey /c/e2e.key'
as_out='--tlscert /c/outsider.crt --tlskey /c/outsider.key'
## 1. Publish/subscribe on an authorized subject:
nb nats \${srv} \${as_e2e} sub e2e.test --count 1 --raw > ${d}/got 2>&1 & pid=\$!
sleep 3
nb nats \${srv} \${as_e2e} pub e2e.test hello-e2e >/dev/null 2>&1 || true
wait \${pid} || true
grep -qx hello-e2e ${d}/got; check pubsub \$? \"e2e.test round trip\"
## 2. No client certificate: refused:
rc=0; nb nats \${srv} pub e2e.test nocert >/dev/null 2>&1 || rc=\$?
[ \${rc} -ne 0 ]; check no-cert-rejected \$? \"exit \${rc}\"
## 3. A valid cert whose CN is not a configured user: refused:
rc=0; nb nats \${srv} \${as_out} pub e2e.test outsider >/dev/null 2>&1 || rc=\$?
[ \${rc} -ne 0 ]; check unknown-user-rejected \$? \"exit \${rc}\"
## 4. An authorized user subscribing outside its subjects: denied:
nb nats \${srv} \${as_e2e} sub forbidden.test --count 1 > ${d}/denied 2>&1 || true
grep -qi 'permissions violation' ${d}/denied; check subject-denied \$? \"sub forbidden.test\""
}

test_oauth2() {
    ## test_oauth2 <oauth2-proxy|woodpecker> <url> - the login flow runs from
    ## this machine (outside the droplet), like a browser would: see
    ## oauth2_flow.py for the checks:
    local target="$1" url="$2" out name st detail
    local member_pw outsider_pw
    member_pw=$(platform_get OIDC_MEMBER_PASSWORD)
    outsider_pw=$(platform_get OIDC_OUTSIDER_PASSWORD)
    local insecure=()
    [[ "${E2E_ACME_CA}" == *staging* ]] && insecure=(--insecure)
    out=$(E2E_MEMBER_PASSWORD="${member_pw}" E2E_OUTSIDER_PASSWORD="${outsider_pw}" \
          uv run --quiet --no-project --with requests python3 -I "${E2E_DIR}/lib/oauth2_flow.py" \
          --target "${target}" --app-url "${url}" --root-domain "${E2E_ROOT_DOMAIN}" --ip "${DROPLET_IP}" \
          --member "${E2E_OIDC_MEMBER}" --outsider "${E2E_OIDC_OUTSIDER}" "${insecure[@]}" 2>&1 || true)
    echo "${out}" | grep -v '^CHECK ' || true
    if ! grep -q '^CHECK ' <<< "${out}"; then
        record_test FAIL "${target}:login-flow" "${url}" "test script failed"
        return
    fi
    while read -r _ name st detail; do
        record_test "${st}" "${target}:${name}" "${url}" "${detail}"
    done < <(grep '^CHECK ' <<< "${out}")
}

test_s3_proxy() {
    ## Put an object in the bucket with mc, then read it back through
    ## s3-proxy's HTTPS route:
    local url="https://s3-proxy.${E2E_ROOT_DOMAIN}/e2e-probe.txt" got token
    token="e2e-$(date +%s)"
    e2e_remote_sh "$(platform_remote_prelude)
$(minio_prelude)
echo ${token} | docker run --rm -i --network host -e MC_HOST_e2e=\"\${mc_host}\" ${MC_IMAGE} \
  $([[ "${E2E_ACME_CA}" == *staging* ]] && echo --insecure) pipe e2e/\$(pget S3PROXY_S3_BUCKET)/e2e-probe.txt >/dev/null" >/dev/null 2>&1 \
        || { record_test FAIL s3-proxy:get-object "${url}" "could not upload the test object"; return; }
    local curl_args=(-s --max-time 20 --resolve "s3-proxy.${E2E_ROOT_DOMAIN}:443:${DROPLET_IP}")
    [[ "${E2E_ACME_CA}" == *staging* ]] && curl_args+=(-k)
    got=$(curl "${curl_args[@]}" "${url}" || true)
    if [[ "${got}" == "${token}" ]]; then
        record_test PASS s3-proxy:get-object "${url}" "object served from minio"
    else
        record_test FAIL s3-proxy:get-object "${url}" "got: ${got:0:40}"
    fi
}

test_copyparty() {
    ## Log in as the test accounts (see app_generated_vars), then check the
    ## per-user home folders and the path permissions (see app_test_vars):
    CP_HOST="copyparty.${E2E_ROOT_DOMAIN}"
    CP_BASE="https://${CP_HOST}"
    local env_file="copyparty/.env_${E2E_NAME}_default" users
    users=$(e2e_remote_sh "_scripts/dotenv -f ${env_file} get COPYPARTY_USERS" 2>/dev/null)
    CP_ADMIN_PW=$(e2e_remote_sh "_scripts/dotenv -f ${env_file} get COPYPARTY_ADMIN_PASSWORD" 2>/dev/null)
    CP_ALICE_PW=$(tr ',' '\n' <<< "${users}" | grep -oP '^e2e-alice:\K.*' || true)
    CP_BOB_PW=$(tr ',' '\n' <<< "${users}" | grep -oP '^e2e-bob:\K.*' || true)
    if [[ -z "${CP_ALICE_PW}" || -z "${CP_BOB_PW}" || -z "${CP_ADMIN_PW}" ]]; then
        record_test FAIL copyparty:login "${CP_BASE}/" "could not read test account passwords"
        return
    fi
    CP_CURL_ARGS=(-s --max-time 20 --resolve "${CP_HOST}:443:${DROPLET_IP}")
    [[ "${E2E_ACME_CA}" == *staging* ]] && CP_CURL_ARGS+=(-k)
    ## The probe file is uploaded under its own name:
    CP_PROBE_DIR=$(mktemp -d)
    CP_PROBE="e2e-probe-$(date +%s).txt"
    echo "${CP_PROBE}" > "${CP_PROBE_DIR}/${CP_PROBE}"
    ## Each step expects a few 403s; copyparty bans an IP for a day after
    ## more than 9 in 2 minutes (--ban-403), so keep the total at 9 or less:
    test_copyparty_homes
    test_copyparty_paths
    test_copyparty_admin
    rm -rf "${CP_PROBE_DIR}"
}

cp_code() {
    ## cp_code <password> <curl args...> - print the HTTP status code:
    local pw="$1"; shift
    curl "${CP_CURL_ARGS[@]}" -o /dev/null -w '%{http_code}' ${pw:+-H "PW: ${pw}"} "$@" || true
}

cp_upload() {
    ## cp_upload <password> <dir path> - upload the probe file, print the code:
    cp_code "$1" -T "${CP_PROBE_DIR}/${CP_PROBE}" "${CP_BASE}$2"
}

cp_list() {
    ## cp_list <password> <dir path> - list a folder, print the code:
    cp_code "$1" "${CP_BASE}$2?ls"
}

cp_expect() {
    ## cp_expect <check> <path> <expected code> <got code> <detail>
    if [[ "$4" == "$3" ]]; then
        record_test PASS "copyparty:$1" "${CP_BASE}$2" "$5: $4"
    else
        record_test FAIL "copyparty:$1" "${CP_BASE}$2" "$5: expected $3, got $4"
    fi
}

test_copyparty_homes() {
    ## COPYPARTY_ENABLE_USER_HOMES: each account gets a private
    ## /home/{username}; only its owner (and the admin) may use it:
    local h=/home/e2e-alice/
    cp_expect owner-upload ${h} 201 "$(cp_upload "${CP_ALICE_PW}" ${h})" "alice uploads to her home"
    cp_expect other-upload ${h} 403 "$(cp_upload "${CP_BOB_PW}" ${h})" "bob uploads to alice's home"
    cp_expect other-list ${h} 403 "$(cp_list "${CP_BOB_PW}" ${h})" "bob lists alice's home"
    cp_expect anon-list ${h} 403 "$(cp_list "" ${h})" "anonymous lists alice's home"
    cp_expect admin-list ${h} 200 "$(cp_list "${CP_ADMIN_PW}" ${h})" "admin lists alice's home"
    ## A user listing /home must see only their own folder:
    local dirs
    dirs=$(curl "${CP_CURL_ARGS[@]}" -H "PW: ${CP_BOB_PW}" "${CP_BASE}/home/?ls" | jq -r '[.dirs[].href] | join(",")' 2>/dev/null || true)
    if [[ "${dirs}" == "e2e-bob/" ]]; then
        record_test PASS copyparty:home-isolation "${CP_BASE}/home/" "bob sees only: ${dirs}"
    else
        record_test FAIL copyparty:home-isolation "${CP_BASE}/home/" "bob sees: ${dirs:-nothing}"
    fi
}

test_copyparty_paths() {
    ## COPYPARTY_PERMISSIONS: a path on the data volume, a nested path that
    ## doesn't inherit its parent's permissions, and an external volume:
    local t=/e2e-team/ n=/e2e-team/alice-only/ x=/e2e-ext/
    cp_expect team-upload ${t} 201 "$(cp_upload "${CP_ALICE_PW}" ${t})" "alice uploads to the team folder"
    cp_expect team-upload-2 ${t} 201 "$(cp_upload "${CP_BOB_PW}" ${t}bob/)" "bob uploads to the team folder"
    cp_expect team-anon-list ${t} 403 "$(cp_list "" ${t})" "anonymous lists the team folder"
    cp_expect nested-upload ${n} 201 "$(cp_upload "${CP_ALICE_PW}" ${n})" "alice uploads to /e2e-team/alice-only"
    cp_expect nested-no-inherit ${n} 403 "$(cp_list "${CP_BOB_PW}" ${n})" "bob lists /e2e-team/alice-only"
    cp_expect nested-admin ${n} 200 "$(cp_list "${CP_ADMIN_PW}" ${n})" "admin lists /e2e-team/alice-only"
    cp_expect ext-upload ${x} 201 "$(cp_upload "${CP_ALICE_PW}" ${x})" "alice uploads to the external volume"
    cp_expect ext-read-only ${x} 403 "$(cp_upload "${CP_BOB_PW}" ${x})" "bob (read only) uploads to the external volume"
    cp_expect ext-list ${x} 200 "$(cp_list "${CP_BOB_PW}" ${x})" "bob lists the external volume"
    ## The uploads must land on the right storage: the data volume, and
    ## the external volume's host directory:
    local out
    out=$(e2e_remote_sh "$(platform_remote_prelude)
c=\$(container_of copyparty copyparty)
docker exec \"\${c}\" test -f /data/e2e-team/${CP_PROBE} && echo DATA_OK
test -f ${E2E_COPYPARTY_EXT_DIR}/${CP_PROBE} && echo EXT_OK" 2>/dev/null || true)
    if grep -q DATA_OK <<< "${out}"; then
        record_test PASS copyparty:team-storage "${CP_BASE}${t}" "stored in the data volume at /data/e2e-team"
    else
        record_test FAIL copyparty:team-storage "${CP_BASE}${t}" "upload not found at /data/e2e-team"
    fi
    if grep -q EXT_OK <<< "${out}"; then
        record_test PASS copyparty:ext-storage "${CP_BASE}${x}" "stored on the host at ${E2E_COPYPARTY_EXT_DIR}"
    else
        record_test FAIL copyparty:ext-storage "${CP_BASE}${x}" "upload not found at ${E2E_COPYPARTY_EXT_DIR} on the host"
    fi
}
test_copyparty_admin() {
    ## A user's 'a' permission on their home must not grant server-wide
    ## powers (the config sets no-reload and no-stack), but it does let
    ## them create share links, which the admin (shr-adm) can see:
    cp_expect user-no-stack / 403 "$(cp_code "${CP_ALICE_PW}" "${CP_BASE}/?stack")" "alice views the server thread list"
    cp_expect user-no-reload / 403 "$(cp_code "${CP_ALICE_PW}" "${CP_BASE}/?reload=cfg")" "alice reloads the server config"
    local key="e2e-share-$(date +%s)"
    cp_expect user-share /share/ 201 "$(cp_code "${CP_ALICE_PW}" -H 'Content-Type: application/json' \
        --data "{\"k\":\"${key}\",\"vp\":[\"/home/e2e-alice/\"],\"pw\":\"\",\"exp\":\"60\",\"perms\":[\"read\"]}" \
        "${CP_BASE}/?share")" "alice shares her home"
    if curl "${CP_CURL_ARGS[@]}" -H "PW: ${CP_ADMIN_PW}" "${CP_BASE}/?shares" | grep -q "${key}"; then
        record_test PASS copyparty:admin-sees-shares "${CP_BASE}/?shares" "admin sees alice's share"
    else
        record_test FAIL copyparty:admin-sees-shares "${CP_BASE}/?shares" "alice's share is missing from the admin's list"
    fi
}


test_nextcloud_backup() {
    ## The restic container initializes its repository in the bucket on
    ## start; run one backup now and check a snapshot landed in minio:
    run_remote_checks nextcloud "s3://minio.${E2E_ROOT_DOMAIN}/e2e-nextcloud" "$(platform_remote_prelude)
$(minio_prelude)
set +e; trap - ERR
check() { if [ \"\$2\" = 0 ]; then echo \"CHECK \$1 PASS \$3\"; else echo \"CHECK \$1 FAIL \$3\"; fi; }
bucket=\$(pget NEXTCLOUD_S3_BUCKET)
docker exec \$(container_of nextcloud data_backup) /bin/backup > /tmp/e2e-nc-backup.log 2>&1
check restic-backup \$? \"/bin/backup in data_backup\"
n=\$(mc ls -r e2e/\${bucket}/ 2>/dev/null | grep -c '/data/snapshots/')
[ \"\${n:-0}\" -ge 1 ]; check snapshot-in-bucket \$? \"\${n:-0} snapshot(s)\""
}

test_sysbox_systemd() {
    ## The container runs under sysbox, with systemd as PID 1 and booted:
    run_remote_checks sysbox-systemd "container://sysbox-systemd" "$(platform_remote_prelude)
set +e; trap - ERR
check() { if [ \"\$2\" = 0 ]; then echo \"CHECK \$1 PASS \$3\"; else echo \"CHECK \$1 FAIL \$3\"; fi; }
c=\$(container_of sysbox-systemd linux)
rt=\$(docker inspect -f '{{.HostConfig.Runtime}}' \${c})
[ \"\${rt}\" = sysbox-runc ]; check runtime \$? \"runtime=\${rt}\"
pid1=\$(docker exec \${c} cat /proc/1/comm)
[ \"\${pid1}\" = systemd ]; check systemd-pid1 \$? \"pid1=\${pid1}\"
## 'degraded' means booted with some unit failed (common in containers):
state=\$(timeout 90 docker exec \${c} systemctl is-system-running --wait 2>/dev/null)
case \"\${state}\" in running|degraded) ok=0 ;; *) ok=1 ;; esac
check systemd-booted \${ok} \"state=\${state}\""
}

test_traefik_step_ca() {
    ## Traefik bootstrapped the platform step-ca (see
    ## platform_setup_traefik_step_ca): its saved root matches the CA's:
    run_remote_checks step-ca "traefik://step-ca" "$(platform_remote_prelude)
set +e; trap - ERR
check() { if [ \"\$2\" = 0 ]; then echo \"CHECK \$1 PASS \$3\"; else echo \"CHECK \$1 FAIL \$3\"; fi; }
t=\$(container_of traefik traefik)
want=\$(stepca step certificate fingerprint /home/step/certs/root_ca.crt)
got=\$(docker exec \${t} step certificate fingerprint /certs/step_ca_root.crt 2>/dev/null)
[ -n \"\${want}\" ] && [ \"\${got}\" = \"\${want}\" ]; check traefik-trusts-root \$? \"root \${got:0:16}...\"
docker exec \${t} sh -c 'openssl x509 -in /certs/step_ca_intermediate.crt -noout -text | grep -q CA:TRUE' 2>/dev/null
check traefik-has-intermediate \$? \"for mTLS client verification\""
}

test_oauth2_proxy_step_ca() {
    ## oauth2-proxy's 'make config' copied Traefik's Step-CA settings
    ## (configure_step_ca.sh), and its image trusts the step-ca root on top
    ## of the public CAs (ZERO_CERTS is not copied). Only when Traefik
    ## trusts step-ca, i.e. step-ca is in the app list:
    [[ ",${E2E_APPS}," == *,step-ca,* ]] || return 0
    run_remote_checks oauth2-proxy "oauth2-proxy://trust" "$(platform_remote_prelude)
set +e; trap - ERR
check() { if [ \"\$2\" = 0 ]; then echo \"CHECK \$1 PASS \$3\"; else echo \"CHECK \$1 FAIL \$3\"; fi; }
env=oauth2-proxy/.env_${E2E_NAME}_default
ok=0
for v in ENABLED ENDPOINT FINGERPRINT; do
  [ \"\$(_scripts/dotenv -f \${env} get OAUTH2_PROXY_STEP_CA_\${v})\" = \"\$(_scripts/dotenv -f traefik/.env_${E2E_NAME}_default get TRAEFIK_STEP_CA_\${v})\" ] || ok=1
done
check step-ca-settings-copied \${ok} \"ENABLED/ENDPOINT/FINGERPRINT match Traefik\"
## The image is built FROM scratch: copy its trust store out:
d=\$(mktemp -d)
docker cp \$(container_of oauth2-proxy oauth2-proxy):/etc/ssl/certs/ca-certificates.crt \${d}/bundle.crt >/dev/null 2>&1
stepca cat /home/step/certs/root_ca.crt > \${d}/root.crt
root=\$(grep -v -- '-----' \${d}/root.crt | tr -d '\\n')
tr -d '\\n' < \${d}/bundle.crt | grep -qF \"\${root}\"; check step-ca-root-trusted \$? \"in the image's CA bundle\"
n=\$(grep -c 'BEGIN CERTIFICATE' \${d}/bundle.crt)
[ \"\${n:-0}\" -gt 50 ]; check public-cas-kept \$? \"\${n:-0} CAs in the bundle\"
rm -rf \${d}"
}

test_tor() {
    ## Fetch whoami through its .onion address with a separate Tor client
    ## (a throwaway container on the droplet). The request travels the real
    ## Tor network: client -> rendezvous -> the tor app -> nginx -> Traefik:
    local host
    host=$(E2E_TOR_HOST)
    run_remote_checks tor "onion://${E2E_TOR_SERVICE}" "$(platform_remote_prelude)
set +e; trap - ERR
check() { if [ \"\$2\" = 0 ]; then echo \"CHECK \$1 PASS \$3\"; else echo \"CHECK \$1 FAIL \$3\"; fi; }
## The service's .onion address (tor writes it once the service is up):
onion=''
for i in \$(seq 1 30); do
  onion=\$(docker exec \$(container_of tor tor) cat /var/lib/tor/${E2E_TOR_SERVICE}/hostname 2>/dev/null)
  [ -n \"\${onion}\" ] && break; sleep 2
done
echo \"\${onion}\" | grep -qE '^[a-z2-7]{56}\\.onion\$'; check onion-address \$? \"\${onion:-none}\"
## Bootstrap a Tor client, then retry while the descriptor propagates:
out=\$(docker run --rm alpine:3 sh -c '
  apk add -q tor curl >/dev/null 2>&1 || exit 2
  tor --SocksPort 9050 --Log \"notice file /tmp/tor.log\" --RunAsDaemon 1 >/dev/null
  for i in \$(seq 1 60); do grep -q \"Bootstrapped 100%\" /tmp/tor.log 2>/dev/null && break; sleep 3; done
  for i in \$(seq 1 20); do
    curl -s --max-time 60 --socks5-hostname 127.0.0.1:9050 http://'\"\${onion}\"'/ && exit 0
    sleep 10
  done
  exit 1' 2>/dev/null)
echo \"\${out}\" | grep -q '^Host: ${host}'; check onion-fetch \$? \"whoami answered over Tor\"
## nginx reaches Traefik over loopback (why 127.0.0.1/32 is allowed):
echo \"\${out}\" | grep -qE '^X-Real-Ip: 127\\.0\\.0\\.1'; check via-local-proxy \$? \"X-Real-Ip from the tor app's nginx\""
}

## -------------------------------------------------------------------------
## Host setup (as root, before an app installs)
## -------------------------------------------------------------------------

SYSBOX_VERSION=0.7.1

app_host_setup() {
    ## app_host_setup <app> - prepare the droplet itself for an app:
    case "$1" in
        sysbox-systemd) host_setup_sysbox ;;
    esac
}

host_setup_sysbox() {
    ## The sysbox runtime (sysbox-runc). Its installer refuses to run while
    ## containers exist if it would have to restart Docker to change the
    ## network config; the bootstrap pins 'bip' and 'default-address-pools'
    ## (remote_bootstrap.sh), so it only reloads Docker and nothing stops:
    if e2e_remote_root "docker info --format '{{json .Runtimes}}' | grep -q sysbox-runc"; then
        echo "sysbox runtime already installed."
        return 0
    fi
    echo "Installing the sysbox runtime (v${SYSBOX_VERSION}) on the droplet ..."
    e2e_remote_root "set -eo pipefail
jq -e '.bip and .\"default-address-pools\"' /etc/docker/daemon.json >/dev/null || {
  echo 'ERROR: /etc/docker/daemon.json lacks bip/default-address-pools; re-run the bootstrap phase.'; exit 1; }
arch=\$(dpkg --print-architecture)
deb=/root/sysbox-ce_${SYSBOX_VERSION}.linux_\${arch}.deb
test -f \${deb} || curl -fsSL -o \${deb} \\
  https://github.com/nestybox/sysbox/releases/download/v${SYSBOX_VERSION}/sysbox-ce_${SYSBOX_VERSION}.linux_\${arch}.deb
DEBIAN_FRONTEND=noninteractive apt-get install -y linux-headers-\$(uname -r) rsync \${deb}
## The runtime is registered with a Docker reload; wait for it:
for i in \$(seq 1 30); do
  docker info --format '{{json .Runtimes}}' | grep -q sysbox-runc && exit 0
  sleep 2
done
echo 'ERROR: sysbox-runc did not show up in docker info'; exit 1"
}
