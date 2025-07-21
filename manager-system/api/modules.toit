import http
import log
import encoding.json
import .utils

class ModuleController:
  _modules/Map

  constructor modules/Map:
    _modules = modules

  handle-get writer/http.ResponseWriter:
    content := _modules.values

    // analog inputs with 3 decimal places
    exception := catch:
      content.do:
        it["analog-inputs"].do: | input |
          input["value"] = input["value"].stringify 3
    if exception:
      log.error "Error formatting analog inputs: $exception"

    write-success writer 200 (json.encode content)

  handle-post request/http.Request writer/http.ResponseWriter id/string?:
    decoded := json.decode-stream request.body
    if id:
      handle-update writer id decoded
    else:
      handle-create writer decoded

  handle-create writer/http.ResponseWriter decoded/Map:
    if _modules.contains decoded["id"]:
      write-error writer 409 "Conflict"
      return

    _modules[decoded["id"]] = decoded
    _modules[decoded["id"]]["last-seen"] = Time.now.stringify
    _modules[decoded["id"]]["online"] = true
    write-success writer 201

  handle-update writer/http.ResponseWriter id/string decoded/Map:
    if not _modules.contains id:
      write-error writer 404 "Module not found"
      return

    _modules[id] = decoded
    _modules[id]["last-seen"] = Time.now.stringify
    _modules[id]["online"] = true
    write-success writer 200 
