import http
import log
import net
import net.wifi
import encoding.json

import .Module

CAPTIVE_PORTAL_SSID     ::= "mywifi"
CAPTIVE_PORTAL_PASSWORD ::= "12345678"

main:
  network := null
  exception := catch:
    log.info "connecting to wifi"
    network = wifi.open
        --save
        --ssid=CAPTIVE_PORTAL_SSID
        --password=CAPTIVE_PORTAL_PASSWORD
  if exception:
    log.warn "connecting to wifi failed"
    sleep (Duration --s=10)

  module := create-module

  // Register module
  client := http.Client network
  response := client.post-json module.to-map --host="200.200.200.1" --path="/api/modules"
  log.info "$response.status-code"

  while true:
    // Update state
    response := client.post-json module.to-map --host="200.200.200.1" --path="/api/module/1"



  
  
create-module -> Module:
  module := Module "1"
  return module
