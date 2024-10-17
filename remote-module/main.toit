import system
import gpio
import gpio.adc
import ..libs.broadcast
import ..libs.utils

main:
  central-station-ip := search-central-station
  print "Central station found at $central-station-ip"
  system.print-objects --gc
  // read broadcasted data
  // search for central station
  // save temporal ip
  // start sending data to central station
  // start receiving data from central station
