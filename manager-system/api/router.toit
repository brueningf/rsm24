import http
import log
import encoding.url
import encoding.json
import net
import system.storage

import ..module
import .utils
import .modules
import .settings
import .remote

class ApiHandler:
  _module-controller/ModuleController
  _settings-controller/SettingsController
  _remote-controller/RemoteController
  interrupt /bool := false

  constructor modules/Map settings/Map module/Module network/net.Client:
    _module-controller = ModuleController modules
    _settings-controller = SettingsController settings
    _remote-controller = RemoteController modules module network

  handle request/http.Request writer/http.ResponseWriter:
    query := url.QueryString.parse request.path
    resourceList := query.resource.split "/"
    action := resourceList[2]
    id := null
    subAction := null

    log.info "Path: $request.path | Resource: $resourceList | Action: $action"

    if resourceList.size > 3:
      id = resourceList[3]
    else if resourceList.size > 4:
      subAction = resourceList[4]

    exception := catch:
      if action == "modules":
        handle-modules request writer id
      else if action == "rmt":
        handle-remote request writer id
      else if action == "settings":
        handle-settings request writer
      else if action == "interrupt":
        handle-interrupt writer
      else:
        write-error writer 404 "Not found"
    if exception:
      log.error "Error handling request"
      write-error writer 500 "Internal server error"

  handle-modules request/http.Request writer/http.ResponseWriter id/string?:
    if request.method == http.GET:
      _module-controller.handle-get writer
    else if request.method == http.POST:
      _module-controller.handle-post request writer id
    else:
      write-error writer 405 "Method not allowed"

  handle-remote request/http.Request writer/http.ResponseWriter id/string:
    _remote-controller.handle-remote request writer id

  handle-settings request/http.Request writer/http.ResponseWriter:
    if request.method == http.GET:
      _settings-controller.handle-get writer
    else if request.method == http.POST:
      _settings-controller.handle-update request writer
    else:
      write-error writer 405 "Method not allowed"

  handle-interrupt writer/http.ResponseWriter:
    write-success writer 200
    interrupt = true
