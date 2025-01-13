import gpio
import gpio.adc
import encoding.json
import log
import net

class Module:
  id /string := ?
  ip /any := null
  inputs /List := []
  outputs /List := []
  analog-inputs /List := []
  pulse-counters /List := []

  constructor id_/string _inputs/List _outputs/List _analog-inputs/List _pulse-counters/List:
    id = id_
    _inputs.do:
      inputs.add (Input it)
    _outputs.do:
      outputs.add (Output it)
    _analog-inputs.do:
      analog-inputs.add (AnalogInput it)

  update-state:
    inputs.do:
      it.read
    analog-inputs.do:
      it.read

  stringify -> string:
    return json.stringify to-map

  to-map -> Map:
    return {
      "id": id,
      "ip": ip.stringify,
      "inputs": inputs.map: it.to-map,
      "outputs": outputs.map: it.to-map,
      "analog-inputs": analog-inputs.map: it.to-map,
    }

abstract class GenericPin:
  pin /any := 0
  value /int := 0

  to-map -> Map:
    if pin is int:
      return {
        "pin": pin,
        "value": value
      }
    else if pin is gpio.Pin:
      return {
        "pin": pin.num,
        "value": value
      }
    else:
      return {
        "value": value
      }

class Input extends GenericPin:
  constructor _pin/int:
    pin = _pin

  read -> int:
    p := gpio.Pin pin --input
    value = p.get
    p.close
    return value

class Output extends GenericPin:
  pin /gpio.Pin := ?
  constructor _pin/int value/int=0:
    pin = gpio.Pin _pin --output
    pin.set value

  set value_/int:
    value = value_
    pin.set value

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

