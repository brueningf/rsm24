import http
import log
import net
import net.wifi
import gpio
import mqtt
import encoding.url
import encoding.json
import system.storage
import system.containers
import ..libs.utils

import .ManagerAPI
import .Module
import .ApiUtils

CAPTIVE-PORTAL-SSID     ::= "mywifi"
CAPTIVE-PORTAL-PASSWORD ::= "12345678"

EXTERNAL-WIFI-SSID     ::= "SPACELAB2"
EXTERNAL-WIFI-PASSWORD ::= "x6254Y:gf7<3"

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
}

module := ?
modules := Map
network := ?

main:
  log.info "starting"

  /**
   * Check if the interrupt button is pressed
   */
  sleep --ms=5000
  pin := gpio.Pin 0 --input --pull-up
  if pin.get == 0: 
    led := gpio.Pin 2 --output
    led.set 0
    sleep --ms=2000
    return

  /**
   * Load settings from flash
   */
  log.info "Loading settings"
  settings-bucket := storage.Bucket.open --flash "settings"

  settings.keys.do:
    settings[it] = settings-bucket.get it --if-absent=:settings[it]
  settings-bucket.close 

  log.info "loading module"

  /**
   * Initialize the module
   * Parameters:
   * inputs, output[pin, default=0], analog-ins, pulse counter
   */
  module = Module "0" [15, 16, 38] [[8, 1], 9, 10, 11, 12, 13, [17, 1], [18, 1]] [4, 5, 6, 7] []

  pump-active := false // tmp variable

  /**
   * Run the main task
   */
  task:: run

  /**
   * Auto pump
   */
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

  /**
   * Heartbeat
   */
  task --background::
    while true:
      trigger-heartbeat 2
      sleep --ms=100

  /**
   * Update the state of the module
   */
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
  while true:
    // Communicate with module network
    log.info "establishing wifi in AP mode ($CAPTIVE_PORTAL_SSID)"
    server-exception := catch:
      run-server
      network.close
    if server-exception:
      log.info "Server: $server-exception"
    sleep --ms=1000
    
    // Connect to LAN
    log.info "Attempting to connect to external WiFi"
    client-exception := catch:
      run-client
      network.close
    if client-exception:
      log.info "Client: $client-exception"
    sleep --ms=1000

run-server:
  try:
    wifi-exception := catch:
      network = wifi.establish
          --ssid=CAPTIVE-PORTAL-SSID
          --password=CAPTIVE-PORTAL-PASSWORD
      log.info "wifi established"      
    if wifi-exception:
      log.info "failed to establish AP"
      
    exception := catch:
       with-timeout (Duration --m=1):
        run-http
    if exception:
      log.info "Breaking"
      log.info exception
      if exception == "Interrupt":
        throw exception
    log.info "wifi closing"
  finally:
    network.close

run-client:
  try:
    exception := catch:
      network = wifi.open --ssid=EXTERNAL-WIFI-SSID --password=EXTERNAL-WIFI-PASSWORD
      log.info "Connected to external WiFi"
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

run_http:
  socket := network.tcp_listen 80
  server := http.Server --max-tasks=3
  server.listen socket:: | request writer |
    try:
      exception := catch:
        handle_http_request request writer
      if exception == "Interrupt":
        socket.close
        throw "Interrupt"
      else if exception:
        log.error "Exception: HTTP - $exception"
        
        writer.headers.set "Content-Type" "text/plain"
        writer.out.write "Internal server error"
    finally:
      writer.close

handle_http_request request/http.Request writer/http.ResponseWriter:
    query := url.QueryString.parse request.path
    resource := query.resource
    if resource == "/":
        ApiUtils.write-html writer 200 INDEX
    else if resource.starts_with "/api": 
      handle_api request writer settings modules module network
    else:
      ApiUtils.write-error writer 404 "Not found"
    writer.close

