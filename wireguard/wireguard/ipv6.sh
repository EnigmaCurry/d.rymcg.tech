#!/usr/bin/with-contenv bash

if [[ "$IPV6_ENABLE" == "true" ]]; then
    if [[ -f /config/ipv6_already_ran.txt ]]; then
        exit # This script already ran once, don't run it again!
    else
        touch /config/ipv6_already_ran.txt
    fi
    ## Add IP masquerade (SNAT) rules for IPv6:
    sed -i 's/^PostUp.*$/&; ip6tables -t nat -A POSTROUTING -o eth+ -j MASQUERADE/g' /config/wg_confs/wg0.conf
    sed -i 's/^PostDown.*$/&; ip6tables -t nat -D POSTROUTING -o eth+ -j MASQUERADE/g' /config/wg_confs/wg0.conf

    ## Iterate over peer names and add IPV6 addresses based upon the existing IPV4 addresses:
    for peer in $(find /config -type d | grep -Po "/config/peer_\K.*"); do
        IPV4=$(grep "^Address =" "/config/peer_${peer}/peer_${peer}.conf" | grep -Po ".*= \K.*")
        NODE_ID=$(echo ${IPV4} | cut -d . -f4)
        IPV6=$(echo ${INTERNAL_SUBNET_IPV6} | sed 's/.$//' | sed "s|.*|&${NODE_ID}|")
        sed -i "s|^AllowedIPs = ${IPV4}/32\$|AllowedIPs = ${IPV4}/32,${IPV6}/128|" /config/wg_confs/wg0.conf
        sed -i "s|^Address = ${IPV4}\$|Address = ${IPV4},${IPV6}|" "/config/peer_${peer}/peer_${peer}.conf"
        rm -f "/config/peer_${peer}/peer_${peer}.png"
    done
fi
