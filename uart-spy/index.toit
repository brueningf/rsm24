import ..libs.weather

INDEX-HTML module-name/string:
  return """
<!DOCTYPE html>
<html>
<head>
    <title>UART Spy - $module-name</title>
    <link href="https://unpkg.com/tailwindcss@^1.0/dist/tailwind.min.css" rel="stylesheet">
</head>
<body>
    <h1 class="text-lg">UART Spy ($module-name)</h1>
    <a href="/reset">RESET</a>
    <div class="grid grid-cols-2 gap-2 h-screen max-h-screen">
      <div>
        <h3 class="text-lg font-bold">Target</h3>
        <div id="messages-target" class="min-h-96 border-2 border-black p-1 bg-yellow-100 overflow-y-scroll"></div>
      </div>
      <div>
        <h3 class="text-lg font-bold">Self</h3>
        <div id="messages-me" class="min-h-96 border-2 border-black p-1 bg-red-100 overflow-y-scroll"></div>
      </div>
    </div>
<script>
    var ws = new WebSocket('ws://' + window.location.host + '/ws');
    var messagesTarget = document.getElementById('messages-target');
    var messagesMe = document.getElementById('messages-me');
    var input = document.getElementById('input');

    ws.onmessage = function(event) {
        var message = document.createElement('p');
        message.textContent = event.data;
        if (event.data.indexOf("TARGET") != -1) {
          messagesTarget.appendChild(message);
          messagesTarget.scrollTop = messages.scrollHeight;
        } else if(event.data.indexOf("ME") != -1) {
          messagesMe.appendChild(message);
          messagesMe.scrollTop = messages.scrollHeight;
        }
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