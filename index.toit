index data:
  return """
<!DOCTYPE html>
<html>
<head>
    <title>Remote Station Module</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background-color: #F5F5F5;
            color: #000;
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

    <script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3.x.x/dist/cdn.min.js"></script>
    <script src="https://cdn.tailwindcss.com"></script>
</head>
<body>
    <h1>Remote station module</h1>
    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
      <div>
        <div x-data="inputs">
            <h3 class="pl-2 text-xs font-bold uppercase">Inputs</h3>
            <div class="grid grid-cols-6 gap-2 w-full bg-gray-200 border border-black">
                <template x-for="(value, input) in items" :key="input">
                    <div class="flex flex-col items-center justify-center p-2">
                        <span x-text="input" class="text-sm font-bold"></span>
                        <span class="block w-6 h-6 rounded-full py-2" :class="!value ? 'bg-white':'bg-green-500'"></span>
                    </div>
                </template>
            </div>
        </div>
        <div x-data="outputs">
            <h3 class="pl-2 text-xs font-bold uppercase">Outputs</h3>
            <div class="grid grid-cols-6 gap-2 w-full bg-gray-200 border border-black">
                <template x-for="(value, input) in items" :key="input">
                    <div class="flex flex-col items-center justify-center p-2">
                        <span x-text="input" class="text-sm font-bold"></span>
                        <span class="block w-6 h-6 rounded-full py-2" :class="value ? 'bg-white':'bg-green-500'"></span>
                    </div>
                </template>
            </div>
        </div>
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
    window.data = $data;

    document.addEventListener('alpine:init', () => {
        Alpine.data('inputs', () => ({
            init() {
                document.addEventListener('data-update', () => this.items = window.data.inputs)
            },
            items: window.data.inputs,
        }))
        Alpine.data('outputs', () => ({
            init() {
                document.addEventListener('data-update', () => this.items = window.data.outputs)
            },
            items: window.data.outputs,
        }))
        Alpine.data('dropdown', () => ({
            open: false,
 
            toggle() {
                this.open = ! this.open
            }
        }))
    })

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
        var message = document.createElement('p');
        window.data = JSON.parse(event.data)
        document.dispatchEvent(new Event('data-update'))
    
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
        if(event.key === 'Enter') {
            ws.send(input.value);
            input.value = '';
        }
    });

</script>
</body>
</html>
"""