import http
import net
import uart
import gpio
import log
import i2c
import encoding.json
import certificate-roots

import .index
import ..libs.utils
import ..libs.weather

import bmp280

HEARTBEAT-LED ::= 15
RST-PIN ::= 27

ORX ::= 2
OTX ::= 4

TARGET-TX ::= 16
TARGET-RX ::= 17


main:
  certificate-roots.install-common-trusted-roots
  print "Starting"

  network := net.open
  server-socket := network.tcp-listen 80
  print "Listening on http://$network.address/"
  clients := []

  // Target UART reader
  task::
    port := uart.Port
        --rx=gpio.Pin TARGET-RX
        --tx=null
        --baud-rate=115200
    exception := catch:
      reader := port.in
      while line := reader.read-line:
        clients.do:
          it.send "TARGET: $line"

    if exception:
      log.error "Struggling to read target uart"

  // Own UART Reader
  task --background::
    oport := uart.Port
        --rx=gpio.Pin OTX
        --tx=null
        --baud-rate=115200
    exception := catch:
      reader := oport.in
      while line := reader.read-line:
        clients.do:
          it.send "ME: $line"

    if exception:
      print "Struggling to read uart"

  // Web Server
  task --background::
    server := http.Server --max-tasks=5
    server.listen server-socket:: | request/http.RequestIncoming response-writer/http.ResponseWriter |
      if request.path == "/" or request.path == "/index.html":
        response-writer.headers.add "Content-Type" "text/html"
        response-writer.out.write INDEX-HTML
      else if request.path == "/reset":
        response-writer.headers.add "Content-Type" "text/html"
        response-writer.out.write "OK"
        rst := gpio.Pin RST-PIN --output
        rst.set 1
        sleep --ms=100
      else if request.path == "/ws":
        // real-time socket
        web-socket := server.web-socket request response-writer
        clients.add web-socket
        while data := web-socket.receive:
          clients.do: it.send data
        clients.remove web-socket
      else:
        response-writer.write-headers http.STATUS-NOT-FOUND --message="Not Found"

  task::
    while true:
      trigger-heartbeat HEARTBEAT-LED 1
      sleep --ms=1000
  
  task::
    sleep --ms=2000
    test-weather := Weather 33 22
    headers := http.Headers
    headers.add "Connection" "Close"
    log.info "Starting send payload"
    while true:
      test-weather.read
      exception := catch:
        data := {
          "temperature": test-weather.temperature,
          "humidity": test-weather.humidity,
          "pressure": test-weather.pressure,
        }
        client := http.Client.tls network
        try:
          response := client.post-json --host="red.fredesk.com" --path="/report/weather" --headers=headers data
        finally:
          client.close
        log.info "sent payload to graph.fredesk.com"
      if exception:
        log.info "failed to report"
        print exception
      sleep --ms=1000

