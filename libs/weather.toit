import i2c
import bmp280
import aht20

class Weather:
  bus/i2c.Bus

  constructor sda/int scl/int:
    bus = i2c.Bus --sda=I2C-SDA --scl=I2C-SCL

  read:
    bmp280-exception := catch:
      device := bus.device bmp280.I2C_ADDRESS_ALT
      driver := bmp280.Bmp280 device
    if bmp280-exception:
      print "NO BMP280"
      return 0
    //aht20-device := bus.device aht20.I2C_ADDRESS
    //aht20-driver := aht20.Driver aht20-device

    temperature := driver.read-temperature

    return temperature


