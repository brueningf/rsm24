import gpio
import gpio.adc
import ntp
import esp32 show adjust-real-time-clock

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
