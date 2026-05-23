defmodule MPL3115A2.Test.FakeChip do
  @moduledoc """
  An in-memory `Wafer.Chip` implementation backed by an `Agent`, used by the
  driver's regression tests to observe the exact byte the driver writes to
  each register.
  """

  defstruct [:agent]

  @type t :: %__MODULE__{agent: pid}

  @spec new(map) :: t
  def new(initial \\ %{}) do
    {:ok, agent} = Agent.start_link(fn -> initial end)
    %__MODULE__{agent: agent}
  end

  @spec peek(t, non_neg_integer) :: byte
  def peek(%__MODULE__{agent: agent}, address) do
    Agent.get(agent, &Map.get(&1, address, 0))
  end

  @spec poke(t, non_neg_integer, byte) :: t
  def poke(%__MODULE__{agent: agent} = conn, address, value) do
    :ok = Agent.update(agent, &Map.put(&1, address, value))
    conn
  end
end

defimpl Wafer.Chip, for: MPL3115A2.Test.FakeChip do
  alias MPL3115A2.Test.FakeChip

  def read_register(%FakeChip{agent: agent}, address, 1) do
    {:ok, <<Agent.get(agent, &Map.get(&1, address, 0))>>}
  end

  def write_register(%FakeChip{agent: agent} = conn, address, <<value>>) do
    :ok = Agent.update(agent, &Map.put(&1, address, value))
    {:ok, conn}
  end

  def swap_register(%FakeChip{agent: agent} = conn, address, <<value>>) do
    old =
      Agent.get_and_update(agent, fn state ->
        {Map.get(state, address, 0), Map.put(state, address, value)}
      end)

    {:ok, <<old>>, conn}
  end
end
