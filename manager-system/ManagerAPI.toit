import http
import log
import encoding.url
import encoding.json
import net
import system.storage

import .Module
import .ApiUtils
import .ModuleController
import .SettingsController
import .RemoteController

class ApiHandler:
  _module-controller/ModuleController
  _settings-controller/SettingsController
  _remote-controller/RemoteController

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

    log.info "API resource: $resourceList"
    log.info "API action: $action"

    if resourceList.size > 3:
      id = resourceList[3]
      log.info "API id: $id"
    else if resourceList.size > 4:
      subAction = resourceList[4]
      log.info "API subAction: $subAction"

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
        ApiUtils.write-error writer 404 "Not found"
    if exception:
      if exception == "Interrupt":
        throw "Interrupt"
      else:
        log.error "Error handling request"
        ApiUtils.write-error writer 500 "Internal server error"

  handle-modules request/http.Request writer/http.ResponseWriter id/string?:
    if request.method == http.GET:
      _module-controller.handle-get writer
    else if request.method == http.POST:
      _module-controller.handle-post request writer id
    else:
      ApiUtils.write-error writer 405 "Method not allowed"

  handle-remote request/http.Request writer/http.ResponseWriter id/string:
    _remote-controller.handle-remote request writer id

  handle-settings request/http.Request writer/http.ResponseWriter:
    if request.method == http.GET:
      _settings-controller.handle-get writer
    else if request.method == http.POST:
      _settings-controller.handle-update request writer
    else:
      ApiUtils.write-error writer 405 "Method not allowed"

  handle-interrupt writer/http.ResponseWriter:
    ApiUtils.write-success writer 200
    throw "Interrupt"

handle_api request/http.Request writer/http.ResponseWriter settings/Map modules/Map module/Module network/net.Client:
  handler := ApiHandler modules settings module network
  handler.handle request writer
