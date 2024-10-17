import gpio
import gpio.adc

read-adc pin/int -> string:
  adc := adc.Adc (gpio.Pin pin)
  value := adc.get.stringify 2
  adc.close
  return value

read-gpio number/int -> int:
  pin := gpio.Pin number --input
  value := pin.get
  pin.close
  return value

