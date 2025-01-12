import gpio
import gpio.adc
import i2c
import uart
import ntp
import esp32 show adjust-real-time-clock
import encoding.json
import system.storage
import pulse_counter

// import watchdog show WatchdogServiceClient

import http
import net
import .index

import bmp280
import aht20

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

aht20-device := I2C-BUS.device aht20.I2C_ADDRESS
aht20-driver := aht20.Driver aht20-device

// flow counter
flow-counter := 0
flow-liters-per-minute := 0
freq := 0

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

send-to-output in/gpio.Pin out/Map:
    if in.get == 0:
      out["pin"].set 1
      out["state"] = 1
    else:
      out["pin"].set 0
      out["state"] = 0
  
generate-client-data:
    devices := I2C-BUS.scan
    temperature := "0"
    pressure := "0"
    temperature-aht20 := "0"
    humidity := "0"
    dew-point := "0"
    adc4 := "0"
    adc6 := "0"
    wl-min := "0"
    wl-max := "0"
    flowppl := "0"

    read-flash-exception := catch:
      water-level-constants := storage.Region.open --flash "water-level" --capacity=8
      wl-min = (water-level-constants.read --from=0 --to=4).to-string-non-throwing
      wl-max = (water-level-constants.read --from=4 --to=8).to-string-non-throwing
      water-level-constants.close

      region := storage.Region.open --flash "flowppl" --capacity=4
      flowppl = (region.read --from=0 --to=4).to-string-non-throwing
      region.close

    if read-flash-exception:
      // log it

    i2c-read-exception := catch:
      driver.on
      temperature = driver.read-temperature.stringify 1
      pressure = driver.read-pressure.stringify 1
      temperature-aht20 = aht20-driver.read-temperature.stringify 1
      humidity = aht20-driver.read-humidity.stringify 2
      dew-point = aht20-driver.read-dew-point.stringify 2
    if i2c-read-exception:
      // log it
    adc-read-exception := catch:
      adc4 = ADC1-4.get.stringify 2
      adc6 = ADC1-6.get.stringify 2
    if adc-read-exception:
      // log it

    return json.stringify { 
      "outputs": outputs.map: | k v | v["state"],
      "inputs": get-values inputs,
      "i2c": devices.stringify, 
      "adc4": adc4,
      "adc6": adc6,
      "temperature_aht20": temperature-aht20,
      "humidity": humidity,
      "dewpoint": dew-point,
      "temperature": temperature,
      "pressure": pressure,
      "wlmin": wl-min,
      "wlmax": wl-max,
      "flowppl": flowppl,
      "flowl": flow-liters-per-minute,
      "flow": flow-counter,
      "freq": freq
        // "humidity": "$driver.read-humidity %"
    }

main:
    update-time
    // client := WatchdogServiceClient
    // client.open  // Now connects to the shared watchdog provider.

    // dog := client.create "doggy"

    network := net.open
    server-socket := network.tcp-listen 80
    clients := []
    
    // set default output to low
    outputs.do: outputs[it]["pin"].set 0

    // invert pump
    PPCTGR.set 1
    
    // open constants region
    // 4 byte variables min, max
    // 4 character in ascii range
    water-level-constants := storage.Region.open --flash "water-level" --capacity=8

    water-level-min := catch:
      wl-min := (water-level-constants.read --from=0 --to=4).to-string
    if water-level-min:
      water-level-constants.write --at=0 "1.00".to-byte-array

    water-level-max := catch:
      wl-max := (water-level-constants.read --from=4 --to=8).to-string
    if water-level-max:
      water-level-constants.write --at=4 "2.80".to-byte-array

    water-level-constants.close

    region := storage.Region.open --flash "flowppl" --capacity=4
    region-exception := catch:
      flowppl := (region.read --from=0 --to=4).to-string
    if region-exception:
      region.write --at=0 "0380".to-byte-array
    flowppl := int.parse (region.read --from=0 --to=4)
    region.close

    info := generate-client-data

    // task::
    //   dog.start --s=60
    //   while true:
    //     dog.feed
    //     sleep --ms=30000

    task --background::  
        server := http.Server --max-tasks=2
        server.listen server-socket:: | request/http.RequestIncoming response-writer/http.ResponseWriter |
          if request.path == "/" or request.path == "/index.html":
            response-writer.headers.add "Content-Type" "text/html"
            response-writer.out.write (index info)
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
            decoded.get "flowppl"
              --if-present=: | value |
                region = storage.Region.open --flash "flowppl" --capacity=4
                region.erase
                region.write --at=0 value.to-byte-array
                region.close
            response-writer.write-headers 201
          else if request.path == "/ws":
            web-socket := server.web-socket request response-writer
            clients.add web-socket
            while chat := web-socket.receive:
              clients.do: it.send chat
            clients.remove web-socket
          else:
            response-writer.write-headers http.STATUS-NOT-FOUND --message="Not Found"
          response-writer.close
    
    task::
      while true:
        info = generate-client-data
        sleep --ms=10000

    task::
      while true:
        sleep --ms=5000
        socket-exception := catch:
          clients.do: 
            it.send info
        if socket-exception:
          print "Error sending info to client"

    task::
      unit := pulse_counter.Unit --low=0 --glitch-filter-ns=1000
      channel := unit.add_channel inputs["2"] --on-positive-edge=pulse_counter.Unit.INCREMENT
      while true:
        freq = (unit.value - flow-counter) * 10
        flow-counter = unit.value
        flow-liters-per-minute = flow-counter / flowppl

        sleep --ms=100

    task::
        // speaker
        while true:
          outputs["1"]["pin"].set 1
          sleep --ms=15
          outputs["1"]["pin"].set 0
          sleep --ms=5000

    task::
        while true:
          // pump and switch
          if CLOLVL.get == 1:
            PPCTGR.set 0
            outputs["PPCTGR"]["state"] = 0
          else:
            PPCTGR.set 1
            outputs["PPCTGR"]["state"] = 1

          send-to-output inputs["2"] outputs["2"]
          send-to-output inputs["3"] outputs["3"]
          send-to-output inputs["4"] outputs["4"]
          send-to-output inputs["5"] outputs["5"]
          sleep --ms=100
