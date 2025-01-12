import http
import log
import net
import net.wifi
import encoding.json

import .Module

CAPTIVE_PORTAL_SSID     ::= "mywifi"
CAPTIVE_PORTAL_PASSWORD ::= "12345678"

network := ?
client := ?
module := Module "1" [5,18] [22,23] [] []

main:
  connect-to-ap

  task:: send-update

connect-to-ap:
  while true:
      exception := catch:
        log.info "connecting to wifi"
        network = wifi.open
            --ssid=CAPTIVE_PORTAL_SSID
            --password=CAPTIVE_PORTAL_PASSWORD
        log.info "connected to wifi"
        client = http.Client network

        // Register module
        log.info "Registering module"
        response := client.post-json module.to-map --host="200.200.200.1" --path="/api/modules"
        log.info "$response.status-code"

        break
      if exception:
        log.warn "connecting to wifi failed"
        log.warn "retrying in 10 seconds"
        sleep (Duration --s=10)

send-update:
  while true:
    // Update state
    exception := catch:
      response := client.post-json module.to-map --host="200.200.200.1" --path="/api/modules/1"
      log.info "$response.status-code"
    if exception:
      log.warn "Failed to update state"
      log.warn "Retrying in 10 seconds"
      connect-to-ap

    sleep (Duration --s=5)
