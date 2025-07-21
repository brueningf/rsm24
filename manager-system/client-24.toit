import http
import log
import gpio
import gpio.pwm
import spi
import net
import net.wifi
import encoding.json
import encoding.url
import ..libs.utils

import cs5529
import .module

CAPTIVE_PORTAL_SSID     ::= "mywifi"
CAPTIVE_PORTAL_PASSWORD ::= "12345678"

network := ?
client := ?
cs5529-reading := "0.00"
interrupt := false
// 2024
module := Module "1" [36,39,35,16] [27,26,25,13,14,2] [32,34] [] --sda=33 --scl=22

main:
  // starting procedure
  log.info "starting"
  signal := gpio.Pin 27 --output
  signal.set 1
  sleep --ms=100
  signal.set 0
  sleep --ms=5000
  pin := gpio.Pin 36 --input 
  if pin.get == 0: 
    log.info "aborting"
    signal.set 0
    sleep --ms=1000
    signal.set 1
    sleep --ms=1000
    return
  pin.close
  signal.close
  
  // running procedure
  connect-to-ap

  // crystal for cs5529
  xout := gpio.Pin 17 --output
  generator := pwm.Pwm --frequency=32_768
  channel := generator.start xout
  channel.set-duty-factor 0.5

  task --background::
    bus := spi.Bus
      --mosi=gpio.Pin 21
      --miso=gpio.Pin 19
      --clock=gpio.Pin 18
    
    device := bus.device 
      --cs=gpio.Pin 5
      --frequency=1_000_000
    
    driver := cs5529.Cs5529 device
    reading := "0.00"

    while true:
      raw := driver.read --raw
      actual-raw := raw >> 8
      VREF := 2.500
      ADC-MAX := 65335.0 // cast to float for division
      // previus calibration 26.108
      cs5529-reading = ((actual-raw / ADC-MAX) * VREF).stringify 5
      sleep --ms=500

  task --background:: send-update
  task:: run-http

run-http:
  while true:
    socket := network.tcp_listen 80
    server := http.Server --max-tasks=3
    try:
      server.listen socket:: | request writer |
        handle_http_request request writer
        if interrupt:
          socket.close
    finally:
      socket.close

    if interrupt:
      break
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
    else if resource == "/api/interrupt":
      interrupt = true

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
      module-map := module.to-map
      module-map["analog-inputs"].add {
        "pin": 99,
        "value": cs5529-reading
      }
      response := client.post-json module-map --host="200.200.200.1" --path="/api/modules/1"
      log.info "$response.status-code"
      module.read-weather
    if exception:
      log.info exception
      log.warn "Failed to update state"
      log.warn "Retrying in 10 seconds"
      connect-to-ap
    if interrupt:
      break
    sleep (Duration --s=1)

write-headers writer/http.ResponseWriter status/int:
  writer.headers.set "Connection" "close"
  writer.write_headers status
