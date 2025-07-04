


# Elixir MAX (MAX Messenger API adapter)

Lightweight:
* Thin! No extra sugar! Just raw official [vendor's API](https://dev.max.ru/docs-api).
* Easy and flexible: one-line deployment with various settings.
* Scalable with [Mint](https://github.com/elixir-mint/mint) & [Finch](https://github.com/sneako/finch)
* [Pluggable](https://hexdocs.pm/plug/readme.html) WebHooks routes for web server.
* Duplicable: means that you can harmoniously use multiple bots in one project, including using one or more different Finch pools or one or more web servers.

## Installation
Add `elixir_max` to your list of dependencies in `mix.exs`:
```elixir
def deps do
  [
    {:elixir_max, github: "addagger/elixir_max"}
  ]
end
```

## Built-in example (MAX.ExampleBot)
Сonfigure MAX Bot token (config/config.exs):
```elixir
config :elixir_max, MAX.ExampleBot, token: "q6LHodR0cOPegA3ZXC-bfhuk3uiu7eEEawIOYD4EKRtT1yeQAZWn7oUU7KaYtOZOpo-dEp7Ax9zNT1ewG23W"
```
Start `MAX.ExampleBot`:

```elixir
children = [MAX.ExampleBot]
opts = [strategy: :one_for_one]
Supervisor.start_link(children, opts)
```
Try in console:
```
% iex -S mix
```
```
iex(1)> MAX.ExampleBot.get("/me")
```
```
{:ok,
  %{
    "description" => "Welcome to the brand new digital",
    "first_name" => "Vladimir",
    "is_bot" => true,
    "last_activity_time" => 1751572821301,
    "name" => "MAX test bot",
    "user_id" => 000001,
    "username" => "username"
  }
}
```
Then try something to message the bot...

## Setup
### Define your own bot module:
```elixir
defmodule MyBot do
  use MAX.Bot
end
```
This means creating stack of five modules - everything you basically need to create chat bot:
1. `MyBot.Api` - just pre-configured and pre-compiled HTTP client for MAX Bot API server, which using [Tesla](https://github.com/elixir-tesla/tesla) with [Finch](https://github.com/sneako/finch) adapter, based on [Mint](https://github.com/elixir-mint/mint). Finch is a great tool for managing multiple connections to an API server via a pool. The best alternative to [Hackney](https://github.com/benoitc/hackney) except it much less blackboxed.
2. `MyBot.Uploader` - pre-configured and pre-compiled HTTP client for CDN servers to upload files. It also using Tesla with Finch adapter, based on Mint. Finch adapter is the same as `MyBot.Api`'s ones.
3. `MyBot.Poller` - just pre-compiled looping Task process to GET [/updates](https://dev.max.ru/docs-api/methods/GET/updates) from the API server. Poller gets updates from an API server and send it to the behaviour module.
4. `MyBot.Router` - [Plug.Router](https://hexdocs.pm/plug/Plug.Router.html) defines routes for Bandit (or Cowboy) webserver, which responsible to handling updates data from API and sending it to the behaviour module.
5. The `MyBot` itself is a behaviour module which defines the main logic of your bot. Each runtime session lives as a GenServer process and cast API updates to a `MyBot.handle_updates/2`. Life-cycle callbacks are also being sended to a behaviour module:
* `MyBot.handle_timeout/2`
* `MyBot.handle_info/3`
* `MyBot.handle_error/5`

All functions are overrideable.

### Configure
All settings are set in the configuration file (config/config.exs).
For example, **necessary and sufficient** would be just MAX Bot token:

```elixir
config :elixir_max, MyBot, token: "q6LHodR0cOPegA3ZXC-bfhuk3uiu7eEEawIOYD4EKRtT1yeQAZWn7oUU7KaYtOZOpo-dEp7Ax9zNT1ewG23W"
```
Full config-defaults for `MyBot` look like this:
```elixir
config :elixir_max, MyBot,
  token: "q6LHodR0cOPegA3ZXC-bfhuk3uiu7eEEawIOYD4EKRtT1yeQAZWn7oUU7KaYtOZOpo-dEp7Ax9zNT1ewG23W",
  base_url: "https://botapi.max.ru",
  max_retries: 5, # Option for https://hexdocs.pm/tesla/Tesla.Middleware.Retry.html
  finch_specs: [
    name: MyBot.Finch,
    pools: %{
      :default => [size: 500, count: 1],
      "https://botapi.max.ru" => [size: 500, count: 1, start_pool_metrics?: true]
    }
  ], # Read https://hexdocs.pm/finch/Finch.html
  finch_name: MyBot.Finch, # You can define your own Finch pool outside
  uploader: [
    chunk_size: 65536,
    max_retries: 15 # Option for https://hexdocs.pm/tesla/Tesla.Middleware.Retry.html
  ]
  max_sessions: 500, # How many runtime processes can your bot handle
  session_timeout: 60, # Seconds does a process live when idle.
  poller: [
    tmp_file: "/tmp/MyBot_abcdefg_poller_marker.tmp", # Specify path to the file that contains the latest marker for Poller (marker+1)
    limit: nil, # GET /updates request parameter, not used if `nil`.
    timeout: 30, # GET /updates request parameter
    allowed_updates: nil, # GET /updates request parameter, not used if `nil`
    inspect_updates: true # Inspect updates in console
  ],
  webhook: [
    path: "/max/randomtoken" # Endpoint for Plug.Router to accept WebHook incomes from API server.
  ]
  
```

### Starting your Bot (in poller mode by default)
Your `MyBot` is now the supervisor Application itself. Starting `MyBot` you're starting linked `MyBot.Poller` sub-application as well (unless WebHooks parameters is set up to the API server, Poller is cheking it while initializing).
Poller is just pre-compiled looping Task process to GET [/updates](https://dev.max.ru/docs-api/methods/GET/updates) from the API server.

Anyway, start your `MyBot` linked as usual (no options provided):

```elixir
children = [MyBot]
opts = [strategy: :one_for_one]
Supervisor.start_link(children, opts)
```

```
22:17:58.627 [info] Running MyBot in polling mode
```
Now your `MyBot.Poller` is looping task to get updates from MAX server.

### Starting in WebHook mode
As mentioned before, you have `MyBot.Router` - [Plug.Router](https://hexdocs.pm/plug/Plug.Router.html) ready to use module.

Then you have to load pluggable webserver if you didn't, [Bandit](https://hexdocs.pm/bandit/Bandit.html) for example. You have to do it on your own, because in many cases one web server can handle multiple task according to your application logic and loading another instance may be redundant. You can create your custom router module and use it sharing between multiple different tasks, who knows.

So if you ready, just plug your `MyBot.Router` after the `MyBot` into the loading chain:
```elixir
children = [MyBot, {Bandit, plug: MyBot.Router, scheme: :http, port: 4000}]
opts = [strategy: :one_for_one]
Supervisor.start_link(children, opts)
```
I use simple example when my web server Bandit accepts everything to port 4000, staying on my local machine. I'm going to accept MAX WebHook requests through a dedicated Nginx web server which is handling external requests on a world-looking machine, so I need to:
1. Come up with a URL path to which MAX should send webhook requests. You can create whatever URL path behind your web interface and put it to bot's config parameter like `webhook: [path: "/mybotwebhook"]`.
But *by default* your `MyBot.Router` uses a generated path based on the token and the module name:
```elixir
iex(1)> MyBot.Router.webhook_path
"/max/SDYUKBMrflgsdo8FGffmm"
```
Keep in mind that endpoint is used just by your local Bandit instance.
In my case the real world-looking web interface managed by Nginx, thus it is reasonable for me to configure Nginx to `proxy_pass` WebHook request to a local machine. And I couldn't think of anything better than to use almost the same path in the Nginx interface: `/nginx/max/SDYUKBMrflgsdo8FGffmm` to accept WebHook request.

2. Next, let's tell MAX API about URL (or direct IP) for WebHook requests we've just chosen. In my case I use direct IP address instead of domain name:
```elixir
iex(1)> MyBot.Poller.stop
:ok
iex(1)> MyBot.post("setWebhook", %{ip_address: "X.X.X.X", url: "https://X.X.X.X/nginx/max/SDYUKBMrflgsdo8FGffmm", certificate: {:file, "/path/to/cert.pem"}})
```
3. Now configure Nginx how to `proxy_pass` to my local Bandit web server.
/etc/nginx/nginx.conf:
```nginx
http {
  upstream mybot {
    server X.X.X.X:4000; # Bandit's IP and port
  }
  server {
    listen 443 ssl; # HTTPS
    server_name  X.X.X.X; # ext IP address
    ssl_certificate  /path/to/cert.pem; # Certificate we loaded to MAX API
    ssl_certificate_key  /path/to/cert.key;
    location /nginx/max/SDYUKBMrflgsdo8FGffmm { # Nginx's endpoint
       proxy_pass http://mybot/max/SDYUKBMrflgsdo8FGffmm; # Bandit's endpoint
       proxy_set_header Host $host;
       proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
       proxy_set_header X-Scheme $scheme;
       proxy_set_header X-Real-IP $remote_addr;
       proxy_redirect off;
    }
  }
}
```
That's it. Restart Nginx. Restart `MyBot` Application and everything should work.

## Create your MAX Bot
All examples are ready to try in `MAX.ExampleBot`.
### handle_update/2:
Each update is sent for processing by callback function `handle_update/2` within your bot module:
Function accepts only 2 arguments: current `update` to process and `bot_state` entity.
* `update` is just a Map respond from API server.
* `bot_state` is an entity to store the current state of the chat. Technically, it is related to the state of the GenServer process and is most often needed to inherit states between user activities according to the application logic.

Bot state lives with a runtime session. Runtime session is linked to the `chat_id` (or `user_id` if no chat id by any change provided) and starts when the first update comes from particular chat (or user). When chat (user) starts runtime session, `bot_state` is passed to `handle_update/2` and it is a copy of the `session_key` at start.
___
**Session key** used in the registry identifier of the [GenServer](https://hexdocs.pm/elixir/GenServer.html) process that represents the runtime session. By default, `session_key` is a tuple `{:chat_id, chat_id}` which means that session processes are initiated from the uniqueness of the current chat. Simply speaking: each chat has its own process by default. Depending on the logic of your application, the key can be changed by overriding `session_key/1` function:
```elixir
defmodule MyBot do
  use MAX.Bot

  def session_key(update) do
    with {_update_type, %{chat: %{"chat_id" => chat_id}, user: %{"user_id" => user_id}}} <- MAX.Helper.extract_chat_user(update) do
      {chat_id, user_id} # With this key, every user in a group will have his own process.
    else
      _ ->
        chat_id = MAX.Helper.extract_chat_id(update)
        {:chat_id, chat_id}
    end
  end
end
```
Session key could be of any data type of Elixir/Erlang.
___
If your app logic presumes to share any data between user activities, you can use that data as a `bot_state` returning `{:ok, bot_state}` from `handle_update/2`. That the way `bot_state` passes between user actions.
* `bot_state` is an any of Elixir data type.
```elixir
defmodule MyBot do
  use MAX.Bot

  def handle_update(%{"update_type" => "message_created", "message" => %{"sender" => sender, "body" => %{"text" => _text}}}, bot_state) do
    bot_state = if not is_integer(bot_state), do: 1, else: bot_state+1
    # this function just count messages during the session
    username = sender["first_name"]
    post("/messages", %{text: "Hello, #{username}. You messaged #{bot_state} times."}, user_id: sender["user_id"])
    {:ok, bot_state}
  end
  
  def handle_update(_update, bot_state) do
    {:ok, bot_state} # just return bot_state
  end
end
```
This callback function must return one of three possible matches of respond which determine the fate of the current session:
* `{:ok, bot_state}` - bot state is saved and transmitted to the next update processing (next `handle_update/2` call).
* `{:ok, bot_state, timeout}` - same as before, and the idle timeout for session is updated to `timeout` (see next chapter).
 * `{:stop, bot_state}` - stop session gracefully.

### What timeout is?
If the user is inactive, his session is idle. After some time of inactivity, the session is destroyed. This time is determined by the `timeout` (read the GenServer [docs](https://hexdocs.pm/elixir/GenServer.html#module-timeouts) for advance). If the user logs in again, a new session is created.
Sometimes it is very often necessary to adjust the timeout so that the bot waits for the user when it is necessary and does not wait when it is not necessary.
Thus some of responds of the bot has to return `{:ok, bot_state, timeout}` instead of `{:ok, bot_state}`.

`timeout` may be defined as the next data types:
* `pos_integer()`, positive integer, determines **seconds**;
* `:infinity` atom represents infinity timeout when session never expired;
* `:default` atom represents default timeout setting;
* tuple `{timeout_now, timeout_next}` where the first element is to return now, and the second timeout for the next call. Each of them in turn can be `pos_integer()`, `:infinity` or  `:default`. 
```elixir
def handle_update(%{"message" => %{"text" => "wait", "chat" => %{"id" => chat_id}}}, bot_state) do
  post("sendMessage", %{text: "Im waiting 2 minutes", chat_id: chat_id})
  {:ok, bot_state, 120}
end
  ```
### Other callbacks
#### handle_timeout/2
Runs when user session is timed out (when GenServer process received callback to `handle_info(:timeout, state)`, read [here](https://hexdocs.pm/elixir/GenServer.html#module-timeouts)). 
Our `handle_timeout` accepts two args: `session_key` and `bot_state`.
```elixir
def handle_timeout({_, chat_or_user_id}, bot_state) do
  post("/messages", %{text: "Bye"}, chat_id: chat_or_user_id)
  {:stop, bot_state}
end
```
 The function is expected to return a value:
 * `{:ok, bot_state}`
 * `{:ok, bot_state, timeout}`
 * `{:stop, bot_state}`
 
#### handle_error/5
Very usefull feature in my own experience.
The function is catching error throws during runtume and responds.
```elixir
def handle_update(%{"update_type" => "message_created", "message" => %{"sender" => _sender, "body" => %{"text" => "raise"}}}, _bot_state) do
  raise("Runtime error catched and rescued.")
end
  
def handle_error(error, _stacktrace, _session_key, update, bot_state) do
  case error do
    %RuntimeError{} ->
      chat_id = MAX.Helper.extract_chat_id(update)
      post("/messages", %{text: error.message}, chat_id: chat_id)
      {:ok, bot_state}
    _ ->
      # MyBot.Admins.notify_admin(error, stacktrace, update, session_key, bot_state)
      {:ok, bot_state}
  end
end
```
 The function is expected to return a value:
 * `{:ok, bot_state}`
 * `{:ok, bot_state, timeout}`
 * `{:stop, bot_state}`
 
#### handle_info/3
Continuation of the eponymous GenServer [callback](https://hexdocs.pm/elixir/GenServer.html#c:handle_info/2) for customize behaviour.
Callback is not often used, except of catching timeouts, so it's blank by default and just logging incoming messages:
```elixir
 def handle_info(msg, _session_key, bot_state) do
   Logger.info(msg)
   {:ok, bot_state}
 end
 ```
 The function is expected to return a value:
 * `{:ok, bot_state}`
 * `{:ok, bot_state, timeout}`
 * `{:stop, bot_state}`
 
 You are free to override it for your own custom experience.

### API client
`MyBot.Api` - is your only MAX Bot API client. All settings are pre-compiled according to configuration settings. 
MAX API [accepts](https://dev.max.ru/docs-api) GET, POST, PUT, PATCH and DELETE.
Moreover, all these methods in combination with different paths, in combination of body content and query content have different API meaning and respond different results.
That's why your client supports all these combinations so you can focus on the API itself:
```elixir
MyBot.post("/messages", %{text: "Ping"}, chat_id: 123456789)
# https://dev.max.ru/docs-api/methods/POST/messages
# Parameters encoded into the URL query and text has to be encoded in a body.
```
not the same thing at all:
```elixir
MyBot.put("/messages", %{text: "Pong"}, message_id: "mid.00000000007415897197d1ba5d2a44fu")
# https://dev.max.ru/docs-api/methods/PUT/messages

MyBot.delete("/messages", message_id: "mid.00000000007415897197d1ba5d2a44fu")
# https://dev.max.ru/docs-api/methods/DELETE/messages
```
That's enough, just follow and monitor the official [MAX Bot API](https://dev.max.ru/docs-api).

### Howto upload files
MAX uses [CDN servers](https://dev.max.ru/docs-api/methods/POST/uploads) to preload files.
1. At the **first step** you have to acquire special URL to upload files:
```elixir
# Acquiring URL link to upload
# Four file types supported: "image", "video", "audio", "file"
iex(1)> MyBot.post("/uploads", type: "video")
{:ok, %{
  "token" => "f9LYuiD0cOJpdenWXFVWERFaNWn8gVPHjnHPp31b0_1NG5VWOhwcnu-VYcCjnCYkhl-UC9tK3nT2vS0FJJ0T",
  "url" => "https://vu.okcdn.ru/upload.do?sig=a1d3dda38928535b971e602b5e9106da112e74e8&expires=1751724040314&clientType=51&id=9845330567059&userId=910146661779"
  }
}
```
If respond body includes **"token"** key (when file type is `"video"` or `"audio"`), that token can will be used as a file payload further. Otherwise payload will be result of uploading itself.

2. Anyway at the **second step** you have to upload file itself. Hackney-style interface for file uploads is a good solution, so as a file (or binary) source you use:
* `{:file, "/path/to/file"}`
or
* `{:file_content, "ANY BINARY DATA", "your_file_name.ext"}`

Let's upload video:
```elixir
iex(1)> MyBot.Uploader.upload("https://vu.okcdn.ru/upload.do?sig=a1d3dda38928535b971e602b5e9106da112e74e8&expires=1751724040314&clientType=51&id=9845330567059&userId=910146661779", {:file, "/path/to/video.mp4"})
{:ok, "0-233928/233929"}
```
This is result of successful uploading, showing us the final content-range value.

3. Now, at the **third step**, because we uploaded a video, we use **token** as a file payload to send it to somebody:
```elixir
MyBot.post("/messages", %{attachments: [%{type: "video", payload: %{
    token: "f9LYuiD0cOJpdenWXFVWERFaNWn8gVPHjnHPp31b0_1NG5VWOhwcnu-VYcCjnCYkhl-UC9tK3nT2vS0FJJ0T"
  }}]}, chat_id: 123456789)
```
Yes, in MAX we have the Message type and everything additional, including inline keyboard, files and another entities - are  Message's **attachments**.

If we try to upload an image, for example:
```elixir
iex(1)> {:ok, %{"url" => url}} = MyBot.post("/uploads", type: "image")
iex(2)> MyBot.Uploader.upload(url, {:file, "/path/to/photo.jpg"})
{:ok, %{
  "photos" => %{
     "JIu3TLdcCTJBcdRFVGusIwttcLg6hSFVGcZ+9gx761RBVRoA1TYLdg==" => %{
        "token" => "Mo+t2qqwCMYHS5kA83IAi4pobA+CMjmzyZS3veU8XoENbQLYLd6JNI/+wYmGMfduMXNwdtODGBjoG04dDmMOW6kPBNgLSdOpc2PF4sq5z/8Sh6AX56tRt671ZyVpuiUmZZ+sS2p94Z2G2wwqm4hhKgoBqsbHui4xeNhJD+zxsbs="
     }
  }
}}
```
Then our photo attachment payload will look like this:
```elixir
MyBot.post("/messages", %{attachments: [%{type: "image", payload: %{
    "photos" => %{
     "JIu3TLdcCTJBcdRFVGusIwttcLg6hSFVGcZ+9gx761RBVRoA1TYLdg==" => %{
        "token" => "Mo+t2qqwCMYHS5kA83IAi4pobA+CMjmzyZS3veU8XoENbQLYLd6JNI/+wYmGMfduMXNwdtODGBjoG04dDmMOW6kPBNgLSdOpc2PF4sq5z/8Sh6AX56tRt671ZyVpuiUmZZ+sS2p94Z2G2wwqm4hhKgoBqsbHui4xeNhJD+zxsbs="
     }
  }
}}]}, chat_id: 123456789)
```
#### Uploading helper
We're going to avoid that stuff of uploading process. So we want just to send a message with a file, right?
Your `MyBot` has ~~two~~  one helper function for that:
```elixir
photo = MyBot.upload_attachment({:file, "/path/to/photo.jpg"}, "video")
```
results in a ready to go attachment:
```
%{type: "image", payload: %{
   "photos" => %{
     "BMcBXIaOUil+Hiw2IdXs9AAsU8uU4aigCjt9cnvSWOEnUE/Ux3vE2g==" => %{
        "token" => "ID76p/sl7r0dhckD2jhPHEROeXTQiZfglyJAmfMgY13JWgMSuI4ZC4FkOU1sdkhPshtmXFiSQAWbZ8ANy6llt4jqVDXlRu4p0k/z0lj/IwJpjspUgppo+EBCobJO7ZKv76khhpaWilGTXfoVI7q0KxNTmBXthUd/ym0Lc9p1EZk="
      }
   }
}}
```
Now you just include it into your message parameters:
```elixir
MyBot.post("/messages", %{attachments: [photo]}, chat_id: 123456789)
```
That's it, folks. At the moment of this article MAX Messenger is still in beta-testing stage. Good luck, MAX team!