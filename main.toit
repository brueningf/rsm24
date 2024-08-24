import gpio
import gpio.adc
import i2c
import uart
import ntp
import esp32 show adjust-real-time-clock

import http
import net
import .index

import .melody

import bmp280


DO1 := gpio.Pin 27 --output
DO2 := gpio.Pin 26 --output
DO3 := gpio.Pin 25 --output
DO4 := gpio.Pin 13 --output
DO5 := gpio.Pin 14 --output

DI1 := gpio.Pin 36 --input
DI2 := gpio.Pin 39 --input
DI3 := gpio.Pin 35 --input
DI4 := gpio.Pin 4 --input
DI5 := gpio.Pin 16 --input

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

generate-client-data:
    devices := I2C-BUS.scan

    driver.on
    return { 
      "i2c": devices.stringify, 
      "adc4": ADC1-4.get.stringify,
      "adc6": ADC1-6.get.stringify,
      "DI5": DI5.get,
      "temperature": "$driver.read-temperature C",
      "pressure": "$driver.read-pressure Pa",
        // "humidity": "$driver.read-humidity %"
    }.stringify

main:
    now := Time.now
    if now < (Time.parse "2022-01-10T00:00:00Z"):
      result ::= ntp.synchronize
      if result:
        adjust-real-time-clock result.adjustment

    network := net.open
    server-socket := network.tcp-listen 80
    clients := []

    // set output 5 default    
    DO5.set 0

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
        melody-channel := Melody DO1

        while true:
          // melody_channel.play "e4e4-=e4-=c4e4-=g4-=-=g3"
          melody-channel.play "c5"
          sleep --ms=120000

    task::
        while true:
          send-to-output DI2 DO2
          send-to-output DI3 DO3
          send-to-output DI4 DO4
          send-to-output DI5 DO5
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
    

