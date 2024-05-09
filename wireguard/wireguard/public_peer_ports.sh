#!/command/with-contenv /bin/bash

## Setup the iptables rules for the public peer ports

for port_map in ${PUBLIC_PEER_PORTS//,/ }
do
    # call your procedure/other scripts here below
    IFS=':' read -r -a __conf <<< "${port_map}"
    PEER="${__conf[0]}"
    PEER_PORT="${__conf[1]}"
    PUBLIC_PORT="${__conf[2]}"
    PORT_TYPE="${__conf[3]}"
    iptables -t nat -A PREROUTING -p "${PORT_TYPE}" --dport "${PUBLIC_PORT}" -j DNAT --to-destination "${PEER}:${PEER_PORT}"
done
