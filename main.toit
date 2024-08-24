import gpio
import gpio.adc
import i2c
import uart
import ntp
import esp32 show adjust-real-time-clock
import encoding.json

import http
import net
import .index

import bmp280


outputs := {
  "1": (gpio.Pin 27 --output),
  "2": (gpio.Pin 26 --output),
  "3": (gpio.Pin 25 --output),
  "4": (gpio.Pin 13 --output),
  "5": (gpio.Pin 14 --output),
}

inputs := {
  "1": (gpio.Pin 36 --input),
  "2": (gpio.Pin 39 --input),
  "3": (gpio.Pin 35 --input),
  "4": (gpio.Pin 4 --input),
  "5": (gpio.Pin 16 --input),
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

PPCTGR := gpio.Pin 2 --output
CLOLVL := gpio.Pin 21 --input

device := I2C-BUS.device bmp280.I2C_ADDRESS_ALT
driver := bmp280.Bmp280 device

current-date:
  now := Time.now.local
  return "$now.year-$(%02d now.month)-$(%02d now.day)"

current-time:
  now := Time.now.local
  return "$(%02d now.h):$(%02d now.m):$(%02d now.s)"

get-values pins/Map:
  values := pins.copy
  pins.do: 
    values[it] = pins[it].get
  return values

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

    i2c-read-exception := catch:
      driver.on
      temperature = "$driver.read-temperature C"
      pressure = "$driver.read-pressure Pa"
    if i2c-read-exception:
      // log it
    adc-read-exception := catch:
      adc4 = ADC1-4.get.stringify 3
      adc6 = ADC1-4.get.stringify 3
    if adc-read-exception:
      // log it

    return json.stringify { 
      "outputs": get-values outputs,
      "inputs": get-values inputs,
      "i2c": devices.stringify, 
      "adc4": adc4,
      "adc6": adc6,
      "temperature": temperature,
      "pressure": pressure,
        // "humidity": "$driver.read-humidity %"
    }

main:
    update-time

    network := net.open
    server-socket := network.tcp-listen 80
    clients := []
    
    // set default output to low
    outputs.do: outputs[it].set 0

    // invert pump
    PPCTGR.set 1

    rx := gpio.Pin 3
    port := uart.Port
        --rx=rx
        --tx=null
        --baud-rate=115200

    task::
      out := ""
      while true:
        while in/ByteArray := port.in.read:
            out += in.to-string
        print "log: $out"
        sleep --ms=500

    task::
        server := http.Server --max-tasks=5
        server.listen server-socket:: | request/http.RequestIncoming response-writer/http.ResponseWriter |
          if request.path == "/" or request.path == "/index.html":
            response-writer.headers.add "Content-Type" "text/html"
            response-writer.out.write (index generate-client-data)
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
          clients.do: it.send generate-client-data
          sleep --ms=5000
    
    task::
        // pump and switch
        while true:
          if CLOLVL.get == 1:
            PPCTGR.set 0
          else:
            PPCTGR.set 1
          sleep --ms=300

    task::
        // speaker
        while true:
          outputs["1"].set 1
          sleep --ms=12
          outputs["1"].set 0
          sleep --ms=120000

    task::
        while true:
          send-to-output inputs["2"] outputs["2"]
          send-to-output inputs["3"] outputs["3"]
          send-to-output inputs["4"] outputs["4"]
          send-to-output inputs["5"] outputs["5"]
          sleep --ms=100

send-to-output in/gpio.Pin out/gpio.Pin:
    if in.get == 0:
      out.set 1
    else:
      out.set 0

blink pin/gpio.Pin:
    pin.set 1
    sleep --ms=1000
    pin.set 0
    

