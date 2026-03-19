## drt — source this file from ~/.bashrc, ~/.bash_profile, or ~/.zshrc
: "${DRT_GIT_REPO:=https://github.com/EnigmaCurry/d.rymcg.tech.git}"
: "${DRT_BUILD_BRANCH:=master}"
: "${DRT_IMAGE:=localhost/d-rymcg-tech:latest}"

drt() {
  export DRT_GIT_REPO DRT_BUILD_BRANCH DRT_IMAGE
  if ! podman image exists "${DRT_IMAGE}" 2>/dev/null; then
    echo "## First run: building ${DRT_IMAGE}" \
      "from ${DRT_GIT_REPO}#${DRT_BUILD_BRANCH} ..." >&2
    local git_sha
    git_sha=$(git ls-remote "${DRT_GIT_REPO}" "refs/heads/${DRT_BUILD_BRANCH}" | cut -c1-12)
    podman build \
      --network=slirp4netns \
      --build-arg BRANCH="${DRT_BUILD_BRANCH}" \
      --build-arg GIT_REPO="${DRT_GIT_REPO}" \
      --build-arg GIT_SHA="${git_sha:-unknown}" \
      -t "${DRT_IMAGE}" \
      -f _container/Dockerfile \
      "${DRT_GIT_REPO}#${DRT_BUILD_BRANCH}"
  fi
  bash <(podman run --rm --pull=never --net=none "${DRT_IMAGE}" drt) "$@"
}

_drt() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  if [[ "${cur}" == -* ]]; then
    COMPREPLY=($(compgen -W "\
      --init --view --edit --clean --seal --unseal \
      --list --git-init --git --pull --build --extract \
      --image --docker --age-key --ssh-key --ssh-timeout \
      --timeout --no-save --controller-port --net \
      --verbose --version --help" -- "${cur}"))
  else
    local cfg_dir="${HOME}/.config/d.rymcg.tech/config"
    if [[ -d "${cfg_dir}" ]]; then
      local contexts
      contexts=$(ls "${cfg_dir}"/*.sops.env 2>/dev/null \
        | xargs -I{} basename {} .sops.env)
      COMPREPLY=($(compgen -W "${contexts}" -- "${cur}"))
    fi
  fi
}
complete -F _drt drt
