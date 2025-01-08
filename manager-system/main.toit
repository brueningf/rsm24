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

modules := []

main:
  log.info "starting"
  task:: run
 
run:
    log.info "establishing wifi in AP mode ($CAPTIVE_PORTAL_SSID)"
    while true:
      network_ap := wifi.establish
          --ssid=CAPTIVE_PORTAL_SSID
          --password=CAPTIVE_PORTAL_PASSWORD
      log.info "wifi established"      
      run_http network_ap

run_http network/net.Interface:
  socket := network.tcp_listen 80
  server := http.Server
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
        writer.headers.set "Connection" "close"
        writer.out.write INDEX

    else if resource.starts_with "/api": 
      handle_api request writer
  
    else:
      writer.headers.set "Content-Type" "text/plain"
      writer.headers.set "Connection" "close"
      writer.write_headers 404
      writer.out.write "Not found: $resource"
  
    writer.close

handle_api request/http.Request writer/http.ResponseWriter:
  query := url.QueryString.parse request.path
  resourceList := query.resource.split "/"
  log.info "API resource: $resourceList"
  action := resourceList[2]
  id := ""

  if resourceList.size > 3:
    id = resourceList[3]

  if action == "modules" and id == "":
    if request.method == http.GET:
        // Get all modules
        writer.headers.set "Content-Type" "application/json"
        write-headers writer 200
        writer.out.write (json.encode modules:: it.stringify)
    else if request.method == http.POST:
        // Add a new module
        decoded := json.decode-stream request.body
        module := null
        module-exception := catch:
          module = Module.parse decoded

        if module-exception:
          write-headers writer 400
          writer.out.write "Bad request"
        else if (modules.any: it.id == module.id):
          write-headers writer 409
          writer.out.write "Conflict"
        else:
          modules.add module
          writer.headers.set "Content-Type" "application/json"
          write-headers writer 201
          writer.out.write "Success"
  else if action == "modules" and id != "":
    if request.method == http.PUT:
        // Update a specific module
        decoded := json.decode-stream request.body
        filtered-modules := (modules.filter: it.id == id)
        if filtered-modules.size != 0:
          module := filtered-modules.first
          module.update decoded
          writer.headers.set "Content-Type" "application/json"
          write-headers writer 200
          writer.out.write "Success"
        else:
          write-headers writer 404
          writer.out.write "Not found"
    else:
        write-headers writer 405
        writer.out.write "Method not allowed"

write-headers writer/http.ResponseWriter status/int:
  writer.headers.set "Connection" "close"
  writer.write_headers status
