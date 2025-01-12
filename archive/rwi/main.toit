import gpio
import i2c
import bmp280
import http
import net
import encoding.json

HEART-BEAT := 2

INDEX-HTML st:
    return """
<!DOCTYPE html>
<body>
Hello<br>
$st
</body>
</html>
"""


main:
    data := {"name": "minor-night", "i2c": null}
    bus := i2c.Bus 
        --sda=gpio.Pin 47
        --scl=gpio.Pin 48

    device := bus.device bmp280.I2C_ADDRESS_ALT
    driver := bmp280.Bmp280 device
    driver.on

    task::
        while true:
            data["i2c"] = (bus.scan).stringify
            sensor-exception := catch:
                data["temperature"] = driver.read-temperature
                data["pressure"] = driver.read-pressure / 100
            if sensor-exception:
                data["i2c-error"] = "Sensor"
            sleep --ms=1000    


    network := net.open
    server-socket := network.tcp-listen 80
    clients := []

    task --background::
        server := http.Server --max-tasks=5
        server.listen server-socket:: | request/http.RequestIncoming response-writer/http.ResponseWriter |
            if request.path == "/" or request.path == "/index.html":
                response-writer.headers.add "Content-Type" "text/html"
                response-writer.out.write (INDEX-HTML (json.stringify data))
            else:
                response-writer.write-headers http.STATUS-NOT-FOUND --message="Not Found"

    task::
        while true:
            heart-beat := gpio.Pin HEART-BEAT --output
            heart-beat.set 0
            sleep (Duration --us=10)
            heart-beat.set 1
            sleep --ms=999
            heart-beat.close
            
        
