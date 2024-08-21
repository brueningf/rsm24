import gpio
import gpio.adc

main:
    DO1 = gpio.Pin 27 --output
    DO2 = gpio.Pin 26 --output
    DO3 = gpio.Pin 25 --output
    DO4 = gpio.Pin 14 --output
    // DO5 = gpio.Pin 14 --output
    
    DI1 = gpio.Pin 35 --input
    DI2 = gpio.Pin 13 --input
    DI3 = gpio.Pin 4 --input
    DI4 = gpio.Pin 16 --input
    DI5 = gpio.Pin 17 --input
    
    I2C_SDA = gpio.Pin 33 
    I2C_SCL = gpio.Pin 22  

    SPI_MISO = gpio.Pin 19 
    SPI_MOSI = gpio.Pin 23 
    SPI_CLK = gpio.Pin 18 
    SPI_CS = gpio.Pin 39 

    ADC1_6 = adc.Adc (gpio.Pin 34)
    ADC1_4 = gpio.Pin 32

    PPCTGR = gpio.Pin 2 --output
    CLOLVL = gpio.Pin 21 --input

    blink DO1
    blink DO2
    blink DO3
    blink DO4

blink pin/gpio.Pin:
    pin.set 1
    sleep --ms=1000
    pin.set 0
