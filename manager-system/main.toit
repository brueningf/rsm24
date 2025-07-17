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

AP-SSID     ::= "mywifi"
AP-PASSWORD ::= "12345678"

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
  module = Module "0" [15, 16, 38] [[8, 1], 9, 10, 11, 12, 13, [17, 1], [18, 1]] [4, 5, 6, 7] []

  pump-active := false // TMP variable

  system.tune-memory-use 5

  // Runs the server in AP/STA mode
  task:: run
  task:: 
    while true:
      stats := system.process-stats --gc=false

      allocated_memory := stats[STATS-INDEX-ALLOCATED-MEMORY]
      reserved_memory := stats[STATS-INDEX-RESERVED-MEMORY]
      system_free_memory := stats[STATS-INDEX-SYSTEM-FREE-MEMORY]
      largest_free_area := stats[STATS-INDEX-SYSTEM-LARGEST-FREE]
      bytes_allocated := stats[STATS-INDEX-BYTES-ALLOCATED-IN-OBJECT-HEAP]
      gc_count := stats[STATS-INDEX-GC-COUNT]
      full_gc_count := stats[STATS-INDEX-FULL-GC-COUNT]
      full_compacting_gc_count := stats[STATS-INDEX-FULL-COMPACTING-GC-COUNT]

      heap_utilization := (allocated_memory / reserved_memory)

      free_heap := reserved_memory - allocated_memory
      fragmentation_ratio := (largest_free_area / free_heap)

      print "=== Memory and GC Statistics ==="
      print "Allocated Memory (bytes):       $(allocated_memory)"
      print "Reserved Memory (bytes):        $(reserved_memory)"
      print "Heap Utilization:               $((heap_utilization * 100).stringify 3)"
      print "System Free Memory (bytes):     $(system_free_memory)"
      print "Largest Free Area (bytes):      $(largest_free_area)"
      print "Fragmentation Ratio:            $(fragmentation_ratio)"
      print "Bytes Allocated in Object Heap: $(bytes_allocated)"
      print "GC Count (new-space):           $(gc_count)"
      print "Full GC Count:                  $(full_gc_count)"
      print "Full Compacting GC Count:       $(full_compacting_gc_count)"
      sleep --ms=10000

  // TMP pump control
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
      break
    sleep --ms=1000
    
    // Connect to LAN
    log.info "Connecting to external network ($EXTERNAL-WIFI-SSID)"
    client-exception := catch:
      run-client
    if client-exception:
      log.info "Client: $client-exception"
    sleep --ms=1000

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
      //sleep (Duration --m=1)
      sleep --ms=10000
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
