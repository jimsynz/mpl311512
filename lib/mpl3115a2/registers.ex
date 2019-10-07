defmodule MPL3115A2.Registers do
  use Bitwise
  alias ElixirALE.I2C

  @moduledoc """
  This module provides a wrapper around the MPL3115A2 registers
  described in Freescale's data sheet.

  Don't access these directly unless you know what you're doing.
  It's better to use the `Commands` module instead.
  """

  @doc """
  STATUS register; 0x00; 1 byte, RO
  """
  def status(pid), do: read_register(pid, 0)

  @doc """
  OUT_P_MSB register; 0x01, 1 byte, RO
  OUT_P_CSB register; 0x02, 1 byte, RO
  OUT_P_LSB register; 0x03, 1 byte, RO
  """
  def pressure_data_out(pid) do
    with msb <- read_register(pid, 1),
         csb <- read_register(pid, 2),
         lsb <- read_register(pid, 3),
         do: msb <> csb <> lsb
  end

  @doc """
  OUT_T_MSB register; 0x04, 1 byte, RO
  OUT_T_LSB register; 0x05, 1 byte, RO
  """
  def temperature_data_out(pid) do
    with msb <- read_register(pid, 4),
         lsb <- read_register(pid, 5),
         do: msb <> lsb
  end

  @doc """
  DR_STATUS register; 0x06, 1 byte, RO
  """
  def data_ready_status(pid), do: read_register(pid, 6)

  @doc """
  OUT_P_DELTA_MSB register; 0x07, 1 byte, RO
  OUT_P_DELTA_CSB register; 0x08, 1 byte, RO
  OUT_P_DELTA_LSB register; 0x09, 1 byte, RO
  """
  def pressure_data_out_delta(pid) do
    with msb <- read_register(pid, 7),
         csb <- read_register(pid, 8),
         lsb <- read_register(pid, 9),
         do: msb <> csb <> lsb
  end

  @doc """
  OUT_T_DELTA_MSB register; 0x0a, 1 byte, RO
  OUT_T_DELTA_LSB register; 0x0b, 1 byte, RO
  """
  def temperature_data_out_delta(pid) do
    with msb <- read_register(pid, 0xA),
         lsb <- read_register(pid, 0xB),
         do: msb <> lsb
  end

  @doc """
  WHO_AM_I register; 0x0c, 1 byte, RO
  """
  def who_am_i(pid), do: read_register(pid, 0xC)

  @doc """
  F_STATUS register; 0x0d, 1 byte, RO
  """
  def fifo_status(pid), do: read_register(pid, 0xD)

  @doc """
  F_DATA register; 0x0e, 1 byte, RO
  """
  def fifo_data_access(pid), do: read_register(pid, 0xE)

  @doc """
  F_SETUP register; 0x0f, 1 byte, RW
  """
  def fifo_setup(pid), do: read_register(pid, 0xF)
  def fifo_setup(pid, value), do: write_register(pid, 0xF, value)

  @doc """
  TIME_DLY register; 0x10, 1 byte, RO
  """
  def time_delay(pid), do: read_register(pid, 0x10)

  @doc """
  SYSMOD register; 0x11, 1 byte, RO
  """
  def system_mode(pid), do: read_register(pid, 0x11)

  @doc """
  INT_SOURCE register; 0x12, 1 byte, RO
  """
  def interrupt_source(pid), do: read_register(pid, 0x12)

  @doc """
  PT_DATA_CFG register; 0x13, 1 byte, RW
  """
  def pt_data_configuration(pid), do: read_register(pid, 0x13)
  def pt_data_configuration(pid, value), do: write_register(pid, 0x13, value)

  @doc """
  BAR_IN_MSB register; 0x14, 1 byte, RW
  BAR_IN_LSB register; 0x15, 1 byte, RW
  """
  def barometric_input(pid) do
    with msb <- read_register(pid, 0x14),
         lsb <- read_register(pid, 0x15),
         do: msb <> lsb
  end

  def barometric_input(pid, value) do
    msb = value >>> 8 &&& 0xFF
    lsb = value &&& 0xFF

    with :ok <- write_register(pid, 0x14, msb),
         :ok <- write_register(pid, 0x15, lsb),
         do: :ok
  end

  @doc """
  P_TGT_MSB register; 0x16, 1 byte, RW
  P_TGT_LSB register; 0x17, 1 byte, RW
  """
  def pressure_target(pid) do
    with msb <- read_register(pid, 0x16),
         lsb <- read_register(pid, 0x17),
         do: msb <> lsb
  end

  def pressure_target(pid, value) do
    msb = value >>> 8 &&& 0xFF
    lsb = value &&& 0xFF

    with :ok <- write_register(pid, 0x16, msb),
         :ok <- write_register(pid, 0x17, lsb),
         do: :ok
  end

  @doc """
  T_TGT register; 0x18, 1 byte, RO
  """
  def temperature_target(pid), do: read_register(pid, 0x18)
  def temperature_target(pid, value), do: write_register(pid, 0x18, value)

  @doc """
  P_WND_MSB register; 0x19, 1 byte, RW
  P_WND_LSB register; 0x1a, 1 byte, RW
  """
  def pressure_altitude_window(pid) do
    with msb <- read_register(pid, 0x19),
         lsb <- read_register(pid, 0x1A),
         do: msb <> lsb
  end

  def pressure_altitude_window(pid, value) do
    msb = value >>> 8 &&& 0xFF
    lsb = value &&& 0xFF

    with :ok <- write_register(pid, 0x19, msb),
         :ok <- write_register(pid, 0x1A, lsb),
         do: :ok
  end

  @doc """
  T_WND register; 0x1b, 1 byte, RW
  """
  def temperature_window(pid), do: read_register(pid, 0x1B)
  def temperature_window(pid, value), do: write_register(pid, 0x1B, value)

  @doc """
  P_MIN_MSB register; 0x1c, 1 byte, RW
  P_MIN_CSB register; 0x1d, 1 byte, RW
  P_MIN_LSB register; 0x1e, 1 byte, RW
  """
  def minimum_pressure_data(pid) do
    with msb <- read_register(pid, 0x1C),
         csb <- read_register(pid, 0x1D),
         lsb <- read_register(pid, 0x1E),
         do: msb <> csb <> lsb
  end

  def minimum_pressure_data(pid, value) do
    msb = value >>> 16 &&& 0xFF
    csb = value >>> 8 &&& 0xFF
    lsb = value &&& 0xFF

    with :ok <- write_register(pid, 0x1C, msb),
         :ok <- write_register(pid, 0x1D, csb),
         :ok <- write_register(pid, 0x1E, lsb),
         do: :ok
  end

  @doc """
  T_MIN_MSB register; 0x1f, 1 byte, RW
  T_MIN_LSB register; 0x20, 1 byte, RW
  """
  def minimum_temperature_data(pid) do
    with msb <- read_register(pid, 0x1F),
         lsb <- read_register(pid, 0x20),
         do: msb <> lsb
  end

  def minimum_temperature_data(pid, value) do
    msb = value >>> 8 && 0xFF
    lsb = value &&& 0xFF

    with :ok <- write_register(pid, 0x1F, msb),
         :ok <- write_register(pid, 0x20, lsb),
         do: :ok
  end

  @doc """
  P_MAX_MSB register, 0x21, 1 byte, RW
  P_MAX_CSB register, 0x22, 1 byte, RW
  P_MAX_LSB register, 0x23, 1 byte, RW
  """
  def maximum_pressure_data(pid) do
    with msb <- read_register(pid, 0x21),
         csb <- read_register(pid, 0x22),
         lsb <- read_register(pid, 0x23),
         do: msb <> csb <> lsb
  end

  def maximum_pressure_data(pid, value) do
    msb = value >>> 16 &&& 0xFF
    csb = value >>> 8 &&& 0xFF
    lsb = value &&& 0xFF

    with :ok <- write_register(pid, 0x21, msb),
         :ok <- write_register(pid, 0x22, csb),
         :ok <- write_register(pid, 0x23, lsb),
         do: :ok
  end

  @doc """
  T_MAX_MSB register; 0x24, 1 byte, RW
  T_MAX_LSB register; 0x25, 1 byte, RW
  """
  def maximum_temperature_data(pid) do
    with msb <- read_register(pid, 0x24),
         lsb <- read_register(pid, 0x25),
         do: msb <> lsb
  end

  def maximum_temperature_data(pid, value) do
    msb = value >>> 8 && 0xFF
    lsb = value &&& 0xFF

    with :ok <- write_register(pid, 0x24, msb),
         :ok <- write_register(pid, 0x25, lsb),
         do: :ok
  end

  @doc """
  CTRL_REG1 register; 1 byte, 0x26, RW
  """
  def control_register1(pid), do: read_register(pid, 0x26)
  def control_register1(pid, value), do: write_register(pid, 0x26, value)

  @doc """
  CTRL_REG2 register; 1 byte, 0x27, RW
  """
  def control_register2(pid), do: read_register(pid, 0x27)
  def control_register2(pid, value), do: write_register(pid, 0x27, value)

  @doc """
  CTRL_REG3 register; 1 byte, 0x28, RW
  """
  def control_register3(pid), do: read_register(pid, 0x28)
  def control_register3(pid, value), do: write_register(pid, 0x28, value)

  @doc """
  CTRL_REG4 register; 1 byte, 0x29, RW
  """
  def control_register4(pid), do: read_register(pid, 0x29)
  def control_register4(pid, value), do: write_register(pid, 0x29, value)

  @doc """
  CTRL_REG5 register; 1 byte, 0x2a, RW
  """
  def control_register5(pid), do: read_register(pid, 0x2A)
  def control_register5(pid, value), do: write_register(pid, 0x2A, value)

  @doc """
  OFF_P register; 1 byte, 0x2b, RW
  """
  def pressure_data_user_offset(pid), do: read_register(pid, 0x2B)
  def pressure_data_user_offset(pid, value), do: write_register(pid, 0x2B, value)

  @doc """
  OFF_T register; 1 byte, 0x2c, RW
  """
  def temperature_data_user_offset(pid), do: read_register(pid, 0x2C)
  def temperature_data_user_offset(pid, value), do: write_register(pid, 0x2C, value)

  @doc """
  OFF_H register; 1 byte, 0x2d, RW
  """
  def altitude_data_user_offset(pid), do: read_register(pid, 0x2D)
  def altitude_data_user_offset(pid, value), do: write_register(pid, 0x2D, value)

  defp read_register(pid, register) do
    I2C.write_read(pid, <<register>>, 1)
  end

  defp write_register(pid, register, value) do
    I2C.write(pid, <<register, value>>)
  end
end
