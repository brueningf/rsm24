import system
import http
import net
import net.tcp
import encoding.json

import .web.index

import ..libs.flash
import ..libs.broadcast

config ::= Flash.get "config" {
  "operation-mode": "auto",
  "pulse-per-liter": 380,
  "tank-1-max": 4000,
  "tank-1-min": 1000,
  "tank-1-capacity": 5000,
  "tank-1-threshold": null,
}

state ::= {
  "station": {
    "temperature": 0,
    "humidity": 0,
    "pressure": 0,
  },
  "modules": [],
  "config": config
}

advertise-central-station:
  broadcast := Server
  network := net.open
  my-ip := network.address
  network.close
  while true:
    if state["modules"].size > 0:
      sleep (Duration --m=10)
    print "Broadcasting central station at $my-ip"
    msg := {"type": "central-station", "ip": "$my-ip"}
    json.stringify msg
    sleep (Duration --s=10)

update-state:


get-state:
  return json.stringify state:: | entry |
    entry.stringify

send-updates-to-clients clients:
  json-state := get-state

  clients.do:
    it.send json-state

class Module:
  socket/http.WebSocket
  state/Map

  constructor .socket/http.WebSocket .state/Map:

  send data/string:
    listener-exception := catch:
      socket.send data
    if listener-exception:
      print "Exception: $listener-exception"

  update-state state_/Map:
   state_.do:
     state[it] = state_[it]

  to-json:
    return json.stringify state

  stringify:
    return to-json

main:
  clients := []

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
      writer.out.write (render-view "index" (get-state))
    else if request.path == "/login":
      if request.method == http.POST:
        decoded := json.decode-stream request.body
        print "Received JSON: $decoded"
        if decoded["username"] == "admin" and decoded["password"] == "admin":
          writer.headers.set "Content-Type" "application/json"
          writer.headers.set "Connection" "close"
          writer.write-headers 200
          writer.out.write ("Success")
        else:
          writer.headers.set "Content-Type" "text/html"
          writer.headers.set "Connection" "close"
          writer.write-headers 401
          writer.out.write ("Failed")
      else:
        writer.headers.set "Content-Type" "text/html"
        writer.headers.set "Connection" "close"
        writer.out.write (render-view "login" {})
    else if request.path == "/config" and request.method == http.POST:
      decoded := json.decode-stream request.body
      print "Received JSON: $decoded"
      decoded.do:
        config[it] = decoded[it]
      Flash.store "config" decoded
      writer.write-headers 200
    else if request.path == "/ws":
      web-socket := server.web-socket request writer
      // New connection
      first := web-socket.receive
      first = json.parse first
      module := null
      if first["type"] == "module":
        module = Module web-socket first["state"]
        state["modules"].add module
        
        print "Adding module: " + web-socket.socket_.peer-address.stringify
        print state["modules"]
      else if first["type"] == "client":
        clients.add web-socket
        print "Adding client: " + web-socket.socket_.peer-address.stringify

      // Established connection
      while data := web-socket.receive:
        decoded := json.parse data
        if decoded["type"] == "module":
          print "Received data from module: " + web-socket.socket_.peer-address.stringify
          module.update-state decoded["state"]
        else if decoded["type"] == "client":
          print "Received data from client: " + web-socket.socket_.peer-address.stringify
        else:
          print "Received unknown data: " + data

      // Connection closed
      if state["modules"].contains web-socket:
        state["modules"].remove web-socket
      else if clients.contains web-socket:
        clients.remove web-socket
    else:
      writer.headers.set "Content-Type" "text/plain"
      writer.out.write "Not found 404"
    writer.close
