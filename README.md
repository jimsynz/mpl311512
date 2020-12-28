# MPL3115A2

Elixir driver for the MPL3115A2 barometric pressure, altitude and temperature
sensor.  I'm using [Adafruit's breakout](https://www.adafruit.com/product/1893).

## Usage

Add your device to your config like so:

    config :mpl3115a2,
      devices: [%{bus: "i2c-1", address: 0x60}]

And start your application.  Your devices will be reset with defaults and you
will be able to take temperature  and pressure or altitude readings. See
`MPL3115A2.Commands.initialize!/1` for more details on the default
initialization.

This device is capable of much more advanced usage than the `MPL3115A2.Device`
module makes use of.  It was all that I needed at the time.  For advanced usage
you can use the `MPL3115A2.Commands` and `MPL3115A2.Registers` modules directly.
Feel free to send PR's.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `mpl3115a2` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:mpl3115a2, "~> 0.3.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/mpl3115a2](https://hexdocs.pm/mpl3115a2).

