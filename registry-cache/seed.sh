#!/usr/bin/env bash
## Seed registry cache volumes from images already on the Docker server.
## Temporarily runs a writable registry:2 on each cache volume, tags and
## pushes matching images from the daemon, then restarts the cache service.
set -euo pipefail

SEED_PORT=5555
SEED_IMAGE="registry:2"
SEED_PREFIX="registry-cache-seed"

# Registry prefix -> compose service name (longest prefixes first)
PREFIXES=(
    "registry.gitlab.com:gitlab"
    "registry.k8s.io:k8s"
    "public.ecr.aws:ecr"
    "codeberg.org:codeberg"
    "docker.io:dockerhub"
    "ghcr.io:ghcr"
    "quay.io:quay"
    "lscr.io:lscr"
    "gcr.io:gcr"
)

cleanup() {
    for svc in dockerhub ghcr quay gcr k8s gitlab ecr lscr codeberg; do
        docker rm -f "${SEED_PREFIX}-${svc}" 2>/dev/null || true
    done
}
trap cleanup EXIT

get_project_name() {
    docker compose config --format json 2>/dev/null \
        | python3 -c "import sys,json; print(json.load(sys.stdin)['name'])"
}

# Print "service|cache_repo" for a given image repository, or nothing if unknown.
classify() {
    local repo="$1"
    for entry in "${PREFIXES[@]}"; do
        local pfx="${entry%%:*}" svc="${entry##*:}"
        if [[ "$repo" == "${pfx}/"* ]]; then
            echo "${svc}|${repo#${pfx}/}"
            return
        fi
    done
    # No known prefix — Docker Hub if the first path component has no dots.
    local first="${repo%%/*}"
    [[ "$first" == *"."* ]] && return
    if [[ "$repo" != *"/"* ]]; then
        echo "dockerhub|library/${repo}"
    else
        echo "dockerhub|${repo}"
    fi
}

seed_volume() {
    local svc="$1" vol="$2"
    shift 2
    local pairs=("$@")
    local name="${SEED_PREFIX}-${svc}"

    echo ""
    echo "=== ${svc} (${#pairs[@]} images) ==="

    docker compose stop "$svc" 2>/dev/null || true
    docker rm -f "$name" 2>/dev/null || true
    docker run -d --name "$name" \
        -p "${SEED_PORT}:5000" \
        -v "${vol}:/var/lib/registry" \
        "$SEED_IMAGE" >/dev/null

    # Wait for the temp registry to respond.
    local ok=false
    for _ in $(seq 1 30); do
        if docker exec "$name" wget -qO- http://localhost:5000/v2/ &>/dev/null; then
            ok=true; break
        fi
        sleep 0.5
    done
    if ! $ok; then
        echo "  ERROR: seed registry did not start"
        docker rm -f "$name" >/dev/null 2>&1
        docker compose start "$svc" 2>/dev/null || true
        return 1
    fi

    for pair in "${pairs[@]}"; do
        local src="${pair%%|*}" dest="${pair##*|}"
        echo "  ${src}"
        docker tag "$src" "localhost:${SEED_PORT}/${dest}"
        docker push "localhost:${SEED_PORT}/${dest}" >/dev/null 2>&1
        docker rmi "localhost:${SEED_PORT}/${dest}" >/dev/null 2>&1 || true
    done

    docker rm -f "$name" >/dev/null
    docker compose start "$svc" 2>/dev/null || true
}

main() {
    local project
    project=$(get_project_name)
    echo "Project: ${project}"

    # Group images by service.
    declare -A bucket
    while IFS=$'\t' read -r repo tag; do
        [[ "$tag" == "<none>" || "$repo" == "<none>" ]] && continue
        [[ -z "$repo" || -z "$tag" ]] && continue
        local info
        info=$(classify "$repo") || continue
        [[ -z "$info" ]] && continue
        local svc="${info%%|*}" cache_repo="${info##*|}"
        local entry="${repo}:${tag}|${cache_repo}:${tag}"
        if [[ -v bucket[$svc] ]]; then
            bucket[$svc]+=$'\n'"$entry"
        else
            bucket[$svc]="$entry"
        fi
    done < <(docker images --format '{{.Repository}}\t{{.Tag}}')

    if [[ ${#bucket[@]} -eq 0 ]]; then
        echo "No images found to seed."
        exit 0
    fi

    local seeded=0
    for svc in "${!bucket[@]}"; do
        local vol="${project}_cache-${svc}"
        if ! docker volume inspect "$vol" &>/dev/null; then
            echo "Skipping ${svc}: volume ${vol} not found (run make install first)"
            continue
        fi
        local -a imgs
        mapfile -t imgs <<< "${bucket[$svc]}"
        seed_volume "$svc" "$vol" "${imgs[@]}"
        ((seeded++))
    done

    echo ""
    if [[ $seeded -eq 0 ]]; then
        echo "No cache volumes found. Run 'make install' first."
    else
        echo "Seeded ${seeded} registries."
    fi
}

main
