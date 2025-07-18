import http
import log
import net
import net.wifi
import gpio
import mqtt
import encoding.url
import encoding.json

import system
import system.storage
import system.containers

import ..libs.utils

import .api.router
import .api.utils
import .Module

import watchdog show WatchdogServiceClient

AP-SSID     ::= "mywifi"
AP-PASSWORD ::= "12345678"

EXTERNAL-WIFI-SSID     ::= "MERIDA RAMIREZ"
EXTERNAL-WIFI-PASSWORD ::= "nose2025"

CLIENT-ID ::= "local-pie"

MQTT-HOST ::= "mqtt.fredesk.com"
MQTT-USERNAME ::= "admin"
MQTT-PASSWORD ::= "curie-tahoe-snuggly"

INDEX ::= """
<html>
    <p>Server is running</p>
<html>
"""

settings ::= {
  "tank-a-capacity": 1000,
  "tank-a-threshold-1": 10,
  "tank-a-threshold-2": 100,
  "pump-upper-bound": 850,
  "pump-lower-bound": 450,
  "lvs1-lower-bound": 500,
  "lvs1-middle-bound": 700,
  "lvs1-upper-bound": 1050,
}

module := ?
modules := Map
network := ?
interrupt := false

main:
  log.info "starting"

  // Check if the device is in bootloader mode
  sleep --ms=5000
  pin := gpio.Pin 0 --input --pull-up
  if pin.get == 0: 
    led := gpio.Pin 2 --output
    led.set 0
    sleep --ms=2000
    return

  // Load settings from flash
  log.info "Loading settings"
  settings-bucket := storage.Bucket.open --flash "settings"

  settings.keys.do:
    settings[it] = settings-bucket.get it --if-absent=:settings[it]
  settings-bucket.close 

  log.info "loading module"

  // inputs, output[pin, default=0], analog-ins, pulse counter
  module = Module "0" [15, 16, 38] [9, 10, 11, 12, 13, [17, 1], [18, 1],[8, 1]] [4, 5, 6, 7] []

  pump-active := false // TMP variable

  system.tune-memory-use 5 // optimize for low memory usage

  // Create a watchdog client, and require feeding every 60 seconds
  //watchdog-client := WatchdogServiceClient
  //watchdog-client.open

  //dog := watchdog-client.create "mtsc-dog"
  //dog.start --s=120
  
  // Runs the server in AP/STA mode
  task:: run

  // first sequence
  task --background::
    log.info modules.stringify
    while true:
      log.info "Checking modules"
      if modules.contains "0" and modules.contains "1" and network:
        log.info "Module 0 found, checking level"
        client := http.Client network
        level := modules["0"]["analog-inputs"][2]["value"]
        p3-active := false
        remote-module := modules["1"]
        output := remote-module["outputs"][1]
        if level <= (settings["lvs1-middle-bound"] / 1000.0):
          log.info "Level is low-middle, activating pump"
          // attempt to fill
          // open valve
          module.outputs[0].set 1 // open valve
          // turn on pump1 P1
          p3-active = true

          // check if there is flow, if not cancel attempt
        else if level >= (settings["lvs1-upper-bound"] / 1000.0):
          // turn off pump p1
          log.info "Level is high, deactivating pump"
          // close valve
          p3-active = false

        drive-pump-exception := catch:
          if p3-active:
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
      else:
        log.info "Module 0 not found, waiting for it to connect"

      sleep --ms=1000

  // Heart-beat
  task --background::
    while true:
      trigger-heartbeat 2
      sleep --ms=100

  // General state update
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

  // Read module temperature
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
  while true:
    // Communicate with module network
    log.info "establishing wifi in AP mode ($AP-SSID)"
    server-exception := catch:
      run-server
    if server-exception:
      log.info "Server: $server-exception"

    log.info (interrupt ? "Server interrupted, stopping..." : "Server timeout, sending info to external server...")

    if interrupt:
      //dog.stop
      //dog.close
      break
    sleep --ms=1000
    
    // Connect to LAN
    log.info "Connecting to external network ($EXTERNAL-WIFI-SSID)"
    client-exception := catch:
      log.info "run client"
      //run-client
    if client-exception:
      log.info "Client: $client-exception"

run-server:
  try:
    wifi-exception := catch:
      network = wifi.establish
          --ssid=AP-SSID
          --password=AP-PASSWORD
      log.info "AP established"      
    if wifi-exception:
      log.error "failed to establish AP"
      log.error wifi-exception
      
    exception := catch:
      log.info "Starting HTTP server"
      http-task := task::
        server := http.Server --max-tasks=3
        socket := network.tcp-listen 80
        server.listen socket:: | request writer |
          handle-http-request request writer
      sleep (Duration --m=2)
      http-task.cancel
    if exception:
      log.error "Server: $exception"
      log.error exception
  finally:
    log.info "HTTP server closing"
    network.close

run-client:
  try:
    exception := catch:
      network = wifi.open --ssid=EXTERNAL-WIFI-SSID --password=EXTERNAL-WIFI-PASSWORD
      log.info "Connected"
      client := mqtt.Client --host=MQTT-HOST
      options := mqtt.SessionOptions
        --client-id=CLIENT-ID
        --username=MQTT-USERNAME
        --password=MQTT-PASSWORD
        --clean-session=true
      client.start --options=options
      payload := json.encode {
        "module": CLIENT-ID,
        "modules": modules.values
      }
      client.publish "mtsc" payload
      client.close
      log.info "MQTT message sent"
    if exception:
      log.error "Client: $exception"
  finally:
    network.close

handle-http-request request/http.Request writer/http.ResponseWriter:
    query := url.QueryString.parse request.path
    resource := query.resource
    exception := catch:
      if resource == "/":
          write-html writer 200 INDEX
      else if resource.starts-with "/api": 
        handler := ApiHandler modules settings module network
        handler.handle request writer

        if handler.interrupt:
          log.info "Interrupting server"
          interrupt = true
      else:
        write-error writer 404 "Not found"
    if exception:
      log.error "HTTP Request handler: $exception"
    writer.close
