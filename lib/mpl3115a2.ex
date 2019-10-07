defmodule MPL3115A2 do
  @moduledoc """
  MPL3115A2 Driver for Elixir using ElixirALE.

  ## Usage:
  Add your devices to your config like so:

      config :mpl3115a2,
        devices: [
          %{bus: "i2c-1", address: 0x3d, reset_pin: 17}
        ]

  Then use the functions in [MPL3115A2.Device] to send image data.
  Pretty simple.
  """

  @doc """
  Connect to an MPL3115A2 device.
  """
  def connect(config),
    do: Supervisor.start_child(MPL3115A2.Supervisor, {MPL3115A2.Device, config})

  @doc """
  Disconnect an MPL3115A2 device.
  """
  def disconnect(device_name) do
    Supervisor.terminate_child(MPL3115A2.Supervisor, {MPL3115A2.Device, device_name})
    Supervisor.delete_child(MPL3115A2.Supervisor, {MPL3115A2.Device, device_name})
  end
end
