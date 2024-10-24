render-view name/string data:
  if name == "index":
    return index data
  else if name == "login":
    return login
  else:
    return "404 Not Found"

login:
  return layout ("""
    <script>
        function login() {
            return {
                username: '',
                password: '',
                submit(e) {
                    fetch('/login', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json',
                        },
                        body: JSON.stringify({username: this.username, password: this.password}),
                    }).then(response => {
                        if (response.ok) {
                            window.location.href = '/';
                        } else {
                            alert('Login failed');
                        }
                    });
                }
            };
        }
    </script>
    <form action="/login" method="POST" class="p-4 grid gap-4" x-data="login" x-on:submit.prevent="submit">
    <h1>Login</h1>
    $(form-input "username" "text" "required")
    $(form-input "password" "password" "required")
    $(button "Login" "submit")
    </form>
  """)

layout content/string:
  return """
  <!DOCTYPE html>
  <html>
  <head>
    <title>Central Station</title>
    <link rel="icon" href="data:,">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3.x.x/dist/cdn.min.js"></script>
    <script src="https://cdn.tailwindcss.com"></script>
  </head>
  <body class="max-w-sm mx-auto bg-stone-900">
    <main class="relative bg-stone-600 text-black">
    $nav-bar
    $content
    </main>
  </body>
  </html>
  """
index data/any:
  return layout """
    <script>
        window.data = $data;

        function config() {
            return {
                items: window.data.config,
                submit(e) {
                    fetch('/config', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json',
                        },
                        body: JSON.stringify(this.items),
                    })
                }
            };
        }
    </script>
    <h1>Central Station</h1>
    <div id="settings" class="bg-gray-300 p-2">
      <form x-data="config" x-on:submit.prevent="submit">
        <template x-for="(value, key) in items" :key="key">
            <div class="flex items-center">
                <label x-text="key" for="key" class="w-1/2"></label>
                <input x-model="items[key]" id="key" type="text" name="key" class="w-1/2" required>
            </div>
        </template>
        <button type="submit">Submit</button>
      </form>

    </div>
    <h1>Chat Server</h1>
    <div id="messages" class="h-[50vh] overflow-y-scroll bg-gray-300 p-2"></div>
    <input id="input" type="text" placeholder="Type your message and hit Enter...">
    </main>
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
            message.classList.add('mb-1');
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
  """

button content/string type/string="button":
  return """
  <button 
    type="$type"
    class="cursor-pointer whitespace-nowrap rounded-md bg-black px-4 py-2 text-xs font-medium tracking-wide text-neutral-100 transition hover:opacity-75 text-center focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-black active:opacity-100 active:outline-offset-0 disabled:opacity-75 disabled:cursor-not-allowed">
    $content
  </button>
"""

form-input name/string type/string="text" required/string="":
  return """
  <div class="flex w-full max-w-xs flex-col gap-1 text-black">
    <label for="$name" class="w-fit pl-0.5 text-sm">$name</label>
    <input id="$name" type="$type" class="w-full rounded-md border border-neutral-300 bg-neutral-50 px-2 py-2 text-sm focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-black disabled:cursor-not-allowed disabled:opacity-75" name="$name" $required x-model="$name"/>
  </div>
  """

nav-bar:
  return """
<nav x-data="{ mobileMenuIsOpen: false }" @click.away="mobileMenuIsOpen = false" class="relative flex items-center justify-between px-6 py-4">
	<!-- Brand Logo -->
	<a href="#" class="text-2xl font-bold">
        Pii - MSi
	</a>
	<!-- Mobile Menu Button -->
    <button @click="mobileMenuIsOpen = !mobileMenuIsOpen" :aria-expanded="mobileMenuIsOpen" :class="mobileMenuIsOpen ? 'fixed sm:absolute top-6 right-6 z-20' : null" type="button" class="flex text-neutral-600 dark:text-neutral-300" aria-label="mobile menu" aria-controls="mobileMenu">
		<svg x-cloak x-show="!mobileMenuIsOpen" xmlns="http://www.w3.org/2000/svg" fill="none" aria-hidden="true" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor" class="size-6">
			<path stroke-linecap="round" stroke-linejoin="round" d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5" />
		</svg>
		<svg x-cloak x-show="mobileMenuIsOpen" xmlns="http://www.w3.org/2000/svg" fill="none" aria-hidden="true" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor" class="size-6">
			<path stroke-linecap="round" stroke-linejoin="round" d="M6 18 18 6M6 6l12 12" />
		</svg>
	</button>
	<!-- Mobile Menu -->
	<ul x-cloak x-show="mobileMenuIsOpen" 
        x-transition:enter="transition motion-reduce:transition-none ease-out duration-300" 
        x-transition:enter-start="-translate-y-full" x-transition:enter-end="translate-y-0" 
        x-transition:leave="transition motion-reduce:transition-none ease-out duration-300" 
        x-transition:leave-start="translate-y-0" x-transition:leave-end="-translate-y-full" 
        id="mobileMenu" 
        class="fixed sm:absolute max-h-svh overflow-y-auto top-0 left-0 w-full z-10 flex flex-col divide-y divide-white border-b border-white bg-black/90 px-6 pb-6 pt-20">
		<li class="py-4"><a href="/info" class="w-full text-lg font-medium text-white focus:underline">Info</a></li>
		<li class="py-4"><a href="/login" class="w-full text-lg font-medium text-white focus:underline">Login</a></li>
	</ul>
</nav>
"""
