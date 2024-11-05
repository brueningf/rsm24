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
  exception := catch:
    pin := gpio.Pin number --input
    value := pin.get
    pin.close
    return value
  if exception:
    print "Exception: $exception on pin $number"
  return 2

write-gpio number/int value/int:
  pin := gpio.Pin number --output
  pin.set value

trigger-heartbeat n/int v/int=0:
  pin := gpio.Pin n --output
  pin.set v
  sleep (Duration --us=10)
  pin.set (1 - v)
  sleep --ms=999
  pin.close

trigger-pin n/int v/int=0:
  pin := gpio.Pin n --output
  pin.set v
  sleep --ms=1000
  pin.set (1 - v)
  sleep --ms=1000
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
