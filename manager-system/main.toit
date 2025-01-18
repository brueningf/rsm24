import http
import log
import net
import net.wifi
import encoding.url
import encoding.json
import system.storage

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

modules := Map
network := ?
module := ?

settings ::= {
  "tank-a-capacity": 1000,
  "tank-a-threshold-1": 10,
  "tank-a-threshold-2": 100
}

main:
  log.info "starting"

  log.info "loading settings"
  settings-bucket := storage.Bucket.open --flash "config"

  settings.keys.do:
    settings[it] = settings-bucket.get it --init=: settings[it]

  settings-bucket.close
  

  log.info "loading module"

  module = Module "0" [15, 16] [1, 2, 9, 10, 11] [4, 6] []

  task::
    while true:
      // update state of this station
      module.update-state
      modules["0"] = module.to-map
      sleep --ms=1000

  task:: run
 
run:
    log.info "establishing wifi in AP mode ($CAPTIVE_PORTAL_SSID)"
    network = wifi.establish
        --ssid=CAPTIVE_PORTAL_SSID
        --password=CAPTIVE_PORTAL_PASSWORD
    log.info "wifi established"      
    run_http

run_http:
  socket := network.tcp_listen 80
  server := http.Server --max-tasks=3
  try:
    server.listen socket:: | request writer |
      handle_http_request request writer
  finally:
    socket.close
  unreachable

handle_http_request request/http.Request writer/http.ResponseWriter:
    query := url.QueryString.parse request.path
    resource := query.resource
    if resource == "/":
        writer.headers.set "Content-Type" "text/html"
        write-headers writer 200
        writer.out.write INDEX

    else if resource.starts_with "/api": 
      handle_api request writer
  
    else:
      writer.headers.set "Content-Type" "text/plain"
      write-headers writer 404
      writer.out.write "Not found: $resource"
  
    writer.close

handle_api request/http.Request writer/http.ResponseWriter:
  query := url.QueryString.parse request.path
  resourceList := query.resource.split "/"
  action := resourceList[2]
  id := null
  subAction := null

  log.info "API resource: $resourceList"
  log.info "API action: $action"

  if resourceList.size > 3:
    id = resourceList[3]
    log.info "API id: $id"
  else if resourceList.size > 4:
    subAction = resourceList[4]
    log.info "API subAction: $subAction"

  if action == "modules":
    if request.method == http.GET:
      // Get all modules
      writer.headers.set "Content-Type" "application/json"
      write-headers writer 200
      writer.out.write (json.encode modules.values)
    else if request.method == http.POST and not id:
      // Add a new module
      decoded := json.decode-stream request.body
      if modules.contains decoded["id"]:
        write-headers writer 409
        writer.out.write "Conflict"
      else:
        modules[decoded["id"]] = decoded
        writer.headers.set "Content-Type" "application/json"
        write-headers writer 201
        writer.out.write "Success"
    else if request.method == http.POST and id:
      // Update a specific module
      decoded := json.decode-stream request.body
      log.info "Updating module $id"

      if modules.contains id:
        modules[id] = decoded
        writer.headers.set "Content-Type" "application/json"
        write-headers writer 200
        writer.out.write "Success"
      else:
        write-headers writer 404
        writer.out.write "Module not found"
    else:
        write-headers writer 405
        writer.out.write "Method not allowed"
  else if action == "rmt" and request.method == http.POST and id:
    decoded := json.decode-stream request.body
    // todo: validate decoded
    log.info "Received JSON: $decoded"
    if id == "0":
      module.outputs[decoded["index"]].set decoded["value"]
    else:
      remote-module := modules[id]

      // Send command to module
      client := http.Client network
      response := client.post-json decoded --host=remote-module["ip"] --path="/api/output"
      client.close
    
    write-headers writer 200
    writer.out.write "Success"
  else if action == "settings":
    if request.method == http.GET:
      // Get all settings
      writer.headers.set "Content-Type" "application/json"
      write-headers writer 200
      writer.out.write (json.encode settings)
    else if request.method == http.POST:
      // Update settings
      decoded := json.decode-stream request.body
      log.info "Decoded: $decoded"

      settings-bucket := storage.Bucket.open --flash "config"
      exception := catch:
        decoded.keys.do:
          log.info "Updating setting: $it, $decoded[it]"
          settings-bucket[it] = decoded[it]
      if exception:
        log.error "Failed to update settings"
        settings-bucket.close
        write-headers writer 500
        writer.out.write "Failed"
        return

      settings.keys.do:
        settings[it] = settings-bucket.get it --init=: settings[it]

      writer.headers.set "Content-Type" "application/json"
      write-headers writer 200
      writer.out.write "Success"
    else:
      write-headers writer 405
      writer.out.write "Method not allowed"
  else:
    write-headers writer 404
    writer.out.write "Not found"

write-headers writer/http.ResponseWriter status/int:
  writer.headers.set "Connection" "close"
  writer.write_headers status
