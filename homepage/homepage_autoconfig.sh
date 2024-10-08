#!/bin/bash

set -e

if [[ "${HOMEPAGE_AUTO_CONFIG}" != "true" ]]; then
    echo "## HOMEPAGE_AUTO_CONFIG=${HOMEPAGE_AUTO_CONFIG}" > /dev/stderr
    echo "## Skipping auto config.." > /dev/stderr
    exit 0
fi

HOMEPAGE_ENABLE_DOCKER=$(${ROOT_DIR}/_scripts/dotenv -f ${ENV_FILE} get HOMEPAGE_ENABLE_DOCKER)
HOMEPAGE_PUBLIC_HTTPS_PORT=$(${ROOT_DIR}/_scripts/dotenv -f ${ENV_FILE} get HOMEPAGE_PUBLIC_HTTPS_PORT)

# Make config dir
config_dir="./homepage/homepage_config"
#config_dir="./homepage/homepage_${DOCKER_CONTEXT}_"$(test -z ${INSTANCE} && echo "default" || echo ${INSTANCE})
# Remove any existing config files from config_dir
rm -rf "${config_dir}"
mkdir -p "${config_dir}"

## images
## ------

mkdir -p "${config_dir}/images/" 
cp -rp ./autoconfig_images/* "${config_dir}/images/" 


## settings.yaml
## -------------

cat <<EOF > "${config_dir}/settings.yaml"
---
# For configuration options and examples, please see:
# https://gethomepage.dev/en/configs/settings

background:
  image: /images/images/crazy-greenblue-waves.jpg
  blur: sm
  saturate: 100
  brightness: 50
  opacity: 100
cardBlur: md
favicon: /images/images/hashbang.png
title: "Homepage (Docker Context: \`${DOCKER_CONTEXT}\`)"
theme: dark
color: slate
headerStyle: boxed
language: en
target: _blank
iconStyle: theme
hideErrors: false
fiveColumns: false
layout:
  Apps:
    style: row
    columns: 5
  Services:
  Infrastructure:
disableCollapse: false
quicklaunch:
    searchDescriptions: true
    hideInternetSearch: false
    hideVisitURL: false
hideVersion: false
# providers is for secrets, and is optional.
# Replace these sample API keys with your own, then reference your secret
# API key in services.yaml.
providers:
  openweathermap: openweathermapapikey
  weatherapi: weatherapiapikey
EOF

# Only show container stats if HOMEPAGE_ENABLE_DOCKER=true
if [[ "${HOMEPAGE_ENABLE_DOCKER}" == true ]]; then
  echo "showStats: true" >> "${config_dir}/settings.yaml"
else
  echo "showStats: false" >> "${config_dir}/settings.yaml"
fi


## bookmarks.yaml
## --------------
cat <<EOF > "${config_dir}/bookmarks.yaml"
---
# For configuration options and examples, please see:
# https://gethomepage.dev/en/configs/bookmarks

- d.rymcg.tech:
    - Github:
        - abbr: d.ry
          href: https://github.com/EnigmaCurry/d.rymcg.tech
          icon: github.png
    - Matrix Chatroom:
        - href: https://matrix.to/#/#d.rymcg.tech:enigmacurry.com
          abbr: Ma
          icon: matrix.png
- Resources:
    - Digital Ocean:
        - abbr: DO
          icon: digital-ocean.png
          href: https://cloud.digitalocean.com/login
    - Mullvad:
        - abbr: MV
          icon: mullvad.png
          href: https://mullvad.net/
EOF


## docker.yaml
## -----------
cat <<EOF > "${config_dir}/docker.yaml"
---
# For configuration options and examples, please see:
# https://gethomepage.dev/en/configs/docker/

#my-docker-1:
#    socket: /var/run/docker.sock
#my-docker-2:
#    host: 127.0.0.1
#    port: 2375

EOF

## In order to expose docker container stats, we need to find a way to determine which of the apps containers to add to the Homepage config (eg., `tiddlywiki-nodejs-s3-proxy-1` or `tiddlywiki-nodejs-tiddlywiki-nodejs-1`) (see docker section near end of services.yaml section)
# Expose docker.sock if HOMEPAGE_ENABLE_DOCKER=true
#if [[ "${HOMEPAGE_ENABLE_DOCKER}" == true ]]; then
#  cat <<EOF >> "${config_dir}/docker.yaml"
#d.rymcg.tech:
#    socket: /var/run/docker.sock
#EOF
#fi


## kubernetes.yaml
## ---------------
cat <<EOF > "${config_dir}/kubernetes.yaml"
---
# sample kubernetes config
EOF


## widgets.yaml
## ------------
cat <<EOF > "${config_dir}/widgets.yaml"
---
# For configuration options and examples, please see:
# https://gethomepage.dev/en/configs/widgets

- logo:
    icon: /images/images/hashbang.png
- greeting:
    text_size: 3xl
    text: "Docker Context: \`${DOCKER_CONTEXT}\`"
- datetime:
    text_size: 2xl
    format:
      dateStyle: short
      timeStyle: short
      hour12: true
- resources:
    label: d.rymcg.tech host
    cpu: true
    memory: true
    disk: /
    uptime: true
    expanded: true
- search:
    provider: duckduckgo
    target: _blank
    focus: false
EOF
# if we want to include the weather widget for the autoconfiguration, we should have Makefile ask for town name, lat/long, timezone, units
#- openmeteo:
#    label: Your Town
#    latitude: -37.427954
#    longitude: 175.959635
#    timezone: Pacific/Auckland
#    units: imperial
#    cache: 15
#EOF


## services.yaml
## -------------
# Create new services.yaml file
echo "- Apps:" > "${config_dir}/services.yaml"

# Determine running containers in the current Docker context
##apps=$(make -sC ${ROOT_DIR} status)
apps=$(docker ps --format {{.Names}})

# Find all .env files for all apps in d.ry using the current Docker context 
mapfile -t env_paths < <(find ${ROOT_DIR} -iname ".env_${DOCKER_CONTEXT}*" -type f)
sorted_env_paths=($(printf '%s\n' "${env_paths[@]}" | sort))

# Split paths of .env files into paths and filenames
for fullpath in "${sorted_env_paths[@]}"; do
  IFS="/" read -ra dirs <<< "$fullpath"
  appdir=${dirs[-2]}
  env_file=${dirs[-1]}
  context_escaped=$(echo "${DOCKER_CONTEXT}" | sed 's/\./\\\./g')
  env_instance=$(echo "${env_file}" | sed "s/\.env_${context_escaped}_\(.*\)/\1/")
  unset env_instance_blank_default
  if [[ "${env_instance}" == "default" ]]; then
    env_instance_blank_default=""
  fi
  #env_instance_escaped=$(echo "${env_instance}" | sed "s/\./\\\./g") # I don't think I need this any more
  #env_instance="${env_instance:-bbb}" # i don't think i need this - don't remember why i added it, probably to debug

  # Ignore parent and "homepage" dirs
  if ! [[ "${appdir}" =~ ^(\.\.|homepage)$ ]]; then
    # The following grep tells us if an app is running, but it will return a line for each container the app is running so this is not useful for determining which container is running the *app* (as opposed to a database or proxy, for example). We probably want to see Homepage display Docker container stats for the container running the app, and not the ancillary containers.
    if [[ "${env_instance}" == "default" ]]; then
      container_running=$(grep -w "${appdir}" <<< "${apps}" || continue)
    else
      container_running=$(grep -w "${appdir}_${env_instance}" <<< "${apps}" || continue)
    fi
    
    # Get the *_TRAEFIK_HOST value from the .env file
    if [[ -n "${container_running}" ]]; then
      port=$([[ "${HOMEPAGE_PUBLIC_HTTPS_PORT}" == '443' ]] && echo '' || echo ':'${HOMEPAGE_PUBLIC_HTTPS_PORT})
      traefik_host=$(${ROOT_DIR}/_scripts/dotenv -f ${fullpath} get $(echo "${appdir}" | tr '[:lower:]' '[:upper:]' | tr '-' '_')"_TRAEFIK_HOST" || echo "#")
      
      # We're assuming there's an icon in the https://github.com/walkxcode/dashboard-icons repo (which Homepage integrates with) matching the app name. It's a safe assumption, but if wrong then the only repercussion is either a broken-image icon, a default "logo" image by Homepage, or no icon at all. The dashboard-icons repo names icons using Kebab Case.
      icon=$(echo "${appdir}" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
      
      # Abbreviation = 1st 2 characters of app name, used if no icon exists
      abbr="${appdir:0:2}"
      
      # Add configs for this app to services.yaml
      cat <<EOF >> "${config_dir}/services.yaml"
    - ${appdir}:
        description: "Instance: \`${env_instance}\`"
        icon: ${icon}.png
        href: https://${traefik_host}${port}
        abbr: ${abbr}
EOF
    ## In order to expose docker container stats, we need to find a way to determine which of the apps containers to add to the Homepage config (eg., `tiddlywiki-nodejs-s3-proxy-1` or `tiddlywiki-nodejs-tiddlywiki-nodejs-1`)
    # Only add docker server if HOMEPAGE_ENABLE_DOCKER=true
#    if [[ "${HOMEPAGE_ENABLE_DOCKER}" == true ]]; then
#      cat <<EOF >> "${config_dir}/services.yaml"
#        server: d.rymcg.tech
#        container: 
#EOF
#    fi
    fi
  fi
done

mkdir -p "${config_dir}"

echo "Homepage configured."
