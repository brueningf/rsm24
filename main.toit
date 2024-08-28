import gpio
import gpio.adc
import i2c
import uart
import ntp
import esp32 show adjust-real-time-clock
import encoding.json
import system.storage
import pulse_counter

import watchdog show WatchdogServiceClient

import http
import net
import .index

import bmp280

PPCTGR := gpio.Pin 2 --output
CLOLVL := gpio.Pin 21 --input

outputs := {
  "1": { "pin": (gpio.Pin 27 --output), "state": 0 },
  "2": { "pin": (gpio.Pin 26 --output), "state": 0 },
  "3": { "pin": (gpio.Pin 25 --output), "state": 0 },
  "4": { "pin": (gpio.Pin 13 --output), "state": 0 },
  "5": { "pin": (gpio.Pin 14 --output), "state": 0 },
  "PPCTGR": { "pin": PPCTGR, "state": 0 }
}

inputs := {
  "1": (gpio.Pin 36 --input),
  "2": (gpio.Pin 39 --input),
  "3": (gpio.Pin 35 --input),
  "4": (gpio.Pin 4 --input),
  "5": (gpio.Pin 16 --input),
  "CLOLVL": CLOLVL,
}

I2C-SDA := gpio.Pin 33 
I2C-SCL := gpio.Pin 22  
I2C-BUS := i2c.Bus --sda=I2C-SDA --scl=I2C-SCL

SPI-MISO := gpio.Pin 19 
SPI-MOSI := gpio.Pin 23 
SPI-CLK := gpio.Pin 18 
SPI-CS := gpio.Pin 5
SPI-RESET := gpio.Pin 17

ADC1-6 := adc.Adc (gpio.Pin 34)
ADC1-4 := adc.Adc (gpio.Pin 32)

device := I2C-BUS.device bmp280.I2C_ADDRESS_ALT
driver := bmp280.Bmp280 device

// flow counter
pulse-count-per-minute := 0
flow-liters-per-minute := 0

current-date:
  now := Time.now.local
  return "$now.year-$(%02d now.month)-$(%02d now.day)"

current-time:
  now := Time.now.local
  return "$(%02d now.h):$(%02d now.m):$(%02d now.s)"

get-values pins/Map:
  return pins.map: | k v |
    v.get

update-time:
  set-timezone "<-05>5"
  now := Time.now
  if now < (Time.parse "2022-01-10T00:00:00Z"):
    result ::= ntp.synchronize --server="0.south-america.pool.ntp.org"
    if result:
      adjust-real-time-clock result.adjustment
    else:
      // log it
      print "ntp: synchronization request failed"
  
generate-client-data:
    devices := I2C-BUS.scan
    temperature := "0"
    pressure := "0"
    adc4 := "0"
    adc6 := "0"

    water-level-constants := storage.Region.open --flash "water-level" --capacity=8
    wl-min := (water-level-constants.read --from=0 --to=3).to-string-non-throwing
    wl-max := (water-level-constants.read --from=4 --to=8).to-string-non-throwing
    water-level-constants.close

    i2c-read-exception := catch:
      driver.on
      temperature = driver.read-temperature.stringify 2
      pressure = "$driver.read-pressure"
    if i2c-read-exception:
      // log it
    adc-read-exception := catch:
      adc4 = ADC1-4.get.stringify 2
      adc6 = ADC1-6.get.stringify 3
    if adc-read-exception:
      // log it

    return json.stringify { 
      "outputs": outputs.map: | k v | v["state"],
      "inputs": get-values inputs,
      "i2c": devices.stringify, 
      "adc4": adc4,
      "adc6": adc6,
      "temperature": temperature,
      "pressure": pressure,
      "wlmin": wl-min,
      "wlmax": wl-max,
      "flowl": flow-liters-per-minute,
      "flow": pulse-count-per-minute,
        // "humidity": "$driver.read-humidity %"
    }

main:
    update-time
    client := WatchdogServiceClient
    client.open  // Now connects to the shared watchdog provider.

    dog := client.create "doggy"

    network := net.open
    server-socket := network.tcp-listen 80
    clients := []
    
    // set default output to low
    outputs.do: outputs[it]["pin"].set 0

    // invert pump
    PPCTGR.set 1
    
    // open constants region
    // 4 byte variables min, max
    water-level-constants := storage.Region.open --flash "water-level" --capacity=8

    water-level-min := catch:
      wl-min := (water-level-constants.read --from=0 --to=3).to-string
    if water-level-min:
      water-level-constants.write --at=0 "1.00".to-byte-array

    water-level-max := catch:
      wl-max := (water-level-constants.read --from=4 --to=8).to-string
    if water-level-max:
      water-level-constants.write --at=4 "2.80".to-byte-array

    water-level-constants.close




    task::
      dog.start --s=60
      while true:
        dog.feed
        sleep --ms=30000

    task --background::
        server := http.Server --max-tasks=5
        server.listen server-socket:: | request/http.RequestIncoming response-writer/http.ResponseWriter |
          if request.path == "/" or request.path == "/index.html":
            response-writer.headers.add "Content-Type" "text/html"
            response-writer.out.write (index generate-client-data)
          else if request.path == "/constants/update" and request.method == http.POST:
            constants := storage.Region.open --flash "water-level" --capacity=8
            decoded := json.decode-stream request.body
            constants.erase
            decoded.get "wlmin"
              --if-present=: | value |
                constants.write --at=0 value.to-byte-array
                print "Setting constant wlmin: $value"
            decoded.get "wlmax"
              --if-present=: | value |
                constants.write --at=4 value.to-byte-array
            constants.close
            response-writer.write-headers 201
          else if request.path == "/ws":
            web-socket := server.web-socket request response-writer
            clients.add web-socket
            while chat := web-socket.receive:
              clients.do: it.send chat
            clients.remove web-socket
          else:
            response-writer.write-headers http.STATUS-NOT-FOUND --message="Not Found"

    task::
        while true:
          data := generate-client-data
          socket-exception := catch:
            clients.do: 
              it.send data
          sleep --ms=5000

    task::
      unit := pulse_counter.Unit
      channel := unit.add_channel inputs["2"]
      while true:
        pulse-count-per-minute = unit.value
        flow-liters-per-minute = pulse-count-per-minute / 380
        sleep --ms=500

    task::
        // pump and switch
        while true:
          if CLOLVL.get == 1:
            PPCTGR.set 0
            outputs["PPCTGR"]["state"] = 0
          else:
            PPCTGR.set 1
            outputs["PPCTGR"]["state"] = 1
          sleep --ms=300

    task::
        // speaker
        while true:
          outputs["1"]["pin"].set 1
          sleep --ms=12
          outputs["1"]["pin"].set 0
          sleep --ms=30000

    task::
        while true:
          send-to-output inputs["2"] outputs["2"]
          send-to-output inputs["3"] outputs["3"]
          send-to-output inputs["4"] outputs["4"]
          send-to-output inputs["5"] outputs["5"]
          sleep --ms=200

send-to-output in/gpio.Pin out/Map:
    if in.get == 0:
      out["pin"].set 1
      out["state"] = 1
    else:
      out["pin"].set 0
      out["state"] = 0