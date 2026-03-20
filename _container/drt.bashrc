## drt — source this file from ~/.bashrc, ~/.bash_profile, or ~/.zshrc
export DRT_GIT_REPO="${DRT_GIT_REPO:-https://github.com/EnigmaCurry/d.rymcg.tech.git}"
export DRT_BUILD_BRANCH="${DRT_BUILD_BRANCH:-master}"
export DRT_IMAGE="${DRT_IMAGE:-localhost/d-rymcg-tech:latest}"
export DRT_INSTALL_EXTRAS="${DRT_INSTALL_EXTRAS:-}"
export DRT_CAP_ADD="${DRT_CAP_ADD:-}"

drt() {
  if ! podman image exists "${DRT_IMAGE}" 2>/dev/null; then
    echo "## First run: building ${DRT_IMAGE}" \
      "from ${DRT_GIT_REPO}#${DRT_BUILD_BRANCH} ..." >&2
    local git_sha
    git_sha=$(git ls-remote "${DRT_GIT_REPO}" "refs/heads/${DRT_BUILD_BRANCH}" | cut -c1-12)
    podman build \
      --build-arg BRANCH="${DRT_BUILD_BRANCH}" \
      --build-arg GIT_REPO="${DRT_GIT_REPO}" \
      --build-arg GIT_SHA="${git_sha:-unknown}" \
      --build-arg INSTALL_EXTRAS="${DRT_INSTALL_EXTRAS}" \
      -t "${DRT_IMAGE}" \
      -f _container/Dockerfile \
      "${DRT_GIT_REPO}#${DRT_BUILD_BRANCH}"
  fi
  # Only inject --cap-add for run actions (not --build, --pull, etc.)
  local _cap_args=()
  local _is_run=true
  local _arg
  for _arg in "$@"; do
    case "${_arg}" in
      --build|--build-force|--pull|--init|--view|--edit|--clean|--list|\
      --seal|--unseal|--git-init|--git|--extract|--help|--version)
        _is_run=false; break ;;
    esac
  done
  if [[ "${_is_run}" == true && -n "${DRT_CAP_ADD}" ]]; then
    local _cap
    for _cap in $(echo "${DRT_CAP_ADD}" | tr ',' ' '); do
      _cap_args+=(--cap-add "${_cap}")
    done
  fi
  bash <(podman run --rm --pull=never --net=none "${DRT_IMAGE}" drt) "${_cap_args[@]+"${_cap_args[@]}"}" "$@"
}

_drt() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  if [[ "${cur}" == -* ]]; then
    COMPREPLY=($(compgen -W "\
      --init --view --edit --clean --seal --unseal \
      --list --git-init --git --pull --build --extract \
      --image --docker --age-key --ssh-key --ssh-timeout \
      --timeout --no-save --controller-port --net --cap-add \
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
