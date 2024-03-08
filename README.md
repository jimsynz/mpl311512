# MPL3115A2

[![Build Status](https://drone.harton.dev/api/badges/james/mpl3115a2/status.svg)](https://drone.harton.dev/james/mpl3115a2)
[![Hex.pm](https://img.shields.io/hexpm/v/mpl3115a2.svg)](https://hex.pm/packages/mpl3115a2)
[![Hippocratic License HL3-FULL](https://img.shields.io/static/v1?label=Hippocratic%20License&message=HL3-FULL&labelColor=5e2751&color=bc8c3d)](https://firstdonoharm.dev/version/3/0/full.html)

Elixir driver for the MPL3115A2 barometric pressure, altitude and temperature
sensor. I'm using [Adafruit's breakout](https://www.adafruit.com/product/1893).

## Usage

Add your device to your config like so:

    config :mpl3115a2,
      devices: [%{bus: "i2c-1", address: 0x60}]

And start your application. Your devices will be reset with defaults and you
will be able to take temperature and pressure or altitude readings. See
`MPL3115A2.Commands.initialize!/1` for more details on the default
initialization.

This device is capable of much more advanced usage than the `MPL3115A2.Device`
module makes use of. It was all that I needed at the time. For advanced usage
you can use the `MPL3115A2.Commands` and `MPL3115A2.Registers` modules directly.
Feel free to send PR's.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `mpl3115a2` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:mpl3115a2, "~> 1.0.1"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/mpl3115a2](https://hexdocs.pm/mpl3115a2).

## Github Mirror

This repository is mirrored [on Github](https://github.com/jimsynz/mpl3115a2)
from it's primary location [on my Forgejo instance](https://harton.dev/james/mpl3115a2).
Feel free to raise issues and open PRs on Github.

## License

This software is licensed under the terms of the
[HL3-FULL](https://firstdonoharm.dev), see the `LICENSE.md` file included with
this package for the terms.

This license actively proscribes this software being used by and for some
industries, countries and activities. If your usage of this software doesn't
comply with the terms of this license, then [contact me](mailto:james@harton.nz)
with the details of your use-case to organise the purchase of a license - the
cost of which may include a donation to a suitable charity or NGO.
