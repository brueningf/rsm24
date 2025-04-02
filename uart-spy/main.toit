import http
import net
import uart
import gpio
import .index
import ..libs.utils

ORX ::= 2
OTX ::= 4

TRX ::= 16
TTX ::= 17

main:
  print "Starting"
  port := uart.Port
      --rx=gpio.Pin TRX
      --tx=null
      --baud-rate=115200

  network := net.open
  server-socket := network.tcp-listen 80
  print "Listening on http://$network.address/"
  clients := []

  task::
    exception := catch:
      reader := port.in
      while line := reader.read-line:
        print "Received: $line"
        clients.do:
          it.send "Target: $line"

    if exception:
      print "Struggling to read uart"

  task --background::
    server := http.Server --max-tasks=5
    server.listen server-socket:: | request/http.RequestIncoming response-writer/http.ResponseWriter |
      if request.path == "/" or request.path == "/index.html":
        response-writer.headers.add "Content-Type" "text/html"
        response-writer.out.write INDEX-HTML
      else if request.path == "/ws":
        web-socket := server.web-socket request response-writer
        clients.add web-socket
        while data := web-socket.receive:
          clients.do: it.send data
        clients.remove web-socket
      else:
        response-writer.write-headers http.STATUS-NOT-FOUND --message="Not Found"

  task::
    while true:
      trigger-heartbeat 22 1

      sleep --ms=1000
