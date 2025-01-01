import http
import log
import net
import net.wifi
import encoding.url

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
    if resource == "/": resource = "index.html"
    if resource.starts_with "/": resource = resource[1..]
  
    if resource != "index.html":
      writer.headers.set "Content-Type" "text/plain"
      writer.write_headers 404
      writer.out.write "Not found: $resource"
  
    writer.headers.set "Content-Type" "text/html"
    writer.out.write INDEX