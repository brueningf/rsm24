import http
import log
import gpio
import net
import net.wifi
import encoding.json
import encoding.url
import ..libs.utils

import .Module

CAPTIVE_PORTAL_SSID     ::= "mywifi"
CAPTIVE_PORTAL_PASSWORD ::= "12345678"

network := ?
client := ?
module := Module "1" [2,35,39,36,33] [4,13,14,27,26,25] [32,34] [] --sda=21 --scl=22
//module := Module "1" [2,35,39,36,33] [4,13] [32,34] []

main:
  // starting procedure
  log.info "starting"
  signal := gpio.Pin 16 --output
  signal.set 1
  sleep --ms=5000
  pin := gpio.Pin 0 --input --pull-up
  if pin.get == 0: 
    log.info "aborting"
    signal.set 0
    sleep --ms=2000
    signal.set 1
    sleep --ms=2000
    return
  pin.close
  signal.close
  
  // running procedure
  connect-to-ap

  task --background::
    while true:
      trigger-heartbeat 16
  task:: send-update
  task:: run-http

run-http:
  while true:
    socket := network.tcp_listen 80
    server := http.Server --max-tasks=3
    try:
      server.listen socket:: | request writer |
        handle_http_request request writer
    finally:
      socket.close
    if network.is-closed:
      sleep (Duration --s=10)
  

handle_http_request request/http.Request writer/http.ResponseWriter:
    query := url.QueryString.parse request.path
    resource := query.resource
    if resource.starts_with "/api": 
      if resource == "/api/output" and request.method == "POST":
        decoded := json.decode-stream request.body
        log.info "Received JSON: $decoded"
        output := module.outputs[decoded["index"]]

        if decoded.contains "manual":
          output.force-set decoded["value"]
        else if not module.outputs[decoded["index"]].manual:
          output.set decoded["value"]

        write-headers writer 200
        writer.out.write "Success"
    else:
      write-headers writer 404
      writer.out.write "Not found: $resource"
  
    writer.close

connect-to-ap:
  while true:
      exception := catch:
        log.info "connecting to wifi"
        network = wifi.open
            --ssid=CAPTIVE_PORTAL_SSID
            --password=CAPTIVE_PORTAL_PASSWORD
        log.info "connected to wifi"
        client = http.Client network

        // Register module
        log.info "Registering module"
        module.ip = network.address
        response := client.post-json module.to-map --host="200.200.200.1" --path="/api/modules"
        log.info "$response.status-code"

        break
      if exception:
        log.warn "connecting to wifi failed"
        log.warn "retrying in 10 seconds"
        sleep (Duration --s=10)

send-update:
  while true:
    // Send updated state
    exception := catch:
      module.update-state
      response := client.post-json module.to-map --host="200.200.200.1" --path="/api/modules/1"
      log.info "$response.status-code"
    if exception:
      log.info exception
      log.warn "Failed to update state"
      log.warn "Retrying in 10 seconds"
      connect-to-ap

    sleep (Duration --s=5)

write-headers writer/http.ResponseWriter status/int:
  writer.headers.set "Connection" "close"
  writer.write_headers status
