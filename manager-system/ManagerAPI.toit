import http
import log
import encoding.url
import encoding.json
import net
import system.storage

import .Module

handle_api request/http.Request writer/http.ResponseWriter settings/Map modules/Map module/Module network/net.Client:
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
      content := modules.values
      write-response writer 200 (json.encode content)
    else if request.method == http.POST and not id:
      // Add a new module
      decoded := json.decode-stream request.body
      if modules.contains decoded["id"]:
        write-response writer 409 "Conflict"
      else:
        modules[decoded["id"]] = decoded
        write-response writer 201

      modules[decoded["id"]]["last-seen"] = Time.now.stringify
      modules[decoded["id"]]["online"] = true
    else if request.method == http.POST and id:
      // Update a specific module
      decoded := json.decode-stream request.body
      log.info "Updating module $id"

      if modules.contains id:
        modules[id] = decoded
        modules[id]["last-seen"] = Time.now.stringify
        modules[id]["online"] = true
        write-response writer 200
      else:
        write-response writer 404 "Module not found"
    else:
        write-response writer 405 "Method not allowed"
  else if action == "rmt" and request.method == http.POST and id:
    decoded := json.decode-stream request.body
    // Add manual flag
    decoded["manual"] = 1
    // todo: validate decoded
    log.info "Received JSON: $decoded"
    if id == "0":
      module.outputs[decoded["index"]].force-set decoded["value"]
    else:
      remote-module := modules[id]

      // forward command to module
      client := http.Client network
      response := client.post-json decoded --host=remote-module["ip"] --path="/api/output"
      client.close
    
    write-response writer 200
  else if action == "settings":
    if request.method == http.GET:
      // Get all settings
      write-response writer 200 (json.encode settings)
    else if request.method == http.POST:
      // Update settings
      decoded := json.decode-stream request.body
      log.info "Decoded: $decoded"

      settings-bucket := storage.Bucket.open --flash "settings"
      exception := catch:
        decoded.keys.do:
          log.info "Updating setting: $it, $decoded[it]"
          settings-bucket[it] = decoded[it]
      if exception:
        log.error "Failed to update settings"
        settings-bucket.close
        write-response writer 500 "Internal server error - update settings"
        return

      settings.keys.do:
        settings[it] = settings-bucket.get it --init=: settings[it]

      write-response writer 200
    else:
      write-response writer 405 "Method not allowed"
  else if action == "interrupt":
    write-response writer 200
    throw "Interrupt"
  else:
    write-response writer 404 "Not found"

write-response writer/http.ResponseWriter status/int message/any="Success" type/string="application/json":
  writer.headers.set "Content-Type" type
  writer.headers.set "Connection" "close"
  writer.write_headers status
  writer.out.write message
