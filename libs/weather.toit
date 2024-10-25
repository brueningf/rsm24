import i2c
import gpio
import bmp280
import aht20

class Weather:
  sda/int
  scl/int
  temperature/float := 0.0
  humidity/float := 0.0
  pressure/float := 0.0
  available/bool := true

  constructor .sda/int .scl/int:

  read:
    if not available:
      return

    SDA := null
    SCL := null

    gpio-except := catch:
      SDA = gpio.Pin sda
      SCL = gpio.Pin scl
    if gpio-except:
      print "Weather: GPIO exception"
      available = false
      return

    try:
      bus := i2c.Bus --sda=SDA --scl=SCL
  
      try:
        bmp280-exception := catch:
          device := bus.device bmp280.I2C_ADDRESS_ALT
          driver := bmp280.Bmp280 device
          temperature = driver.read-temperature
          pressure = driver.read-pressure / 100
        if bmp280-exception:
          print "Weather: NO BMP280"
    
        aht20-exception := catch:
          device := bus.device aht20.I2C-ADDRESS
          driver := aht20.Driver device
          humidity = driver.read-humidity
        if aht20-exception:
          print "Weather: NO AHT20"
      finally:
        bus.close
        SDA.close
        SCL.close
    finally:
      print "Weather: Read"


