PS1=${debian_chroot:+($debian_chroot)}\u@\h:\w\$
export PATH=${PATH}:${HOME}/git/vendor/enigmacurry/d.rymcg.tech/_scripts/user
eval "$(d.rymcg.tech completion bash)"
