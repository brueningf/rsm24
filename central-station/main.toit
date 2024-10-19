import system
import http
import net
import net.tcp
import encoding.json
import ..libs.broadcast
import .index

state ::= {
  "DO1": 0,
  "DO2": 0,
  "DO3": 0,
  "DO4": 0,
}

advertise-central-station:
  broadcast := Server
  network := net.open
  my-ip := network.address
  network.close
  broadcast.periodic-broadcast (Duration --s=10):
    print "Broadcasting central station at $my-ip"
    msg := {"type": "central-station", "ip": "$my-ip"}
    json.stringify msg

send-updates-to-clients clients:
  clients.do:
    it.send (json.stringify state)

class Module:
  socket/http.WebSocket
  state/Map

  constructor .socket/http.WebSocket .state/Map:

  send data/string:
    listener-exception := catch:
      socket.send data
    if listener-exception:
      print "Exception: $listener-exception"

main:
  clients := []
  modules := []

  task:: advertise-central-station
  task:: 
    while true:
      send-updates-to-clients clients
      sleep --ms=1000

  network := net.open
  server := (http.Server --max-tasks=4)
  server.listen network 80:: | request/http.RequestIncoming writer/http.ResponseWriter |
    if request.path == "/":
      writer.headers.set "Content-Type" "text/html"
      writer.headers.set "Connection" "close"
      writer.out.write (render-view "index" (json.stringify "data"))
    else if request.path == "/ws":
      web-socket := server.web-socket request writer
      first := web-socket.receive
      first = json.parse first
      if first["type"] == "module":
        modules.add (Module web-socket first["state"])
        print "Adding module: " + web-socket.socket_.peer-address.stringify
        print modules
      else if first["type"] == "client":
        clients.add web-socket
        print "Adding client: " + web-socket.socket_.peer-address.stringify
      while data := web-socket.receive:
        decoded := json.parse data
        if decoded["type"] == "module":
          print "Received data from module: " + web-socket.socket_.peer-address.stringify
        else if decoded["type"] == "client":
          print "Received data from client: " + web-socket.socket_.peer-address.stringify
        else:
          print "Received unknown data: " + data
      if modules.contains web-socket:
        modules.remove web-socket
      else if clients.contains web-socket:
        clients.remove web-socket
    else:
      writer.headers.set "Content-Type" "text/plain"
      writer.out.write "Not found 404"
    writer.close
