defmodule MPL3115A2.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: MPL3115A2.Registry}
    ]

    devices =
      :mpl3115a2
      |> Application.get_env(:devices, [])
      |> Enum.map(&{MPL3115A2.Device, &1})

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MPL3115A2.Supervisor]
    Supervisor.start_link(children ++ devices, opts)
  end
end
