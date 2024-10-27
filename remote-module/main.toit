import system
import net
import http
import gpio
import gpio.adc
import encoding.json
import pulse-counter
import ..libs.broadcast
import ..libs.utils

config ::= {
  "AIN1": 32,
  "AIN2": 34,
  "DI1": 36,
  "DI2": 39,
  "DI3": 35,
  "DI4": 4,
  "DI5": 16,
  "DI6": 21,
  "DO1": 27,
  "DO2": 26,
  "DO3": 25,
  "DO4": 13,
  "DO5": 14,
  "PC1_DIVISOR": 380,
}

data := {
  "type": "module",
  "state": {
    "AIN1": 0,
    "AIN2": 0,
    "PC1": 0,
    "DI2": 0, 
    "DI3": 0,
    "DI4": 0, 
    "DI5": 0,
    "DO1": 0,
    "DO2": 0,
    "DO3": 0,
    "DO4": 0,
  }
}

main:
  update-time
  task::
    // speaker
    while true:
      speaker := gpio.Pin config["DO1"] --output
      speaker.set 1
      sleep --ms=15
      speaker.set 0
      speaker.close
      sleep --ms=15000

  central-station-ip := search-central-station
  print "Central station found at $central-station-ip"

  sleep --ms=5000
  system.print-objects --gc

  task:: read-counter config["DI2"]
        
  task::
    while true:
      data["state"]["AIN1"] = read-adc config["AIN1"]
      data["state"]["AIN2"] = read-adc config["AIN2"]
      data["state"]["DI1"] = read-gpio config["DI1"]
      data["state"]["DI3"] = read-gpio config["DI3"]
      data["state"]["DI4"] = read-gpio config["DI4"]
      data["state"]["DI5"] = read-gpio config["DI5"]
      data["state"]["DI6"] = read-gpio config["DI6"]
      sleep --ms=1000

  network := net.open
  client := http.Client network

  while true:
    web-socket := null
    connection-exception := catch:
      web-socket = client.web-socket --host=central-station-ip --path="/ws"
    if connection-exception:
      sleep --ms=5000
      continue
    task --background::
      catch:
        while received := web-socket.receive:
          json-parse-exception := catch:
            decoded := json.parse received
            if decoded["type"] == "central-station":
              update-state decoded["state"]

          if json-parse-exception:
            print "Exception: $json-parse-exception"
            print "Received message: $received"

    while true:
      socket-exception := catch:
        web-socket.send (json.stringify data)
        print "Sent message $Time.now"
      if socket-exception:
        print "Exception: $socket-exception"
        print "Reconnecting"
        break
      sleep --ms=2000
   
read-counter number/int:
  unit := pulse-counter.Unit
  pin := gpio.Pin number
  channel := unit.add-channel (pin)
  while true:
    if unit.value >= config["PC1_DIVISOR"]:
      data["state"]["PC1"] += unit.value / config["PC1_DIVISOR"]
      unit.clear  
    sleep --ms=1000
  channel.close
  unit.close
  pin.close

update-state state:
  state.do:
    write-gpio config[it] state[it]
    print "Wrote $state[it] to $it"
