import sys, Ice
import MumbleServer

with Ice.initialize(sys.argv) as communicator:
    base = communicator.stringToProxy("Meta:tcp -h 127.0.0.1 -p 6502")

    meta = MumbleServer.MetaPrx.checkedCast(base)
    if not meta:
        raise RuntimeError("Invalid proxy")

    servers = meta.getAllServers()

    if len(servers) == 0:
        print("No servers found")

    for currentServer in servers:
        if currentServer.isRunning():
            print(
                "Found server (id=%d):\tOnline since %d seconds"
                % (currentServer.id(), currentServer.getUptime())
            )
        else:
            print("Found server (id=%d):\tOffline" % currentServer.id())
