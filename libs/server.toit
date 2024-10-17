import http
import encoding.json
import net
import net.tcp
import tls
import gpio
import system.storage
import .index
import .flash

class WebServer:
    clients /List := []
    network /net.Client := ?
    server /http.Server := ?

    constructor:
        network = net.open
        server = (http.Server --max-tasks=2)
    
    run port/int:
        server.listen network port:: | request/http.RequestIncoming writer/http.ResponseWriter |
            if request.path == "/":
                flash := Flash 
                tank-level := gpio.Pin 32 --input
                tank-level-value := tank-level.get
                tank-level.close
                bucket := storage.Bucket.open --ram "pump-state"
                active := bucket.get "active"
                bucket.close
                data := {
                    "interval": flash.get "settings/interval" "01:00",
                    "pump_period": flash.get "settings/pump_period" "05:00",
                    "tank_level": tank-level-value,
                    "pump_active": active,
                }

                writer.headers.set "Content-Type" "text/html"
                writer.out.write (index (json.stringify data))
            else if request.path == "/pump-trigger" and request.method == "POST":
                bucket := storage.Bucket.open --ram "pump-state"
                bucket["tmp-active"] = true
                bucket.close
                writer.write-headers 201
            else if request.path == "/toggle-pump" and request.method == "POST":
                bucket := storage.Bucket.open --ram "pump-state"
                old := bucket.get "active"
                bucket["active"] = not old
                bucket.close
                writer.write-headers 201
            else if request.path == "/settings" and request.method == "POST":
                flash := Flash 
                decoded := json.decode-stream request.body
                decoded.get "interval"
                  --if-present=: | value |
                    flash.store "settings/interval" value

                decoded.get "pump_period"
                  --if-present=: | value |
                    flash.store "settings/pump_period" value
                
                writer.write-headers 201
            else:
                writer.headers.set "Content-Type" "text/plain"
                writer.out.write "Not found 404"
            writer.close

