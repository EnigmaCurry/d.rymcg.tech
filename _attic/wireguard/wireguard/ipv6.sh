#!/usr/bin/with-contenv bash
WG_CONF=/config/wg_confs/wg0.conf

if [[ "$IPV6_ENABLE" == "true" ]]; then
    ## Add IP masquerade (SNAT) rules for IPv6:
    if ! grep "^PostUp.*ip6tables.*" ${WG_CONF} >/dev/null; then
        sed -i 's/^PostUp.*$/&; ip6tables -t nat -A POSTROUTING -o eth+ -j MASQUERADE/g' ${WG_CONF}
        sed -i 's/^PostDown.*$/&; ip6tables -t nat -D POSTROUTING -o eth+ -j MASQUERADE/g' ${WG_CONF}
    fi

    ## Iterate over peer names and add IPV6 addresses based upon the existing IPV4 addresses:
    for peer in $(find /config -type d | grep -Po "/config/peer_\K.*"); do
        PEER_CONF="/config/peer_${peer}/peer_${peer}.conf"
        IPV4=$(grep "^Address =" "${PEER_CONF}" | grep -Po ".*= \K.*")
        NODE_ID=$(echo ${IPV4} | cut -d . -f4)
        IPV6=$(echo ${INTERNAL_SUBNET_IPV6} | sed 's/.$//' | sed "s|.*|&${NODE_ID}|")
        if ! grep "^AllowedIPs.*," ${WG_CONF} >/dev/null; then
            sed -i "s|^AllowedIPs = ${IPV4}/32\$|AllowedIPs = ${IPV4}/32,${IPV6}/128|" ${WG_CONF}
        fi
        if ! grep "^Address.*," ${PEER_CONF} >/dev/null; then
            sed -i "s|^Address = ${IPV4}\$|Address = ${IPV4},${IPV6}|" ${PEER_CONF}
        fi
        rm -f "/config/peer_${peer}/peer_${peer}.png"
    done
fi
