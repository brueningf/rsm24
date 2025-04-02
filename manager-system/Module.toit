import gpio
import gpio.adc
import encoding.json
import log
import net
import ..libs.weather

class Module:
  id /string := ?
  ip /any := null
  online /bool := true
  inputs /List := []
  outputs /List := []
  analog-inputs /List := []
  pulse-counters /List := []
  weather /Weather := ?
  last-seen /Time := ?

  constructor id_/string _inputs/List _outputs/List _analog-inputs/List _pulse-counters/List --sda=47 --scl=48:
    id = id_
    _inputs.do:
      inputs.add (Input it)
    _outputs.do:
      if it is List:
        outputs.add (Output it[0] it[1])
      else:
        outputs.add (Output it)
    _analog-inputs.do:
      analog-inputs.add (AnalogInput it)

    weather = Weather sda scl

    last-seen = Time.now

  update-state:
    inputs.do:
      it.read
    analog-inputs.do:
      it.read

  read-weather:
    if weather and weather.available:
      weather.read

  stringify -> string:
    return json.stringify to-map

  to-map -> Map:
    return {
      "id": id,
      "ip": ip.stringify,
      "inputs": inputs.map: it.to-map,
      "outputs": outputs.map: it.to-map,
      "analog-inputs": analog-inputs.map: it.to-map,
      "weather": weather.to-map,
      "online": online.stringify,
      "last-seen": last-seen.stringify
    }

abstract class GenericPin:
  type /string := "generic"
  pin /any := 0
  value /int := 0

  to-map -> Map:
    if pin is int:
      return {
        "pin": pin,
        "value": value,
      }
    else if type == "output":
      return to-map
    else:
      return {
        "value": value,
      }

class Input extends GenericPin:
  constructor _pin/int:
    pin = _pin
    type = "input"

  read -> int:
    p := gpio.Pin pin --input
    value = p.get
    p.close
    return value

class Output extends GenericPin:
  pin /gpio.Pin := ?
  manual /bool := false

  constructor _pin/int _value/int=0:
    pin = gpio.Pin _pin --output
    type = "output"
    value = _value
    pin.set value

  set _value/int:
    if manual:
      return
    value = _value
    pin.set value

  force-set _value/int:
    manual = not manual
    value = _value
    pin.set value
 
  to-map:
      return {
        "pin": pin.num,
        "value": value,
        "manual": manual,
      }


class AnalogInput extends GenericPin:
  value /float := 0.0
  constructor _pin/int:
    pin = _pin

  read -> float:
    p := gpio.Pin pin --input
    ap := adc.Adc p
    value = ap.get
    ap.close
    p.close
    return value

class PulseCounter:
  pin /int := ?

  constructor _pin/int:
    pin = _pin

