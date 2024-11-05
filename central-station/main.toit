import system
import http
import net
import net.tcp
import encoding.json
import system
import gpio

import .web.index

import ..libs.flash
import ..libs.broadcast
import ..libs.utils
import ..libs.weather

config ::= Flash.get "config" {
  "operation-mode": "auto",
  "pulse-per-liter": 380,
  "tank-1-max": 4000,
  "tank-1-min": 1000,
  "tank-1-capacity": 5000,
  "tank-1-threshold": 1,
}

state ::= {
  "station": {
    "errors": Set,
    "temperature": 0,
    "humidity": 0,
    "pressure": 0,
    "AIN0": 0,
    "AIN1": 0,
    "AIN2": 0,
    "AIN4": 0,
    "DI1": 0,
    "DI2": 0,
    "DI3": -1,
    "DI4": 0,
    "DO1": 0,
    "DO2": 0,
    "DO3": 0,
    "DO4": 0,
    "DO5": 0,
    "P1": 0,
    "P2": 0,
    "AUX": 0,
  },
  "modules": [],
  "config": config
}

advertise-central-station:
  server := Server
  network := net.open
  my-ip := network.address
  network.close
  while true:
    print "Broadcasting central station at $my-ip"
    msg := {"type": "central-station", "ip": "$my-ip"}
    server.broadcast (json.stringify msg)

    if state["modules"].size > 0:
      sleep (Duration --m=10)
    else:
      sleep (Duration --s=10)

get-weather:
  weather := Weather 47 48
  weather.read
  return weather

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
  print "Starting central station"
  update-time

  weather := get-weather
  clients := []

  task:: advertise-central-station
  task --background:: 
    while true: 
      trigger-heartbeat 2

  // task --background::
  //   while true:
  //     [9,10,11,12,13].do:
  //       trigger-pin it
  //     sleep --ms=1000
  task::
    DO1 := gpio.Pin 9 --output
    DO2 := gpio.Pin 10 --output
    DO3 := gpio.Pin 11 --output
    DO4 := gpio.Pin 12 --output
    DO5 := gpio.Pin 13 --output
    P1 := gpio.Pin 17 --output
    P2 := gpio.Pin 18 --output
    AUX := gpio.Pin 8 --output
    while true:
      DO1.set state["station"]["DO1"]
      DO2.set state["station"]["DO2"]
      DO3.set state["station"]["DO3"]
      DO4.set state["station"]["DO4"]
      DO5.set state["station"]["DO5"]
      P1.set state["station"]["P1"]
      P2.set state["station"]["P2"]
      AUX.set state["station"]["AUX"]
      sleep --ms=1000

  task:: 
    while true:
      if weather.available:
        state["station"]["temperature"] = weather.temperature
        state["station"]["humidity"] = weather.humidity
        state["station"]["pressure"] = weather.pressure
        
      state["station"]["AIN0"] = read-adc 4
      state["station"]["AIN1"] = read-adc 5
      state["station"]["AIN2"] = read-adc 6
      state["station"]["AIN4"] = read-adc 7
      state["station"]["DI1"] = read-gpio 15
      state["station"]["DI2"] = read-gpio 16
      // state["station"]["DI3"] = read-gpio 37
      state["station"]["DI4"] = read-gpio 38

      send-updates-to-clients clients
      sleep --ms=1000

  system.print-objects --gc

  // Start the web server
  network := net.open
  server := (http.Server --max-tasks=3)
  server.listen network 80:: | request/http.RequestIncoming writer/http.ResponseWriter |
    if request.path == "/":
      writer.headers.set "Content-Type" "text/html"
      writer.headers.set "Connection" "close"
      writer.out.write (render-view "index" (get-state))
    else if request.path == "/set-output" and request.method == http.POST:
      decoded := json.decode-stream request.body
      if not state["station"].contains decoded["name"]:
        writer.headers.set "Content-Type" "text/html"
        writer.headers.set "Connection" "close"
        writer.write-headers 401
        writer.out.write ("Failed")
      else:  
        state["station"][decoded["name"]] = decoded["value"]
        writer.headers.set "Content-Type" "text/html"
        writer.headers.set "Connection" "close"
        writer.write-headers 200
        writer.out.write ("Success")
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
      if state["modules"].contains module:
        state["modules"].remove module
      else if clients.contains web-socket:
        clients.remove web-socket
    else:
      writer.headers.set "Content-Type" "text/plain"
      writer.out.write "Not found 404"
    writer.close
