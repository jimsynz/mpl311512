defmodule MPL3115A2Test do
  use ExUnit.Case, async: true
  doctest MPL3115A2

  alias MPL3115A2.Test.FakeChip

  @ctrl_reg1 0x26
  @ctrl_reg2 0x27
  @who_am_i 0x0C
  @device_id 0xC4

  describe "acquire/1 oversample encoding" do
    test "OS=2 sets the OS bits, not the ALT bit" do
      conn = FakeChip.new(%{@who_am_i => @device_id})

      {:ok, _} = MPL3115A2.acquire(conn: conn, oversample: 2, mode: :barometer)

      reg = FakeChip.peek(conn, @ctrl_reg1)
      assert Bitwise.band(reg, 0x38) == 0x08
      assert Bitwise.band(reg, 0x80) == 0x00
    end

    test "OS=128 encodes the full 3-bit field" do
      conn = FakeChip.new()

      {:ok, _} = MPL3115A2.acquire(conn: conn, oversample: 128, mode: :altimeter)

      reg = FakeChip.peek(conn, @ctrl_reg1)
      assert Bitwise.band(reg, 0x38) == 0x38
      assert Bitwise.band(reg, 0x80) == 0x80
    end
  end

  describe "oversample_ratio/1" do
    for {raw, expected} <- [{0x00, 1}, {0x08, 2}, {0x10, 4}, {0x18, 8}, {0x38, 128}] do
      test "decodes raw #{inspect(raw, base: :hex)} as #{expected}" do
        conn = FakeChip.new(%{@ctrl_reg1 => unquote(raw)})
        dev = %MPL3115A2{conn: conn}

        assert {:ok, unquote(expected)} = MPL3115A2.oversample_ratio(dev)
      end
    end
  end

  describe "oversample_ratio/2" do
    for os <- [1, 2, 4, 8, 16, 32, 64, 128] do
      test "round-trips OS=#{os}" do
        conn = FakeChip.new()
        dev = %MPL3115A2{conn: conn}

        {:ok, dev} = MPL3115A2.oversample_ratio(dev, unquote(os))

        assert {:ok, unquote(os)} = MPL3115A2.oversample_ratio(dev)
      end
    end

    test "preserves the ALT and RAW bits when changing OS" do
      conn = FakeChip.new(%{@ctrl_reg1 => 0xC1})
      dev = %MPL3115A2{conn: conn}

      {:ok, _} = MPL3115A2.oversample_ratio(dev, 32)

      reg = FakeChip.peek(conn, @ctrl_reg1)
      assert Bitwise.band(reg, 0xC0) == 0xC0
      assert Bitwise.band(reg, 0x07) == 0x01
      assert Bitwise.band(reg, 0x38) == 0x28
    end
  end

  describe "data_acquisition_time_step/1" do
    test "returns an integer (not a float)" do
      conn = FakeChip.new(%{@ctrl_reg2 => 0x04})
      dev = %MPL3115A2{conn: conn}

      assert {:ok, 16} = MPL3115A2.data_acquisition_time_step(dev)
    end
  end

  describe "data_acquisition_time_step/2" do
    for st <- [1, 2, 4, 8, 16, 64, 1024, 32_768] do
      test "round-trips ST=#{st}" do
        conn = FakeChip.new()
        dev = %MPL3115A2{conn: conn}

        {:ok, dev} = MPL3115A2.data_acquisition_time_step(dev, unquote(st))

        assert {:ok, unquote(st)} = MPL3115A2.data_acquisition_time_step(dev)
      end
    end

    test "preserves the high nibble (ALARM_SEL/LOAD_OUTPUT) when changing ST" do
      conn = FakeChip.new(%{@ctrl_reg2 => 0x30})
      dev = %MPL3115A2{conn: conn}

      {:ok, _} = MPL3115A2.data_acquisition_time_step(dev, 64)

      reg = FakeChip.peek(conn, @ctrl_reg2)
      assert Bitwise.band(reg, 0xF0) == 0x30
      assert Bitwise.band(reg, 0x0F) == 0x06
    end
  end
end
