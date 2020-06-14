![logo](https://i.imgur.com/6kYR90I.png)

Drizzle is a Nerves-based home sprinkler system.
It is designed to support up to 8 zones, and will automatically adjust watering
times given local weather data.
By default, the watering times will increase gradually as the temperature reaches
a predetermined threshold (90ºF) and will decrease gradually based on recent and
upcoming precipitation.
The system will also shut down when the temperature drops below a predetermined
threshold (40ºF). You also have the option to set "Winter months", which are
months where the system will not run regardless of temperature.

## Configuration

For the system to work properly, you need to export some ENV variables. For weather forecasts, set the following:
- `LATITUDE=<your local latitude>`
- `LONGITUDE=<your local longitude>`

## Weather Adapters

By default, Drizzle uses [ClimaCell weather API](https://www.climacell.co/weather-api/pricing/) to fetch weather forecasts
which requires setting an API key in your environment when compiling.
- `CLIMACELL_API_KEY=<your API key>`

If you wish to use a different weather API service, you can implement the `Drizzle.WeatherAdapter`
behavior in another module and set it in your application config:

```elixir
config :drizzle, weather_adapter: MyCustomAdapter
```

If this is a common weather API that could be useful to others, please consider contributing back to
this library and opening a PR supporting it.

## First boot
When your device starts up *for its first time* it will need to know the SSID and passphrase (aka PSK, pre-shared key) for the wireless SSID its going to connect to (for weather updates for example). This process is done using the [VintageNetWizard](https://hexdocs.pm/vintage_net_wizard/readme.html), so this means you have to temporarily connect your mobile or laptop to the wireless access point named "nerves_xxxxx" (where xxxxx is an automatically generated ID for your nerves machine) and access a basic web portal to select your home network and provide its password. 

Once you select a wireless network and provide the credentials, just double-check your entered the correct passphrase and click on `Complete without validation` button (as validation involves the AP dropping the connection to test connecting to your home router's AP and then reconnecting it back to the temporary AP later - so I find it error-prone and inconvenient).

After the process is complete, the WiFi card will be automatically configured with the SSID and passphrase upon next boot-ups.
The device is now discoverable as `drizzle.local` (try pinging it!) and exposes an SSH server into the Erlang VM console: 
```
$ ping drizzle.local
PING drizzle.local (192.168.8.111) 56(84) bytes of data.
64 bytes from 192.168.8.111 (192.168.8.111): icmp_seq=1 ttl=64 time=12.2 ms
64 bytes from 192.168.8.111 (192.168.8.111): icmp_seq=2 ttl=64 time=6.41 ms
^C
--- drizzle.local ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1002ms
rtt min/avg/max/mdev = 6.407/9.304/12.201/2.897 ms
ekarak@ekarak-Latitude-7400:~$ ssh drizzle.local
The authenticity of host 'drizzle.local (192.168.8.111)' can't be established.
RSA key fingerprint is SHA256:s6rDEVL9YH3LaEDRxRX4qStknwY3560Vs5wkQ4wQMmA.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added 'drizzle.local' (RSA) to the list of known hosts.
Interactive Elixir (1.10.3) - press Ctrl+C to exit (type h() ENTER for help)
The Nerves.Runtime.Helpers have been removed. Use https://hex.pm/packages/toolshed instead.
iex(1)> 
```

## Web interface
(Work in progress) Drizzle has its own user interface based on Phoenix. Once you get the network setup complete, you should be able to navigate to 
http://drizzle.local and get a basic web page that allows you to:
- Manually control the zones
- View a list of the next scheduled irrigation events for each zone

Things on the backlog for the UI are currently:
- Dynamic schedule (change your watering schedule via the UI)
- Dynamic configuration (set your weather provider details, API keys etc)
- Ability to select from preset hardware GPIO pin layouts for your board


## OTA firmware upgrades

Once you've pinged it succesfully you can leverage nerves_firmware_ssh mechanism to do OTA (over-the-air) firmware upgrades (so that you don't need to swap the microSD card in and out from your RPi), as follows:
```sh
# write out the firmware upload script (upload.sh), you only need this done once
$ mix firmware.gen.script
# generate firmware file
$ mix firmware
# run the upload script
$ ./upload.sh drizzle.local ./_build/rpi3/rpi3_dev/nerves/images/drizzle.fw
```
## Wiring Diagram
![wiring diagram](https://i.imgur.com/Opf0RgV.png)

## How It Works

- Starts the weather data agent, which stores state for the previous 12 hours and next 24 hours of weather. Until the system has been online for 12 hours, your previous 12 hours will not be set.
- Registers each of your zones with a corresponding GPIO pin on your device.
- Starts a recurring genserver that checks the weather each hour and updates the weather data agent.
- The scheduler generates or updates the schedule from its own config when:
  * the system starts up
  * a zone (or a series of chained zones) finishes irrigation
  * by a PubSub event

## Scheduler

Drizzle comes bundled with a powerful scheduler that is driven off astronomical events (like sunrise/noon/sunset/midnight). This allows time calculations to be entirely based on UTC, as long as you've set up your coordinates correctly. You can define individual triggers per zone, or you can 'chain' several zones to activate one after the other. Please see the `Drizzle.Scheduler` module documentation for more details.  

## Targets

Nerves applications produce images for hardware targets based on the
`MIX_TARGET` environment variable. If `MIX_TARGET` is unset, `mix` builds an
image that runs on the host (e.g., your laptop). This is useful for executing
logic tests, running utilities, and debugging. Other targets are represented by
a short name like `rpi3` that maps to a Nerves system image for that platform.
All of this logic is in the generated `mix.exs` and may be customized. For more
information about targets see:

https://hexdocs.pm/nerves/targets.html#content

## Local testing in your host environment
Getting Circuits.GPIO to work in stub mode is tricky, as it needs recompilation. You only need to recompile when you switch mix targets though:
```sh
$ rm -rf _build/
$ MIX_ENV="test" CIRCUITS_MIX_ENV="test" iex -S mix phx.server
```

when done with testing, clean all build artifacts, recompile and flash over the network:
```sh
$ rm -rf _build/
$ MIX_TARGET="rpi3" mix firmware && ./upload.sh drizzle.local _build/rpi3/rpi3_dev/nerves/images/drizzle.fw 
```

## Getting Started

To start your Nerves app:
  * `export MIX_TARGET=my_target` or prefix every command with
    `MIX_TARGET=my_target`. For example, `MIX_TARGET=rpi3`
  * Install dependencies with `mix deps.get`
  * Create firmware with `mix firmware`
  * Burn to an SD card with `mix firmware.burn`

## Learn more

  * Official docs: https://hexdocs.pm/nerves/getting-started.html
  * Official website: http://www.nerves-project.org/
  * Discussion Slack elixir-lang #nerves ([Invite](https://elixir-slackin.herokuapp.com/))
  * Source: https://github.com/nerves-project/nerves
