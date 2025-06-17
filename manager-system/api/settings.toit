import http
import log
import encoding.json
import system.storage
import .utils

class SettingsController:
  _settings/Map

  constructor settings/Map:
    _settings = settings

  handle-get writer/http.ResponseWriter:
    write-success writer 200 (json.encode _settings)

  handle-update request/http.Request writer/http.ResponseWriter:
    decoded := json.decode-stream request.body
    log.info "Decoded: $decoded"

    settings-bucket := storage.Bucket.open --flash "settings"
    exception := catch:
      decoded.keys.do:
        log.info "Updating setting: $it, $decoded[it]"
        settings-bucket[it] = decoded[it]
    if exception:
      log.error "Failed to update settings: $exception"
      write-error writer 500 "Internal server error - update settings"

    // Update the settings in the manager
    _settings.keys.do:
      _settings[it] = settings-bucket.get it --init=: _settings[it]

    settings-bucket.close

    write-success writer 200 
