import gpio
X
outs := [27,26,25,13]
main:
  task:: output-circus

  pin := gpio.Pin 16 --output
  while true:
    pin.set 1
    sleep --ms=950
    pin.set 0
    sleep --ms=50
    

output-circus:
  while true:
    outs.do:
      pin := gpio.Pin it --output
      pin.set 0
      sleep --ms=950
      pin.set 1 
      sleep --ms=50
      pin.close
    sleep --ms=1000
  

