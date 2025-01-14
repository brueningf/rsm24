import http
import log
import net
import net.wifi
import encoding.url
import encoding.json

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

main:
  log.info "starting"
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
      log.info "Decoded: $decoded"

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
    // Remote control
    decoded := json.decode-stream request.body
    module := modules[id]
    // Send command to module
    // decoded = { "index": 0, "value": 1 }
    client := http.Client network
    response := client.post-json decoded --host=module["ip"] --path="/api/output"
    client.close
    
    write-headers writer 200
    writer.out.write "Success"
  else:
    write-headers writer 404
    writer.out.write "Not found"

write-headers writer/http.ResponseWriter status/int:
  writer.headers.set "Connection" "close"
  writer.write_headers status
