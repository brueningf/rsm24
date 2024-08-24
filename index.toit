index data:
  return """
<!DOCTYPE html>
<html>
<head>
    <title>Chat Server</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background-color: #F5F5F5;
            color: #333;
            padding: 10px;
        }
        #messages {
            height: 70vh;
            border: 1px solid #ddd;
            padding: 10px;
            border-radius: 5px;
            overflow-y: auto;
            margin-bottom: 10px;
            background-color: #fff;
            box-shadow: 0 0 10px rgba(0,0,0,0.1);
        }
        #input {
            width: 100%;
            height: 30px;
            padding: 5px;
            border: 1px solid #ddd;
            border-radius: 5px;
        }
    </style>

    <script src="https://cdn.tailwindcss.com"></script>

    <script src="https://cdnjs.com/libraries/Chart.js"></script>
    <script>var stats = "$data.stringify"</script>
</head>
<body>
    <h1>Remote station server</h1>
    <div class="grid grid-cols-4">
      <div>
        <div id="messages"></div>
        <input id="input" type="text" placeholder="Type your message and hit Enter...">
      </div>
      <div>
        <h3>Temperature<h3/>
        <div id=""></div>
      </div>
    </div>
<script>
    var ws = new WebSocket('ws://' + window.location.host + '/ws');
    var messages = document.getElementById('messages');
    var input = document.getElementById('input');

    ws.onmessage = function(event) {
        console.log(event.data)
        var message = document.createElement('p');
        data = event.data;
        message.textContent = data;
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