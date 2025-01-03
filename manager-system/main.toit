import http
import log
import net
import net.wifi
import encoding.url
import encoding.json

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
        writer.out.write (json.encode modules)
    else if request.method == http.POST:
        // Add a new module
        decoded := json.decode-stream request.body
        if not decoded.contains "id":
          writer.write_headers 400
          writer.out.write "Bad request"
        else if (modules.any: it["id"] == decoded["id"]):
          writer.write_headers 409
          writer.out.write "Conflict"
        else:
          modules.add decoded
          writer.headers.set "Content-Type" "application/json"
          writer.out.write "Success"
  else if action == "modules" and id != "":
    if request.method == http.PUT:
        // Update a specific module
        decoded := json.decode-stream request.body
        module := (modules.filter: it["id"] == id)
        if modules.size != 0:
          module = module.first
          module.do:
            module[it] = decoded[it]
          writer.headers.set "Content-Type" "application/json"
          writer.out.write "Success"
        else:
          writer.write_headers 404
          writer.out.write "Not found"
    else:
        writer.write_headers 405
        writer.out.write "Method not allowed"
