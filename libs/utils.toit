import gpio
import gpio.adc

read-adc number/int -> string:
  pin := gpio.Pin number
  adc := adc.Adc pin
  value := adc.get.stringify 2
  adc.close
  pin.close
  return value

read-gpio number/int -> int:
  pin := gpio.Pin number --input
  value := pin.get
  pin.close
  return value

write-gpio number/int value/int:
  pin := gpio.Pin number --output
  pin.set value
  pin.close
