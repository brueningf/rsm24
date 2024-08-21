import gpio
import gpio.adc

main:
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
    
    I2C_SDA := gpio.Pin 33 
    I2C_SCL := gpio.Pin 22  

    SPI_MISO := gpio.Pin 19 
    SPI_MOSI := gpio.Pin 23 
    SPI_CLK := gpio.Pin 18 
    SPI_CS := gpio.Pin 5
    SPI_RESET := gpio.Pin 17

    ADC1_6 := adc.Adc (gpio.Pin 34)
    ADC1_4 := gpio.Pin 32

    PPCTGR := gpio.Pin 2 --output
    PPCTGR.set 1
    CLOLVL := gpio.Pin 21 --input
    
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
          DO1.set 1
          sleep --ms=10
          DO1.set 0
          sleep --ms=5000

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
    

