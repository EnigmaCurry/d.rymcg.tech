#!/command/with-contenv /bin/bash

## Setup the iptables rules for the public peer ports

for port_map in ${PUBLIC_PEER_PORTS//,/ }
do
    IFS='-' read -r -a __conf <<< "${port_map}"
    PEER_IP="${__conf[0]}"
    PEER_PORT="${__conf[1]}"
    PUBLIC_PORT="${__conf[2]}"
    PORT_TYPE="${__conf[3]}"
    if [[ "${PEER_IP}" == *"."* ]]; then
        # IPv4
        iptables -t nat -A PREROUTING -p "${PORT_TYPE}" --dport "${PUBLIC_PORT}" -j DNAT --to-destination "${PEER_IP}:${PEER_PORT}"
    elif [[ "${PEER_IP}" == *":"* ]]; then
        # IPv6
        ip6tables -t nat -A PREROUTING -p "${PORT_TYPE}" --dport "${PUBLIC_PORT}" -j DNAT --to-destination "[${PEER_IP}]:${PEER_PORT}"
    else
        echo "Invalid PEER_IP: ${PEER_IP}"
        continue
    fi
done
