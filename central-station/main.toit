import system
import http
import net
import encoding.json
import ..libs.broadcast

view name/string data:
  return """
  <!DOCTYPE html>
  <html>
  <head>
    <title>Central Station</title>
    <link rel="icon" href="data:;base64,=">
  </head>
  <body>
    <h1>Central Station</h1>
    <p>$data</p>
    <h1>Chat Server</h1>
    <div id="messages"></div>
    <input id="input" type="text" placeholder="Type your message and hit Enter...">
    <script>
        var ws = new WebSocket('ws://' + window.location.host + '/ws');
        var messages = document.getElementById('messages');
        var input = document.getElementById('input');

        ws.onmessage = function(event) {
            var message = document.createElement('p');
            message.textContent = event.data;
            messages.appendChild(message);
            messages.scrollTop = messages.scrollHeight;
        };

        input.addEventListener('keydown', function(event) {
            if (event.key === 'Enter') {
                ws.send(input.value);
                input.value = '';
            }
        });
    </script>
  </body>
  </html>
  """
advertise-central-station:
  broadcast := Server
  network := net.open
  my-ip := network.address
  network.close
  broadcast.periodic-broadcast (Duration --s=30):
    print "Broadcasting central station at $my-ip"
    msg := {"type": "central-station", "ip": "$my-ip"}
    json.stringify msg

main:
  task:: advertise-central-station

  clients := []
  network := net.open
  server := (http.Server --max-tasks=4)
  server.listen network 80:: | request/http.RequestIncoming writer/http.ResponseWriter |
    if request.path == "/":
      writer.headers.set "Content-Type" "text/html"
      writer.headers.set "Connection" "close"
      writer.out.write (view "index" (json.stringify "data"))
    else if request.path == "/ws":
      web-socket := server.web-socket request writer
      clients.add web-socket
      print clients
      while data := web-socket.receive:
        print "Received: $data"
        print "Sending to clients: $clients"
        clients.do: 
          tcp-exception := catch:
            it.send data
          if tcp-exception:
            print "Exception: $tcp-exception"
            clients.remove it
      clients.remove web-socket
    else:
      writer.headers.set "Content-Type" "text/plain"
      writer.out.write "Not found 404"
    writer.close
