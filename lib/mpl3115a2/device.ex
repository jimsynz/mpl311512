defmodule MPL3115A2.Device do
  alias MPL3115A2.{Device, Commands}
  alias ElixirALE.I2C
  use GenServer
  require Logger

  @doc """
  Returns true of there is pressure or temperature data ready for reading.
  """
  def pressure_or_temperature_data_ready?(device_name),
    do:
      GenServer.call(
        {:via, Registry, {MPL3115A2.Registry, device_name}},
        :pressure_or_temperature_data_ready?
      )

  @doc """
  Returns true of there is pressure data ready for reading.
  """
  def pressure_data_available?(device_name),
    do:
      GenServer.call(
        {:via, Registry, {MPL3115A2.Registry, device_name}},
        :pressure_data_available?
      )

  @doc """
  Returns true of there is temperature data ready for reading.
  """
  def temperature_data_available?(device_name),
    do:
      GenServer.call(
        {:via, Registry, {MPL3115A2.Registry, device_name}},
        :temperature_data_available?
      )

  @doc """
  Returns the current altutude (in meters).
  """
  def altitude(device_name),
    do:
      GenServer.call(
        {:via, Registry, {MPL3115A2.Registry, device_name}},
        :altitude
      )

  @doc """
  Returns the current barometric pressure (in Pascals).
  """
  def pressure(device_name),
    do:
      GenServer.call(
        {:via, Registry, {MPL3115A2.Registry, device_name}},
        :pressure
      )

  @doc """
  Returns the current temperature (in ℃)
  """
  def temperature(device_name),
    do:
      GenServer.call(
        {:via, Registry, {MPL3115A2.Registry, device_name}},
        :temperature
      )

  @doc """
  Returns the change in altitude since the last sample (in meters).
  """
  def altitude_delta(device_name),
    do:
      GenServer.call(
        {:via, Registry, {MPL3115A2.Registry, device_name}},
        :altitude_delta
      )

  @doc """
  Returns the change in pressure since the last sample (in Pascals).
  """
  def pressure_delta(device_name),
    do:
      GenServer.call(
        {:via, Registry, {MPL3115A2.Registry, device_name}},
        :pressure_delta
      )

  @doc """
  Returns the change in temperature since the last sample (in ℃)
  """
  def temperature_delta(device_name),
    do:
      GenServer.call(
        {:via, Registry, {MPL3115A2.Registry, device_name}},
        :temperature_delta
      )

  @doc """
  Execute an arbitrary function with the PID of the I2C connection.
  """
  def execute(device_name, function) when is_function(function, 1),
    do: GenServer.call({:via, Registry, {MPL3115A2.Registry, device_name}}, {:execute, function})

  @doc false
  def start_link(config), do: GenServer.start_link(Device, config)

  @impl true
  def init(%{bus: bus, address: address} = state) do
    name = device_name(state)

    {:ok, _} = Registry.register(MPL3115A2.Registry, name, self())
    Process.flag(:trap_exit, true)

    Logger.info("Connecting to MPL3115A2 device on #{inspect(name)}")

    {:ok, pid} = I2C.start_link(bus, address)

    with 0xC4 <- Commands.who_am_i(pid),
         :ok <- Commands.initialize!(pid, state) do
      state =
        state
        |> Map.merge(%{name: name, i2c: pid})

      {:ok, state}
    else
      i when is_integer(i) ->
        {:stop, "Device responded incorrectly to WHO_AM_I command with #{inspect(i)}"}

      {:error, message} ->
        {:stop, message}
    end
  end

  @impl true
  def terminate(_reason, %{i2c: pid, name: name}) do
    Logger.info("Disconnecting from MPL3115A2 device on #{inspect(name)}")
    I2C.release(pid)
  end

  @impl true
  def handle_call(:pressure_or_temperature_data_ready?, _from, %{i2c: pid} = state) do
    {:reply, Commands.pressure_or_temperature_data_ready(pid), state}
  end

  def handle_call(:pressure_data_available?, _from, %{i2c: pid} = state) do
    {:reply, Commands.pressure_data_available(pid), state}
  end

  def handle_call(:temperature_data_available?, _from, %{i2c: pid} = state) do
    {:reply, Commands.temperature_data_available(pid), state}
  end

  def handle_call(:altitude, _from, %{i2c: pid} = state) do
    {:reply, Commands.altitude(pid), state}
  end

  def handle_call(:temperature, _from, %{i2c: pid} = state) do
    {:reply, Commands.temperature(pid), state}
  end

  def handle_call(:pressure, _from, %{i2c: pid} = state) do
    {:reply, Commands.pressure(pid), state}
  end

  def handle_call(:altitude_delta, _from, %{i2c: pid} = state) do
    {:reply, Commands.altitude_delta(pid), state}
  end

  def handle_call(:temperature_delta, _from, %{i2c: pid} = state) do
    {:reply, Commands.temperature_delta(pid), state}
  end

  def handle_call(:pressure_delta, _from, %{i2c: pid} = state) do
    {:reply, Commands.pressure_delta(pid), state}
  end

  def handle_call({:execute, function}, _from, %{i2c: pid} = state) do
    {:reply, function.(pid), state}
  end

  @doc false
  def child_spec(config) do
    %{
      id: {MPL3115A2.Device, device_name(config)},
      start: {MPL3115A2.Device, :start_link, [config]},
      restart: :transient
    }
  end

  defp device_name(%{bus: bus, address: address} = config),
    do: Map.get(config, :name, {bus, address})
end
