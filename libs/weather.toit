import i2c
import gpio
import bmp280
import aht20
import log

class Weather:
  sda/int
  scl/int
  address/int

  temperature/float := 0.0
  humidity/float := 0.0
  pressure/float := 0.0
  available/bool := true

  constructor .sda/int .scl/int .address/int=bmp280.I2C-ADDRESS-ALT:

  to-map -> Map:
    return {
      "temperature": temperature,
      "humidity": humidity,
      "pressure": pressure,
    }

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
          device := bus.device address
          driver := bmp280.Bmp280 device
          driver.on
          temperature = driver.read-temperature
          pressure = driver.read-pressure / 100
        if bmp280-exception:
          log.info "Weather: NO BMP280"
          available = false
    
        aht20-exception := catch:
          device := bus.device aht20.I2C-ADDRESS
          driver := aht20.Driver device
          humidity = driver.read-humidity
        if aht20-exception:
          log.info "Weather: NO AHT20"
      finally:
        bus.close
        SDA.close
        SCL.close
    finally:
      log.info "Weather: T: $temperature, H: $humidity, P: $pressure"


