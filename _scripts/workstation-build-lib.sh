#!/bin/bash
## Shared library for workstation build scripts (USB image + install-to-device)
## Source this after funcs.sh. Expects BIN and ROOT_DIR to be set.

AI_ML_PROJECTS=(comfyui open-webui invokeai ollama kokoro)

## Pre-flight check: show what will be included and offer to fetch missing data.
## Expects ARCHIVE_SOURCE to be set by the caller.
## Sets ARCHIVE_IMG_DIR, ISOS_DIR, DOCKER_PKG_DIR.
workstation_archive_preflight() {
    echo "=== Pre-flight check ==="
    echo ""
    MISSING=()

    # Check Docker image archive
    ARCHIVE_IMG_DIR="${ARCHIVE_SOURCE}/images/x86_64"
    if [[ -d "$ARCHIVE_IMG_DIR" ]] && [[ -n "$(ls -A "$ARCHIVE_IMG_DIR" 2>/dev/null)" ]]; then
        count=$(find "$ARCHIVE_IMG_DIR" -name '*.tar.gz' 2>/dev/null | wc -l)
        size=$(du -sh "$ARCHIVE_IMG_DIR" | cut -f1)
        echo "  [x] Docker image archive: $count images ($size)"
    else
        echo "  [ ] Docker image archive: not found"
        MISSING+=("images")
    fi

    # Check ISOs
    ISOS_DIR="${ARCHIVE_SOURCE}/isos"
    if [[ -d "$ISOS_DIR" ]] && [[ -n "$(ls -A "$ISOS_DIR" 2>/dev/null)" ]]; then
        count=$(ls "$ISOS_DIR" | wc -l)
        size=$(du -sh "$ISOS_DIR" | cut -f1)
        echo "  [x] OS images (ISOs): $count files ($size)"
    else
        echo "  [ ] OS images (ISOs): not found"
        MISSING+=("isos")
    fi

    # Check Docker CE packages
    DOCKER_PKG_DIR="${ARCHIVE_SOURCE}/docker-packages"
    if [[ -d "$DOCKER_PKG_DIR" ]] && [[ -n "$(ls -A "$DOCKER_PKG_DIR" 2>/dev/null)" ]]; then
        count=$(find "$DOCKER_PKG_DIR" -name '*.deb' -o -name '*.rpm' 2>/dev/null | wc -l)
        size=$(du -sh "$DOCKER_PKG_DIR" | cut -f1)
        echo "  [x] Docker CE packages: $count packages ($size)"
    else
        echo "  [ ] Docker CE packages: not found"
        MISSING+=("docker-packages")
    fi

    echo ""

    if [[ ${#MISSING[@]} -gt 0 ]]; then
        echo "Some archive data is missing. The image will be built without it"
        echo "unless you download it now."
        echo ""
        for item in "${MISSING[@]}"; do
            case "$item" in
                images)
                    if confirm no "Download Docker image archive? (requires d.rymcg.tech image-archive)"; then
                        d.rymcg.tech image-archive --fail-fast --delete --verbose
                    fi
                    ;;
                isos)
                    if confirm yes "Download OS images (ISOs)?"; then
                        d.rymcg.tech workstation-usb-download-isos
                    fi
                    ;;
                docker-packages)
                    if confirm yes "Download Docker CE packages?"; then
                        d.rymcg.tech workstation-usb-download-docker-packages
                    fi
                    ;;
            esac
        done
        echo ""
    else
        echo "All archive data present."
        echo ""
    fi
}

## Interactive archive category selection + ComfyUI variant picker + manifest generation.
## Expects ARCHIVE_IMG_DIR, ISOS_DIR, DOCKER_PKG_DIR, ARCHIVE_SOURCE to be set.
## Sets MANIFEST_FILE, SELECTED_IMAGE_PROJECTS, COMFYUI_SELECTED_FILES,
## INCLUDE_AI_ML, INCLUDE_SERVICES, INCLUDE_ISOS, INCLUDE_DOCKER_PACKAGES.
workstation_archive_select() {
    CATEGORY_LABELS=()
    CATEGORY_KEYS=()

    # Measure AI/ML images
    _AI_ML_SIZE=0
    _AI_ML_FOUND=false
    for proj in "${AI_ML_PROJECTS[@]}"; do
        proj_dir="$ARCHIVE_IMG_DIR/$proj"
        if [[ -d "$proj_dir" ]] && [[ -n "$(ls -A "$proj_dir" 2>/dev/null)" ]]; then
            _AI_ML_FOUND=true
            _AI_ML_SIZE=$((_AI_ML_SIZE + $(du -sb "$proj_dir" | cut -f1)))
        fi
    done
    if $_AI_ML_FOUND; then
        _ai_ml_gb=$(awk "BEGIN {printf \"%.1f\", $_AI_ML_SIZE / 1073741824}")
        CATEGORY_LABELS+=("Docker images: AI/ML ($_ai_ml_gb GB)")
        CATEGORY_KEYS+=("ai_ml")
    fi

    # Measure service images (everything not in AI_ML_PROJECTS)
    _SERVICES_SIZE=0
    _SERVICES_FOUND=false
    if [[ -d "$ARCHIVE_IMG_DIR" ]]; then
        for proj_dir in "$ARCHIVE_IMG_DIR"/*/; do
            [[ -d "$proj_dir" ]] || continue
            proj_name=$(basename "$proj_dir")
            if ! element_in_array "$proj_name" "${AI_ML_PROJECTS[@]}"; then
                if [[ -n "$(ls -A "$proj_dir" 2>/dev/null)" ]]; then
                    _SERVICES_FOUND=true
                    _SERVICES_SIZE=$((_SERVICES_SIZE + $(du -sb "$proj_dir" | cut -f1)))
                fi
            fi
        done
    fi
    if $_SERVICES_FOUND; then
        _services_gb=$(awk "BEGIN {printf \"%.1f\", $_SERVICES_SIZE / 1073741824}")
        CATEGORY_LABELS+=("Docker images: Services ($_services_gb GB)")
        CATEGORY_KEYS+=("services")
    fi

    # Measure ISOs
    if [[ -d "$ISOS_DIR" ]] && [[ -n "$(ls -A "$ISOS_DIR" 2>/dev/null)" ]]; then
        _isos_bytes=$(du -sb "$ISOS_DIR" | cut -f1)
        _isos_gb=$(awk "BEGIN {printf \"%.1f\", $_isos_bytes / 1073741824}")
        CATEGORY_LABELS+=("OS images / ISOs ($_isos_gb GB)")
        CATEGORY_KEYS+=("isos")
    fi

    # Measure Docker CE packages
    if [[ -d "$DOCKER_PKG_DIR" ]] && [[ -n "$(ls -A "$DOCKER_PKG_DIR" 2>/dev/null)" ]]; then
        _docker_pkg_bytes=$(du -sb "$DOCKER_PKG_DIR" | cut -f1)
        _docker_pkg_mb=$(awk "BEGIN {printf \"%.0f\", $_docker_pkg_bytes / 1048576}")
        CATEGORY_LABELS+=("Docker CE packages ($_docker_pkg_mb MB)")
        CATEGORY_KEYS+=("docker_packages")
    fi

    if [[ ${#CATEGORY_LABELS[@]} -gt 0 ]]; then
        echo "=== Select archive categories ==="
        echo "Deselect categories you don't need to reduce image size."
        echo ""

        # All selected by default
        _DEFAULT_JSON=$(printf '%s\n' "${CATEGORY_LABELS[@]}" | jq -R . | jq -s -c .)
        _exit_code=0
        SELECTED_OUTPUT=$(wizard select --cancel-code=2 --default "$_DEFAULT_JSON" \
            "Select categories to include:" "${CATEGORY_LABELS[@]}") && _exit_code=$? || _exit_code=$?
        if [[ "$_exit_code" == "2" ]]; then
            cancel
        fi
        readarray -t SELECTED <<< "$SELECTED_OUTPUT"

        # Determine what was selected
        INCLUDE_AI_ML=false
        INCLUDE_SERVICES=false
        INCLUDE_ISOS=false
        INCLUDE_DOCKER_PACKAGES=false

        for sel in "${SELECTED[@]}"; do
            case "$sel" in
                "Docker images: AI/ML"*) INCLUDE_AI_ML=true ;;
                "Docker images: Services"*) INCLUDE_SERVICES=true ;;
                "OS images / ISOs"*) INCLUDE_ISOS=true ;;
                "Docker CE packages"*) INCLUDE_DOCKER_PACKAGES=true ;;
            esac
        done

        ## ComfyUI GPU variant selection
        COMFYUI_SELECTED_FILES=()
        COMFYUI_DIR="$ARCHIVE_IMG_DIR/comfyui"
        if $INCLUDE_AI_ML && [[ -d "$COMFYUI_DIR" ]] && [[ -n "$(ls -A "$COMFYUI_DIR" 2>/dev/null)" ]]; then
            VARIANT_LABELS=()
            VARIANT_FILES=()
            for f in "$COMFYUI_DIR"/comfyui-comfyui-*_latest.tar.gz; do
                [[ -f "$f" ]] || continue
                fname=$(basename "$f")
                variant=$(echo "$fname" | sed 's/comfyui-comfyui-\(.*\)_latest\.tar\.gz/\1/')
                case "$variant" in
                    rocm) variant_label="ROCm" ;;
                    cuda) variant_label="CUDA" ;;
                    intel) variant_label="Intel" ;;
                    cpu) variant_label="CPU" ;;
                    *) variant_label="$variant" ;;
                esac
                file_size=$(du -sh "$f" | cut -f1)
                VARIANT_LABELS+=("ComfyUI $variant_label ($file_size)")
                VARIANT_FILES+=("$fname")
            done

            if [[ ${#VARIANT_LABELS[@]} -gt 1 ]]; then
                echo ""
                _VARIANT_DEFAULT_JSON=$(printf '%s\n' "${VARIANT_LABELS[@]}" | jq -R . | jq -s -c .)
                _exit_code=0
                VARIANT_OUTPUT=$(wizard select --cancel-code=2 --default "$_VARIANT_DEFAULT_JSON" \
                    "Select ComfyUI GPU variants:" "${VARIANT_LABELS[@]}") && _exit_code=$? || _exit_code=$?
                if [[ "$_exit_code" == "2" ]]; then
                    cancel
                fi
                readarray -t SELECTED_VARIANTS <<< "$VARIANT_OUTPUT"

                for i in "${!VARIANT_LABELS[@]}"; do
                    for sel in "${SELECTED_VARIANTS[@]}"; do
                        if [[ "$sel" == "${VARIANT_LABELS[$i]}" ]]; then
                            COMFYUI_SELECTED_FILES+=("${VARIANT_FILES[$i]}")
                        fi
                    done
                done
            else
                # Only one variant available, include it
                COMFYUI_SELECTED_FILES=("${VARIANT_FILES[@]}")
            fi
        fi

        ## Build archive selection manifest
        SELECTED_IMAGE_PROJECTS=()
        if $INCLUDE_AI_ML; then
            for proj in "${AI_ML_PROJECTS[@]}"; do
                [[ "$proj" == "comfyui" ]] && continue
                proj_dir="$ARCHIVE_IMG_DIR/$proj"
                [[ -d "$proj_dir" ]] && [[ -n "$(ls -A "$proj_dir" 2>/dev/null)" ]] && SELECTED_IMAGE_PROJECTS+=("$proj")
            done
        fi
        if $INCLUDE_SERVICES; then
            for proj_dir in "$ARCHIVE_IMG_DIR"/*/; do
                [[ -d "$proj_dir" ]] || continue
                proj_name=$(basename "$proj_dir")
                if ! element_in_array "$proj_name" "${AI_ML_PROJECTS[@]}"; then
                    [[ -n "$(ls -A "$proj_dir" 2>/dev/null)" ]] && SELECTED_IMAGE_PROJECTS+=("$proj_name")
                fi
            done
        fi

        MANIFEST_FILE=$(mktemp)
        {
            echo "ARCHIVE_ROOT=\"$ARCHIVE_SOURCE\""
            echo "IMAGE_PROJECTS=\"${SELECTED_IMAGE_PROJECTS[*]}\""
            echo "COMFYUI_FILES=\"${COMFYUI_SELECTED_FILES[*]}\""
            echo "INCLUDE_ISOS=$INCLUDE_ISOS"
            echo "INCLUDE_DOCKER_PACKAGES=$INCLUDE_DOCKER_PACKAGES"
        } > "$MANIFEST_FILE"
        echo ""
    fi
}

## Prompt for hostname and username, updating settings.nix if changed.
## Expects ROOT_DIR to be set.
workstation_configure_settings() {
    local settings_file="$ROOT_DIR/nix/workstation/settings.nix"
    local settings_changed=""

    echo ""
    echo "=== System configuration ==="

    local current_host
    current_host=$(grep 'hostName' "$settings_file" | sed 's/.*"\(.*\)".*/\1/')
    read -e -p "Hostname [$current_host]: " ws_host
    ws_host="${ws_host:-$current_host}"
    if [[ "$ws_host" != "$current_host" ]]; then
        sed -i "s/hostName = \"$current_host\"/hostName = \"$ws_host\"/" "$settings_file"
        settings_changed=1
        echo "Updated settings.nix: hostName = \"$ws_host\""
    fi

    echo ""
    echo "=== Admin user account ==="
    echo "This account has sudo (wheel group). Password = username."
    echo "(This is fine for a USB stick — change it after installing to a real system.)"
    local current_user
    current_user=$(grep 'userName' "$settings_file" | sed 's/.*"\(.*\)".*/\1/')
    read -e -p "Admin username [$current_user]: " ws_user
    ws_user="${ws_user:-$current_user}"
    if [[ "$ws_user" != "$current_user" ]]; then
        sed -i "s/userName = \"$current_user\"/userName = \"$ws_user\"/" "$settings_file"
        settings_changed=1
        echo "Updated settings.nix: userName = \"$ws_user\""
    fi

    if [[ -n "$settings_changed" ]]; then
        git -C "$ROOT_DIR" update-index --skip-worktree nix/workstation/settings.nix
    fi
}

## Read a remote URL from settings.nix.
## Expects ROOT_DIR to be set.
## Usage: workstation_remote "repo-name"
workstation_remote() {
    nix eval --raw --file "$ROOT_DIR/nix/workstation/settings.nix" "remotes.\"$1\""
}

## Create bare git repo clones in a temp directory.
## Expects ROOT_DIR to be set.
## Sets BARE_DIR.
workstation_create_bare_repos() {
    echo "=== Creating bare git repo clones ==="
    BARE_DIR=$(mktemp -d)/vendor-git-repos
    mkdir -p "$BARE_DIR"
    git clone --bare "$(git -C "${ROOT_DIR}" rev-parse --show-toplevel)" "$BARE_DIR/d.rymcg.tech"
    git clone --bare "$(workstation_remote sway-home)" "$BARE_DIR/sway-home"
    git clone --bare "$(workstation_remote emacs)" "$BARE_DIR/emacs"
    git clone --bare "$(workstation_remote blog.rymcg.tech)" "$BARE_DIR/blog.rymcg.tech"
    git clone --bare "$(workstation_remote org)" "$BARE_DIR/org"
    echo "Bare repos created in $BARE_DIR"
}

## Run nix build with --override-input vendor-git-repos.
## Expects ROOT_DIR and BARE_DIR to be set.
## Usage: workstation_nix_build FLAKE_ATTR
## Prints the output path to stdout.
workstation_nix_build() {
    local flake_attr="$1"
    nix build "${ROOT_DIR}#${flake_attr}" \
        --override-input vendor-git-repos "path:${BARE_DIR}" \
        --no-link --print-out-paths
}
