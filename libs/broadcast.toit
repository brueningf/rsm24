import net
import i2c
import gpio
import net.udp
import encoding.json

search-central-station -> string:
  client := Client
  while true:
    print "Searching for central station"
    data := client.receive
    data = json.parse data

    if data["type"] == "central-station":
      return data["ip"]
    print "Central station not found. Retrying in 5 seconds"
    sleep --ms=5000

class Server:
  static DEFAULT_PORT ::= 3000
  static DEFAULT_MASK ::= "192.168.1.255"
  address/net.SocketAddress
  socket/udp.Socket

  constructor --port=DEFAULT_PORT --mask=DEFAULT_MASK :
    address = net.SocketAddress
      net.IpAddress.parse mask
      port

    network := net.open
    socket = network.udp_open
    socket.broadcast = true

  get-address -> string:
    return address.ip.stringify

  /**
  Broadcasts the $value on the configured address.

  The $value must be JSON encodeable.
  */
  broadcast value:
    data := json.encode value
    socket.send
      udp.Datagram data address

  /**
  Calls $read_value every $interval and broadcasts the value.
  */
  periodic-broadcast interval/Duration [read_value]:
    interval.periodic:
      broadcast read_value.call

class Client:
  static DEFAULT_PORT ::= 3000
  static DEFAULT_MASK ::= "192.168.1.255"
  socket/udp.Socket

  constructor --port=Server.DEFAULT_PORT:
    network := net.open
    socket = network.udp_open --port=port

  receive:
    datagram := socket.receive
    while true:
      e := catch:
        data := json.decode datagram.data
        return data

  receive --continuous=false [on_receive]:
    received := false
    while continuous or not received:
      on_receive.call receive
      received = true
