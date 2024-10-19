render-view name/string data:
  return """
  <!DOCTYPE html>
  <html>
  <head>
    <title>Central Station</title>
    <link rel="icon" href="data:,">

    <script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3.x.x/dist/cdn.min.js"></script>
    <script src="https://cdn.tailwindcss.com"></script>
  </head>
  <body class="container mx-auto max-w-sm bg-gray-400">
    <h1>Central Station</h1>
    <p>$data</p>
    <h1>Chat Server</h1>
    <div id="messages" class="h-[50vh] overflow-y-scroll bg-gray-300"></div>
    <input id="input" type="text" placeholder="Type your message and hit Enter...">
    <script>
        var ws = new WebSocket('ws://' + window.location.host + '/ws');
        var messages = document.getElementById('messages');
        var input = document.getElementById('input');

        ws.onopen = function() {
            messages.innerHTML = '<p>Connected</p>';
            ws.send(JSON.stringify({type: 'client'}));
        };

        ws.onmessage = function(event) {
            var message = document.createElement('p');
            message.textContent = event.data;
            messages.appendChild(message);
            messages.scrollTop = messages.scrollHeight;

            if (messages.children.length > 50) {
                messages.removeChild(messages.firstChild);
            }
        };

        input.addEventListener('keydown', function(event) {
            if (event.key === 'Enter') {
                ws.send(input.value);
                input.value = '';
                var message = document.createElement('p');
                message.textContent = 'You sent: ' + input.value;
                messages.appendChild(message);
            }
        });
    </script>
  </body>
  </html>
  """
