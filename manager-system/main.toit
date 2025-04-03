import http
import log
import net
import net.wifi
import gpio
import encoding.url
import encoding.json
import system.storage
import system.containers
import ..libs.utils

import .ManagerAPI
import .Module

CAPTIVE_PORTAL_SSID     ::= "mywifi"
CAPTIVE_PORTAL_PASSWORD ::= "12345678"

INDEX ::= """
<html>
  <head>
    <title>Server</title>
  </head>
  <body>
    <p>Server is running</p>
  <body>
<html>
"""

settings ::= {
  "tank-a-capacity": 1000,
  "tank-a-threshold-1": 10,
  "tank-a-threshold-2": 100,
  "pump-upper-bound": 850,
  "pump-lower-bound": 450,
}

module := ?
modules := Map
network := ?

main:
  log.info "starting"
  sleep --ms=5000
  pin := gpio.Pin 0 --input --pull-up
  if pin.get == 0: 
    led := gpio.Pin 2 --output
    led.set 0
    sleep --ms=2000
    return

  log.info "loading settings"
  settings-bucket := storage.Bucket.open --flash "settings"

  settings.keys.do:
    settings[it] = settings-bucket.get it --if-absent=:settings[it]
  settings-bucket.close 

  log.info "loading module"

  // inputs, output[pin, default=0], analog-ins, pulse counter
  module = Module "0" [15, 16, 38] [[8, 1], 9, 10, 11, 12, 13, [17, 1], [18, 1]] [4, 5, 6, 7] []
  pump-active := false

  task:: run

  // auto pump
  task --background::
    while true:
      if modules.contains "1" and network:
        client := http.Client network
        remote-module := modules["1"]
        level := remote-module["analog-inputs"][0]
        output := remote-module["outputs"][1]

        if level["value"] <= (settings["pump-lower-bound"] / 1000.0):
          pump-active = false
        else if level["value"] >= (settings["pump-upper-bound"] / 1000.0):
          pump-active = true

        drive-pump-exception := catch:
          if pump-active:
            if output["value"] != 1:
              print "activate pump"
              // Send command to module
              response := client.post-json {"index": 1, "value": 1 } --host=remote-module["ip"] --path="/api/output"
          else:
            if output["value"] != 0:
              print "deactivate pump"
              response := client.post-json {"index": 1, "value": 0 } --host=remote-module["ip"] --path="/api/output"
              sleep (Duration --s=30)
        if drive-pump-exception:
          print "failed driving pump"
      sleep --ms=2000

  task --background::
    while true:
      trigger-heartbeat 2
      sleep --ms=100

  task --background::
    while true:
      exception := catch:
        // update state of this station
        module.update-state
        modules["0"] = module.to-map
        check-modules
      if exception:
        log.error "Exception: ModuleUpdate - $exception"

      sleep --ms=100

  task --background::
    while true:
      module.read-weather
      sleep --ms=5000

check-modules:
  now := Time.now
  modules.do: 
    m := modules[it]
    if m["id"] != "0":
      if ((Time.parse m["last-seen"]).plus --s=10) < now:
        m["online"] = false
      if ((Time.parse m["last-seen"]).plus --m=1) < now:
        log.info "Removing module " + m["id"]
        modules.remove m["id"]
 
run:
    log.info "establishing wifi in AP mode ($CAPTIVE_PORTAL_SSID)"
    network = wifi.establish
        --ssid=CAPTIVE_PORTAL_SSID
        --password=CAPTIVE_PORTAL_PASSWORD
    log.info "wifi established"      
    run_http
    log.info "wifi closing"

run_http:
  socket := network.tcp_listen 80
  server := http.Server --max-tasks=3
  server.listen socket:: | request writer |
    exception := catch:
      handle_http_request request writer
    if exception == "Interrupt":
      socket.close
    else if exception:
      log.error "Exception: HTTP - $exception"
      
      writer.headers.set "Content-Type" "text/plain"
      writer.out.write "Internal server error"
      writer.close
  unreachable

handle_http_request request/http.Request writer/http.ResponseWriter:
    query := url.QueryString.parse request.path
    resource := query.resource
    if resource == "/":
        write-response writer 200 INDEX "text/html"
    else if resource.starts_with "/api": 
      handle_api request writer settings modules module network
    else:
      write-response writer 404 "Not found" "text/plain"
    writer.close

