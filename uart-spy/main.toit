import http
import net
import net.tcp
import uart
import gpio
import log
import i2c
import encoding.json
import mqtt

import .index
import ..libs.utils
import ..libs.weather

import bmp280

MODULE-NAME ::= "green-medium"

CLIENT-ID ::= MODULE-NAME
HOST ::= "mqtt.fredesk.com"
MQTT-USERNAME ::= "admin"
MQTT-PASSWORD ::= "curie-tahoe-snuggly"
TOPIC ::= "weather"

HEARTBEAT-LED ::= 15
RESET-PIN ::= 27

ORX ::= 2
OTX ::= 4

TARGET-TX ::= 16
TARGET-RX ::= 17

MAX-CLIENTS ::= 3  // Reduced from 5 to lower memory footprint

class WebServer:
  network/net.Interface? := null
  server-socket/tcp.ServerSocket? := null
  clients_/List := []
  is-active/bool := false

  constructor:
    network = null
    server-socket = null
    clients_ = []
    is-active = false

  clean-inactive-clients:
    inactive := []
    clients_.do: | client |
      if not client.is-open:
        inactive.add client
    inactive.do: clients_.remove it

  start:
    if is-active: return
    is-active = true
    network = net.open
    server-socket = network.tcp-listen 80
    print "Listening on http://$network.address/"
    
    task --background::
      server := http.Server --max-tasks=2
      server.listen server-socket:: | request/http.RequestIncoming response-writer/http.ResponseWriter |
        response-writer.headers.set "Connection" "close"
        if request.path == "/" or request.path == "/index.html":
          response-writer.headers.add "Content-Type" "text/html"
          response-writer.out.write (INDEX-HTML MODULE-NAME)
        else if request.path == "/reset":
          response-writer.headers.add "Content-Type" "text/html"
          response-writer.out.write "OK"
          reset-pin := gpio.Pin RESET-PIN --output
          reset-pin.set 1
          sleep --ms=100
          reset-pin.close
        else if request.path == "/ws":
          clean-inactive-clients  // Clean before adding new client
          // real-time socket
          if clients_.size >= MAX-CLIENTS:
            response-writer.write-headers http.STATUS-SERVICE-UNAVAILABLE --message="Too many connections"
          else:
            web-socket := server.web-socket request response-writer
            clients_.add web-socket
            while data := web-socket.receive:
              clients_.do: it.send data
            clients_.remove web-socket
        else:
          response-writer.write-headers http.STATUS-NOT-FOUND --message="Not Found"
        response-writer.close

  stop:
    is-active = false
    if server-socket: server-socket.close
    if network: network.close
    network = null
    server-socket = null
    clients_ = []

  send data/string:
    if not is-active: return
    clients_.do: it.send data

main:
  print "Starting"

  //web-server := WebServer
  // Uncomment the next line to enable the web server
  // web-server.start

  // Target UART reader
  // // Target UART reader - reads data from target device
  // task --background::
  //   sleep --ms=100
  //   port := uart.Port
  //       --rx=gpio.Pin TARGET-RX
  //       --tx=null
  //       --baud-rate=115200
  //   exception := catch:
  //     reader := port.in
  //     while line := reader.read-line:
  //       web-server.send "TARGET: $line"

  //   if exception:
  //     log.error "Struggling to read target uart"

  // // Own UART Reader - reads data from this device
  // task --background::
  //   oport := uart.Port
  //       --rx=gpio.Pin OTX
  //       --tx=null
  //       --baud-rate=115200
  //   exception := catch:
  //     reader := oport.in
  //     while line := reader.read-line:
  //       web-server.send "ME: $line"

  //   if exception:
  //     print "Struggling to read uart"

  task::
    while true:
      trigger-heartbeat HEARTBEAT-LED 1
      sleep --ms=1000
  
  task::
    sleep --ms=2000
    test-weather := Weather 33 22
    log.info "Start send payload"
    options := mqtt.SessionOptions
      --client-id=CLIENT-ID
      --username=MQTT-USERNAME
      --password=MQTT-PASSWORD
      --clean-session=true
    while true:
      exception := catch:
        client := mqtt.Client --host=HOST
        client.start --options=options
        test-weather.read
        payload := json.encode {
          "module": MODULE-NAME,
          "temperature": test-weather.temperature,
          "humidity": test-weather.humidity,
          "pressure": test-weather.pressure,
        }
        client.publish TOPIC payload
        log.info "sent payload to graph.fredesk.com"
        client.close
      if exception:
        log.info "failed to report"
        print exception
      sleep --ms=10000
