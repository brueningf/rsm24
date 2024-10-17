import net
import encoding.json
import ..libs.broadcast

advertise-central-station:
  broadcast := Server
  network := net.open
  my-ip := network.address
  network.close
  broadcast.periodic-broadcast (Duration --s=30):
    print "Broadcasting central station at $my-ip"
    msg := {"type": "central-station", "ip": "$my-ip"}
    json.stringify msg



main:
  task:: advertise-central-station

