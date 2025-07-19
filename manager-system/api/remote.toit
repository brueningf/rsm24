import http
import log
import encoding.json
import net
import .utils
import ..module

class RemoteController:
  _modules/Map
  _module/Module
  _network/net.Client

  constructor modules/Map module/Module network/net.Client:
    _modules = modules
    _module = module
    _network = network

  handle-remote request/http.Request writer/http.ResponseWriter id/string:
    if request.method != http.POST:
      write-error writer 405 "Method not allowed"
      return

    decoded := json.decode-stream request.body
    decoded["manual"] = 1
    log.info "Received JSON: $decoded"

    if id == "0":
      _module.outputs[decoded["index"]].force-set decoded["value"]
    else:
      remote-module := _modules[id]
      client := http.Client _network
      response := client.post-json decoded --host=remote-module["ip"] --path="/api/output"
      client.close

    write-success writer 200 
