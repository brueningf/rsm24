import system
import net
import http
import gpio
import gpio.adc
import encoding.json
import pulse-counter
import ..libs.broadcast
import ..libs.utils

config := {
  "ADC1_4": 32,
  "ADC1_6": 34,
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
      "ADC1_4":read-adc 32,
      "ADC1_6":read-adc 34,
      "PC1": 0,
      "DI2": read-gpio config["DI2"],
      "DI3": read-gpio config["DI3"],
      "DI4": read-gpio config["DI4"],
      "DI5": read-gpio config["DI5"],
  }
}

state := {
  "DO1": 0,
  "DO2": 0,
  "DO3": 0,
  "DO4": 0,
}

main:
  update-time
  central-station-ip := search-central-station
  print "Central station found at $central-station-ip"

  sleep --ms=5000
  system.print-objects --gc
        
  task::
    data["state"]["ADC1_4"] = read-adc 32
    data["state"]["ADC1_6"] = read-adc 34
    data["state"]["PC1"] += read-counter 36
    data["state"]["DI2"] = read-gpio 39
    data["state"]["DI3"] = read-gpio 35
    data["state"]["DI4"] = read-gpio 4
    data["state"]["DI5"] = read-gpio 16
    data["state"]["DI6"] = read-gpio 21
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
              state = decoded["state"]
              update-state

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
  pin := gpio.Pin number
  unit := pulse-counter.Unit
  channel := unit.add-channel (pin)
  result := 0
  if unit.value >= config["PC1_DIVISOR"]:
    result = unit.value / config["PC1_DIVISOR"]
    unit.clear  
  channel.close
  unit.close
  pin.close
  return result

update-state:
  state.do:
    write-gpio config[it] state[it]
    print "Wrote $state[it] to $it"
