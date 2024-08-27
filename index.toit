index data:
  return """
<!DOCTYPE html>
<html>
<head>
    <title>Remote Station Module</title>

    <script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3.x.x/dist/cdn.min.js"></script>
    <script src="https://cdn.tailwindcss.com"></script>
</head>
<body>
    <h1 class="font-bold text-center uppercase">Remote station module</h1>
    <div class="grid grid-cols-1 md:grid-cols-2 gap-4 m-4">
      <div>
        <h3>Water Level<h3/>
        <canvas id="water-level"></canvas>
        <h3>Temperature<h3/>
        <canvas id="temperature"></canvas>
      </div>
      <div class="grid grid-cols-1 gap-4">
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
        <div x-data="adcs">
            <h3 class="pl-2 text-xs font-bold uppercase">ADCs + Flow Di1</h3>
            <div class="grid grid-cols-4 gap-2 w-full bg-gray-200 border border-black">
                <template x-for="(value, input) in items" :key="input">
                    <div class="flex flex-col items-center justify-center p-2">
                        <span x-text="input" class="text-sm font-bold uppercase"></span>
                        <span x-text="value" class="block p-2 border border-black"></span>
                    </div>
                </template>
            </div>
        </div>
        <div x-data="settings">
            <h3 class="pl-2 text-xs font-bold uppercase">Settings</h3>
            <form x-on:submit.prevent="submit" class="w-full bg-gray-200 border border-black">
                <div class="grid grid-cols-4 gap-2">
                    <template x-for="(value, input) in items" :key="input">
                        <div class="flex flex-col items-center justify-center p-2">
                            <span x-text="input" class="text-sm font-bold uppercase"></span>
                            <input class="w-full" type="text" :value="value" :name="input" required> 
                        </div>
                    </template>
                </div>
                <button class="p-1 border border-black m-2" type="submit">Save</button>
            </form>
        </div>
        <div id="messages" class="w-full mt-2 overflow-scroll bg-gray-200 border border-black p-1 h-[50vh]"></div>
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
        Alpine.data('adcs', () => ({
            init() {
                document.addEventListener('data-update', () => this.items = {
                    adc4: window.data.adc4 + "V",
                    adc6: window.data.adc6 + "V",
                    flowl: window.data.flowl,
                    flow: window.data.flow,
                })
            },
            items: {
                adc4: window.data.adc4 + "V",
                adc6: window.data.adc6 + "V",
                flowl: window.data.flowl,
                flow: window.data.flow,
            },
        }))
        Alpine.data('settings', () => ({
            init() {
                document.addEventListener('data-update', () => {
                    this.items.wlmin = window.data.wlmin
                    this.items.wlmax = window.data.wlmax
                })
            },
            items: {
                wlmin: window.data.wlmin,
                wlmax: window.data.wlmax,
            },
            submit(e) {
                const formData = new FormData(e.target);
                const jsonObject = {};
    
                formData.forEach((value, key) => {
                    jsonObject[key] = value;
                });
    
                fetch('/constants/update', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify(jsonObject),
                })
            }
        }))
    })

    var ws = new WebSocket('ws://' + window.location.host + '/ws');
    var messages = document.getElementById('messages');
    var input = document.getElementById('input');
    var temperature = [];

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
        },
        options: { 
            scales: { 
                y: { min: -30, max: 100 },
            }
        }
      }
    );

    var waterLevelChart = new Chart(
      document.getElementById('water-level'),
      {
        type: 'bar',
        data: {
          labels: ['Tank A'],
          datasets: [
            {
              label: 'Water level',
              data: ['1.5']
            }
          ]
        },
        options: {
            scales: {
                y: {
                    min: 0,
                    max: 100,
                }
            }
        }
      }
    );

    ws.onmessage = function(event) {
        var message = document.createElement('p');
        window.data = JSON.parse(event.data)
        document.dispatchEvent(new Event('data-update'))
    
        var date = new Date(Date.now());
        var currentTime = date.toLocaleString('en-US', { timeZone: 'America/Lima' }).substr(11, 8);
        
        if(data.temperature) {
            if(temperature.length == 0 || data.temperature !== temperature[temperature.length -1].value) {
                temperature.push({
                    time: currentTime,
                    value: data.temperature 
                }) 

                tempChart.data.labels = temperature.map(row => row.time)
                tempChart.data.datasets[0].data = temperature.map(row => row.value)
                tempChart.update()
            }
        }

        if(data.adc4) {
            val = ((data.adc4 - data.wlmin) * 100) / (data.wlmax - data.wlmin)

            waterLevelChart.data.datasets[0].data = [val]
            waterLevelChart.update()
        }
        
        message.textContent = event.data;
        messages.appendChild(message);
        messages.scrollTop = messages.scrollHeight;
    };
</script>
</body>
</html>
"""