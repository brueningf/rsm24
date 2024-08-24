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
</head>
<body>
    <h1>Remote station server</h1>
    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
      <div>
        <div id="inputs"></div>
        <div id="outputs"></div>
        <div id="messages"></div>
        <input id="input" type="text" placeholder="Type your message and hit Enter...">
      </div>
      <div>
        <h3>ADC4<h3/>
        <canvas id="adc4"></canvas>
        <h3>Temperature<h3/>
        <canvas id="temperature"></canvas>
      </div>
    </div>

<script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.1/chart.umd.js"></script>
<script>
    var ws = new WebSocket('ws://' + window.location.host + '/ws');
    var messages = document.getElementById('messages');
    var input = document.getElementById('input');
    var temperature = [];
    var adc4 = [];

    var tempChart = new Chart(
      document.getElementById('temperature'),
      {
        type: 'line',
        data: {
          labels: temperature.map(row => row.time),
          datasets: [
            {
              label: 'Temperature',
              data: temperature.map(row => row.value)
            }
          ]
        }
      }
    );

    var adc4Chart = new Chart(
      document.getElementById('adc4'),
      {
        type: 'line',
        data: {
          labels: adc4.map(row => row.time),
          datasets: [
            {
              label: 'Voltage',
              data: adc4.map(row => row.value)
            }
          ]
        }
      }
    );

    ws.onmessage = function(event) {
        console.log(event.data)
        var message = document.createElement('p');
        data = JSON.parse(event.data);

        var el = document.getElementById("inputs")
        el.innerHTML = "";

        for(var input in data.inputs) {
          var div = document.createElement('div');
          div.textContent = "DI" + input + ": " + data.inputs[input];
          el.appendChild(div);
        }

        var el = document.getElementById("outputs")
        el.innerHTML = "";

        for(var input in data.outputs) {
          var div = document.createElement('div');
          div.textContent = "DO" + input + ": " + data.outputs[input];
          el.appendChild(div);
        }

        // Create a new Date object from the timestamp
        var date = new Date(Date.now());
        // Format the time as HH:MM:SS
        var currentTime = date.toLocaleString('en-US', { timeZone: 'America/Lima' }).substr(11, 8);
        
        if(data.temperature) {
            temperature.push({
              time: currentTime,
              value: data.temperature 
            }) 

            tempChart.data.labels = temperature.map(row => row.time)
            tempChart.data.datasets[0].data = temperature.map(row => row.value)
            tempChart.update()
        }

        if(data.adc4) {
            if(adc4.length > 20) {
              adc4 = []; 
            }
            adc4.push({
              time: currentTime,
              value: data.adc4 
            }) 
            adc4Chart.data.labels = adc4.map(row => row.time)
            adc4Chart.data.datasets[0].data = adc4.map(row => row.value)
            adc4Chart.update()
        }
        
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