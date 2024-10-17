import system
import net
import http
import gpio
import gpio.adc
import encoding.json
import ..libs.broadcast
import ..libs.utils

main:
  central-station-ip := search-central-station
  print "Central station found at $central-station-ip"

  data := {
    "type": "module",
    "tank-level": read-adc 32,
    "chlorum-level": read-gpio 21,
  }

  sleep --ms=5000
  system.print-objects --gc

  task::
    data["tank-level"] = read-adc 32
    data["chlorum-level"] = read-gpio 21
    sleep --ms=1000

  network := net.open
  client := http.Client network
  while true:
    web-socket := client.web-socket --host=central-station-ip --path="/ws"
    while true:
      socket-exception := catch:
        web-socket.send (json.stringify data)
        print "Sent message $Time.now"
      if socket-exception:
        print "Exception: $socket-exception"
        print "Reconnecting"
        break
      sleep --ms=2000
    sleep --ms=5000
   
