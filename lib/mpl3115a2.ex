defmodule MPL3115A2 do
  @derive [Wafer.Chip, Wafer.DeviceID, Wafer.Release]
  defstruct ~w[conn]a
  @behaviour Wafer.Conn
  alias MPL3115A2.Registers
  alias Wafer.Conn
  use Bitwise
  import Wafer.Twiddles

  @moduledoc """
  MPL3115A2 Driver for Elixir using Wafer.
  """

  @type t :: %MPL3115A2{conn: Conn.t()}
  @type acquire_options :: [acquire_option]
  @type acquire_option ::
          {:conn, Conn.t()}
          | {:standby, boolean}
          | {:oversample, oversample}
          | {:mode, mode}
          | {:event_on_new_temperature, boolean}
          | {:event_on_new_pressue, boolean}
          | {:data_ready_event_mode, boolean}
  @type oversample :: 1 | 2 | 4 | 8 | 16 | 32 | 64
  @type mode :: :altimeter | :barometer
  @type altitude :: float
  @type pressure :: float
  @type temperature :: float
  @type fifo_mode :: :fifo_disabled | :circular_buffer | :halt_on_overflow

  @device_id 0xC4

  @doc """
  Acquire a connection to the MPL3115A2 device using the passed in I2C
  connection.

  ## Options:
  - `conn` an I2C connection, probably from `ElixirALE.I2C` or `Circuits.I2C`.
  - `standby` set to `true` to put the device in standby, otherwise defaults to `false`.
  - `mode` set to either `:altimeter` or `:barometer`.  Defaults to `:altimeter`.
  - `event_on_new_temperature` set to `false` to disable.  Defaults to `true`.
  - `event_on_new_pressure` set to `false` to disable. Defaults to `true`.
  - `data_ready_event_mode` set to `false` to disable. Defaults to `true`.
  """
  @spec acquire(acquire_options) :: {:ok, t} | {:error, reason :: any}
  @impl Wafer.Conn
  # credo:disable-for-next-line
  def acquire(options) do
    standby =
      case Keyword.get(options, :standby, false) do
        true -> 0x00
        false -> 0x01
      end

    oversample =
      case Keyword.get(options, :oversample, 128) do
        1 -> 0x00
        2 -> 0x80
        4 -> 0x10
        8 -> 0x18
        16 -> 0x20
        32 -> 0x28
        64 -> 0x30
        128 -> 0x38
      end

    mode =
      case Keyword.get(options, :mode, :altimeter) do
        :altimeter -> 0x80
        :barometer -> 0x00
      end

    tdefe =
      case Keyword.get(options, :event_on_new_temperature, true) do
        true -> 0x01
        false -> 0x00
      end

    pdefe =
      case Keyword.get(options, :event_on_new_pressure, true) do
        true -> 0x02
        false -> 0x00
      end

    drem =
      case Keyword.get(options, :data_ready_event_mode, true) do
        true -> 0x04
        false -> 0x00
      end

    with {:ok, conn} <- Keyword.fetch(options, :conn),
         {:ok, conn} <- Registers.write_ctrl_reg1(conn, <<standby ||| oversample ||| mode>>),
         {:ok, conn} <- Registers.write_pt_data_cfg(conn, <<tdefe ||| pdefe ||| drem>>) do
      {:ok, %MPL3115A2{conn: conn}}
    else
      :error -> {:error, "`MPL3115A2,.acquire/1` requires a `conn` option."}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  PTOW Pressure/Altitude OR Temperature data overwrite.
  """
  @spec pressure_or_temperature_data_overwrite?(t) :: boolean
  def pressure_or_temperature_data_overwrite?(%MPL3115A2{conn: conn}) do
    with {:ok, data} <- Registers.read_dr_status(conn),
         true <- get_bool(data, 7),
         do: true,
         else: (_ -> false)
  end

  @doc """
  POW Pressure/Altitude data overwrite.
  """
  @spec pressure_data_overwrite?(t) :: boolean
  def pressure_data_overwrite?(%MPL3115A2{conn: conn}) do
    with {:ok, data} <- Registers.read_dr_status(conn),
         true <- get_bool(data, 6),
         do: true,
         else: (_ -> false)
  end

  @doc """
  TOW Temperature data overwrite.
  """
  @spec temperature_data_overwrite?(t) :: boolean
  def temperature_data_overwrite?(%MPL3115A2{conn: conn}) do
    with {:ok, data} <- Registers.read_dr_status(conn),
         true <- get_bool(data, 5),
         do: true,
         else: (_ -> false)
  end

  @doc """
  PTDR Pressure/Altitude OR Temperature data ready.
  """
  @spec pressure_or_temperature_data_ready?(t) :: boolean
  def pressure_or_temperature_data_ready?(%MPL3115A2{conn: conn}) do
    with {:ok, data} <- Registers.read_dr_status(conn),
         true <- get_bool(data, 3),
         do: true,
         else: (_ -> false)
  end

  @doc """
  PDR Pressure/Altitude new data available.
  """
  @spec pressure_data_ready?(t) :: boolean
  def pressure_data_ready?(%MPL3115A2{conn: conn}) do
    with {:ok, data} <- Registers.read_dr_status(conn),
         true <- get_bool(data, 2),
         do: true,
         else: (_ -> false)
  end

  @doc """
  TDR Temperature new Data Available.
  """
  @spec temperature_data_ready?(t) :: boolean
  def temperature_data_ready?(%MPL3115A2{conn: conn}) do
    with {:ok, data} <- Registers.read_dr_status(conn),
         true <- get_bool(data, 1),
         do: true,
         else: (_ -> false)
  end

  @doc """
  OUT_P Altitude in meters.
  """
  @spec altitude(t) :: {:ok, altitude} | {:error, reason :: any}
  def altitude(%MPL3115A2{conn: conn}) do
    with {:ok, <<msb>>} <- Registers.read_out_p_msb(conn),
         {:ok, <<csb>>} <- Registers.read_out_p_csb(conn),
         {:ok, <<lsb>>} <- Registers.read_out_p_lsb(conn),
         do: to_altitude(<<msb, csb, lsb>>)
  end

  @doc """
  OUT_P Pressure in Pascals.
  """
  @spec pressure(t) :: {:ok, pressure} | {:error, reason :: any}
  def pressure(%MPL3115A2{conn: conn}) do
    with {:ok, <<msb>>} <- Registers.read_out_p_msb(conn),
         {:ok, <<csb>>} <- Registers.read_out_p_csb(conn),
         {:ok, <<lsb>>} <- Registers.read_out_p_lsb(conn),
         do: to_pressure(<<msb, csb, lsb>>)
  end

  @doc """
  OUT_T Temperature in ℃.
  """
  @spec temperature(t) :: {:ok, temperature} | {:error, reason :: any}
  def temperature(%MPL3115A2{conn: conn}) do
    with {:ok, <<msb>>} <- Registers.read_out_t_msb(conn),
         {:ok, <<lsb>>} <- Registers.read_out_t_lsb(conn),
         do: to_temperature(<<msb, lsb>>)
  end

  @doc """
  OUT_P_DELTA Altitude delta in meters.
  """
  @spec altitude_delta(t) :: {:ok, altitude} | {:error, reason :: any}
  def altitude_delta(%MPL3115A2{conn: conn}) do
    with {:ok, <<msb>>} <- Registers.read_out_p_delta_msb(conn),
         {:ok, <<csb>>} <- Registers.read_out_p_delta_csb(conn),
         {:ok, <<lsb>>} <- Registers.read_out_p_delta_lsb(conn),
         do: to_altitude(<<msb, csb, lsb>>)
  end

  @doc """
  OUT_P_DELTA Pressure delta in Pascals.
  """
  @spec pressure_delta(t) :: {:ok, pressure} | {:error, reason :: any}
  def pressure_delta(%MPL3115A2{conn: conn}) do
    with {:ok, <<msb>>} <- Registers.read_out_p_delta_msb(conn),
         {:ok, <<csb>>} <- Registers.read_out_p_delta_csb(conn),
         {:ok, <<lsb>>} <- Registers.read_out_p_delta_lsb(conn),
         do: to_pressure(<<msb, csb, lsb>>)
  end

  @doc """
  OUT_T_DELTA Temperature delta in ℃.
  """
  @spec temperature_delta(t) :: {:ok, temperature} | {:error, reason :: any}
  def temperature_delta(%MPL3115A2{conn: conn}) do
    with {:ok, <<msb>>} <- Registers.read_out_t_delta_msb(conn),
         {:ok, <<lsb>>} <- Registers.read_out_t_delta_lsb(conn),
         do: to_temperature_delta(<<msb, lsb>>)
  end

  @doc """
  WHO_AM_I Verify the device's identity

  Read the contents of the WHO_AM_I register and make sure that it equals the
  value specified in the datasheet (0xC4).
  """
  @spec verify_identity(t) :: {:ok, t} | {:error, reason :: any}
  def verify_identity(%MPL3115A2{conn: conn} = dev) do
    case Registers.read_who_am_i(conn) do
      {:ok, <<@device_id>>} -> {:ok, %{dev | conn: conn}}
      {:ok, <<id>>} -> {:error, "Found incorrect ID #{inspect(id)}"}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  F_OVF FIFO overflow events detected?
  """
  @spec fifo_overflow?(t) :: boolean
  def fifo_overflow?(%MPL3115A2{conn: conn}) do
    with {:ok, data} <- Registers.read_f_status(conn),
         true <- get_bool(data, 7),
         do: true,
         else: (_ -> false)
  end

  @doc """
  F_WMRK_FLAG FIFO watermark events detected?
  """
  @spec fifo_watermark?(t) :: boolean
  def fifo_watermark?(%MPL3115A2{conn: conn}) do
    with {:ok, data} <- Registers.read_f_status(conn),
         true <- get_bool(data, 6),
         do: true,
         else: (_ -> false)
  end

  @doc """
  F_CNT FIFO sample count
  """
  @spec fifo_sample_count(t) :: {:ok, non_neg_integer} | {:error, reason :: any}
  def fifo_sample_count(%MPL3115A2{conn: conn}) do
    with {:ok, <<data>>} <- Registers.read_f_status(conn),
         do: {:ok, data &&& 0x1F}
  end

  @doc """
  F_DATA Read FIFO data in Altitude mode.
  """
  @spec fifo_read_altitude(t) :: {:ok, [altitude]} | {:error, reason :: any}
  def fifo_read_altitude(%MPL3115A2{conn: conn} = dev) do
    with {:ok, count} <- fifo_sample_count(dev),
         {:ok, fifo} <- fifo_read(conn, count),
         do: {:ok, Enum.map(fifo, &to_altitude(&1))}
  end

  @doc """
  F_DATA Read FIFO data in Barometer mode.
  """
  @spec fifo_read_pressure(t) :: {:ok, [pressure]} | {:error, reason :: any}
  def fifo_read_pressure(%MPL3115A2{conn: conn} = dev) do
    with {:ok, count} <- fifo_sample_count(dev),
         {:ok, fifo} <- fifo_read(conn, count),
         do: {:ok, Enum.map(fifo, &to_pressure(&1))}
  end

  @doc """
  F_MODE get FIFO mode

  Can be either `:fifo_disabled`, `:circular_buffer`, or `:halt_on_overflow`.
  """
  @spec fifo_mode(t) :: {:ok, fifo_mode} | {:error, reason :: any}
  def fifo_mode(%MPL3115A2{conn: conn}) do
    with {:ok, <<data>>} <- Registers.read_f_setup(conn) do
      mode =
        case data >>> 6 do
          0 -> :fifo_disabled
          1 -> :circular_buffer
          2 -> :halt_on_overflow
        end

      {:ok, mode}
    end
  end

  @doc """
  F_MODE set FIFO mode

  Can be either `:fifo_disabled`, `:circular_buffer`, or `:halt_on_overflow`.
  """
  @spec fifo_mode(t, fifo_mode) :: {:ok, t} | {:error, reason :: any}
  def fifo_mode(%MPL3115A2{conn: conn} = dev, :fifo_disabled) do
    with {:ok, conn} <-
           Registers.update_f_setup(conn, fn <<data>> ->
             <<data &&& 0x7F>>
           end),
         do: {:ok, %{dev | conn: conn}}
  end

  def fifo_mode(%MPL3115A2{conn: conn} = dev, :circular_buffer) do
    with {:ok, conn} <-
           Registers.update_f_setup(conn, fn <<data>> ->
             <<data &&& 0x7F + (1 <<< 6)>>
           end),
         do: {:ok, %{dev | conn: conn}}
  end

  def fifo_mode(%MPL3115A2{conn: conn} = dev, :halt_on_overflow) do
    with {:ok, conn} <-
           Registers.update_f_setup(conn, fn <<data>> ->
             <<data &&& 0x7F + (1 <<< 7)>>
           end),
         do: {:ok, %{dev | conn: conn}}
  end

  @doc """
  F_WMRK Get FIFO Event Sample Count Watermark.
  """
  @spec fifo_event_sample_count_watermark(t) :: {:ok, 0..31} | {:error, reason :: any}
  def fifo_event_sample_count_watermark(%MPL3115A2{conn: conn}) do
    with {:ok, <<data>>} <- Registers.read_f_setup(conn), do: {:ok, data &&& 0x1F}
  end

  @doc """
  F_WMRK Set FIFO Event Sample Count Watermark.
  """
  @spec fifo_event_sample_count_watermark(t, 0..31) :: {:ok, t} | {:error, reason :: any}
  def fifo_event_sample_count_watermark(%MPL3115A2{conn: conn} = dev, count)
      when count >= 0 and count <= 31 do
    with {:ok, conn} <-
           Registers.update_f_setup(conn, fn <<data>> ->
             <<(data >>> 5 <<< 5) + (count &&& 0x1F)>>
           end),
         do: {:ok, %{dev | conn: conn}}
  end

  @doc """
  TIME_DLY

  The time delay register contains the number of ticks of data sample time
  since the last byte of the FIFO was written. This register starts to
  increment on FIFO overflow or data wrap and clears when last byte of FIFO is
  read.
  """
  @spec time_delay(t) :: {:ok, non_neg_integer} | {:error, reason :: any}
  def time_delay(%MPL3115A2{conn: conn}) do
    with {:ok, <<data>>} <- Registers.read_time_dly(conn), do: {:ok, data}
  end

  @doc """
  SYSMOD Get System Mode, either `:standby` or `:active`.
  """
  @spec system_mode(t) :: {:ok, :standby | :active} | {:error, reason :: any}
  def system_mode(%MPL3115A2{conn: conn}) do
    with {:ok, <<data>>} <- Registers.read_sysmod(conn) do
      mode =
        case get_bit(data, 0) do
          0 -> :standby
          1 -> :active
        end

      {:ok, mode}
    end
  end

  @doc """
  SRC_DRDY Data ready interrupt status.

  `true` indicates that Pressure/Altitude or Temperature data ready interrupt
  is active indicating the presence of new data and/or a data overwrite,
  otherwise it is `false`.
  """
  @spec data_ready_interrupt?(t) :: boolean
  def data_ready_interrupt?(%MPL3115A2{conn: conn}) do
    with {:ok, data} <- Registers.read_int_source(conn),
         true <- get_bool(data, 7),
         do: true,
         else: (_ -> false)
  end

  @doc """
  SRC_FIFO FIFO interrupt status.

  `true` indicates that a FIFO interrupt event such as an overflow event has
  occurred. `false` indicates that no FIFO interrupt event has occurred.
  """
  @spec fifo_interrupt?(t) :: boolean
  def fifo_interrupt?(%MPL3115A2{conn: conn}) do
    with {:ok, data} <- Registers.read_int_source(conn),
         true <- get_bool(data, 6),
         do: true,
         else: (_ -> false)
  end

  @doc """
  SRC_PW Altitude/Pressure alerter status near or equal to target Pressure/Altitude.

  Near is within target value ± window value. Window value needs to be non
  zero for interrupt to trigger.
  """
  @spec altitude_pressure_interrupt?(t) :: boolean
  def altitude_pressure_interrupt?(%MPL3115A2{conn: conn}) do
    with {:ok, data} <- Registers.read_int_source(conn),
         true <- get_bool(data, 5),
         do: true,
         else: (_ -> false)
  end

  @doc """
  SRC_TW Temperature alerter status bit near or equal to target temperature.

  Near is within target value ± window value. Window value needs to be non zero
  for interrupt to trigger.
  """
  @spec temperature_interrupt?(t) :: boolean
  def temperature_interrupt?(%MPL3115A2{conn: conn}) do
    with {:ok, data} <- Registers.read_int_source(conn),
         true <- get_bool(data, 4),
         do: true,
         else: (_ -> false)
  end

  @doc """
  SRC_PTH Altitude/Pressure threshold interrupt.

  With the window set to a non zero value, the trigger will occur on crossing
  any of the thresholds: upper, center or lower. If the window is set to 0, it
  will only trigger on crossing the center threshold.
  """
  @spec altitude_pressure_threshold_interrupt?(t) :: boolean
  def altitude_pressure_threshold_interrupt?(%MPL3115A2{conn: conn}) do
    with {:ok, data} <- Registers.read_int_source(conn),
         true <- get_bool(data, 3),
         do: true,
         else: (_ -> false)
  end

  @doc """
  SRC_TTH Temperature threshold interrupt.

  With the window set to a non zero value, the trigger will occur on crossing
  any of the thresholds: upper, center or lower. If the window is set to 0, it
  will only trigger on crossing the center threshold.
  """
  @spec temperature_threshold_interrupt?(t) :: boolean
  def temperature_threshold_interrupt?(%MPL3115A2{conn: conn}) do
    with {:ok, data} <- Registers.read_int_source(conn),
         true <- get_bool(data, 2),
         do: true,
         else: (_ -> false)
  end

  @doc """
  SRC_PCHG Delta P interrupt status.
  """
  @spec altitude_pressure_delta_interrupt?(t) :: boolean
  def altitude_pressure_delta_interrupt?(%MPL3115A2{conn: conn}) do
    with {:ok, data} <- Registers.read_int_source(conn),
         true <- get_bool(data, 1),
         do: true,
         else: (_ -> false)
  end

  @doc """
  SRC_TCHG Delta T interrupt status.
  """
  @spec temperature_delta_interrupt?(t) :: boolean
  def temperature_delta_interrupt?(%MPL3115A2{conn: conn}) do
    with {:ok, data} <- Registers.read_int_source(conn),
         true <- get_bool(data, 0),
         do: true,
         else: (_ -> false)
  end

  @doc """
  DREM Get data ready event mode.

  If the DREM bit is set `true` and one or more of the data ready event flags
  (PDEFE, TDEFE) are enabled, then an event flag will be raised upon change in
  state of the data. If the DREM bit is `false` and one or more of the data
  ready event flags are enabled, then an event flag will be raised whenever
  the system acquires a new set of data.

  Default value: `false`.
  """
  @spec data_ready_event_mode?(t) :: boolean
  def data_ready_event_mode?(%MPL3115A2{conn: conn}) do
    with {:ok, data} <- Registers.read_pt_data_cfg(conn),
         true <- get_bool(data, 2),
         do: true,
         else: (_ -> false)
  end

  @doc """
  DREM Set data ready event mode.

  If the DREM bit is set `true` and one or more of the data ready event flags
  (PDEFE, TDEFE) are enabled, then an event flag will be raised upon change in
  state of the data. If the DREM bit is `false` and one or more of the data
  ready event flags are enabled, then an event flag will be raised whenever
  the system acquires a new set of data.

  Default value: `false`.
  """
  @spec data_ready_event_mode(t, boolean) :: {:ok, t} | {:error, reason :: any}
  def data_ready_event_mode(%MPL3115A2{conn: conn} = dev, value) when is_boolean(value) do
    with {:ok, conn} <- Registers.update_pt_data_cfg(conn, &set_bit(&1, 2, value)),
         do: {:ok, %{dev | conn: conn}}
  end

  @doc """
  PDEFE Data event flag enable on new Pressure/Altitude data.

  Default value: `false`.
  """
  @spec pressure_altitude_event_flag_enable?(t) :: boolean
  def pressure_altitude_event_flag_enable?(%MPL3115A2{conn: conn}) do
    with {:ok, data} <- Registers.read_pt_data_cfg(conn),
         true <- get_bool(data, 1),
         do: true,
         else: (_ -> false)
  end

  @doc """
  PDEFE Data event flag enable on new Pressure/Altitude data.

  Default value: `false`.
  """
  @spec pressure_altitude_event_flag_enable(t, boolean) :: {:ok, t} | {:error, reason :: any}
  def pressure_altitude_event_flag_enable(%MPL3115A2{conn: conn} = dev, value)
      when is_boolean(value) do
    with {:ok, conn} <- Registers.update_pt_data_cfg(conn, &set_bit(&1, 1, value)),
         do: {:ok, %{dev | conn: conn}}
  end

  @doc """
  TDEFE Data event flag enable on new Temperature data.

  Default value: `false`.
  """
  @spec temperature_event_flag_enable?(t) :: boolean
  def temperature_event_flag_enable?(%MPL3115A2{conn: conn}) do
    with {:ok, data} <- Registers.read_pt_data_cfg(conn),
         true <- get_bool(data, 0),
         do: true,
         else: (_ -> false)
  end

  @doc """
  TDEFE Data event flag enable on new Temperature data.

  Default value: `false`.
  """
  @spec temperature_event_flag_enable(t, boolean) :: {:ok, t} | {:error, reason :: any}
  def temperature_event_flag_enable(%MPL3115A2{conn: conn} = dev, value) when is_boolean(value) do
    with {:ok, conn} <- Registers.update_pt_data_cfg(conn, &set_bit(&1, 0, value)),
         do: {:ok, %{dev | conn: conn}}
  end

  @doc """
  BAR_IN Barometric input for altitude calculations.

  Input is equivalent sea level pressure for measurement location.
  """
  @spec barometric_pressure_input(t) :: {:ok, pressure} | {:error, reason :: any}
  def barometric_pressure_input(%MPL3115A2{conn: conn}) do
    with {:ok, <<msb>>} <- Registers.read_bar_in_msb(conn),
         {:ok, <<lsb>>} <- Registers.read_bar_in_lsb(conn),
         do: {:ok, ((msb <<< 8) + lsb) * 2}
  end

  @doc """
  BAR_IN Barometric input for altitude calculations.

  Input is equivalent sea level pressure for measurement location in Pascals.
  """
  @spec barometric_pressure_input(t, pressure) :: {:ok, pressure} | {:error, reason :: any}
  def barometric_pressure_input(%MPL3115A2{conn: conn} = dev, pascals) do
    data = div(pascals, 2)
    msb = data >>> 8 &&& 0xFF
    lsb = data &&& 0xFF

    with {:ok, conn} <- Registers.write_bar_in_msb(conn, <<msb>>),
         {:ok, conn} <- Registers.write_bar_in_lsb(conn, <<lsb>>),
         do: {:ok, %{dev | conn: conn}}
  end

  @doc """
  P_TGT Altitude/Pressure target value.

  This value works in conjunction with the window value (P_WND).

  In Altitude mode the result is in meters.
  In Pressure mode the result is in Pascals.
  """
  @spec pressure_or_altitude_target(t) :: {:ok, pressure | altitude} | {:error, reason :: any}
  def pressure_or_altitude_target(%MPL3115A2{conn: conn}) do
    with {:ok, <<msb>>} <- Registers.read_p_tgt_msb(conn),
         {:ok, <<lsb>>} <- Registers.read_p_tgt_lsb(conn),
         do: {:ok, (msb <<< 8) + lsb}
  end

  @doc """
  P_TGT Altitude/Pressure target value.

  This value works in conjunction with the window value (P_WND).

  In Altitude mode the result is in meters.
  In Pressure mode the result is in Pascals.
  """
  @spec pressure_or_altitude_target(t, pressure | altitude) :: {:ok, t} | {:error, reason :: any}
  def pressure_or_altitude_target(%MPL3115A2{conn: conn} = dev, pressure_or_altitude) do
    msb = pressure_or_altitude >>> 8 &&& 0xFF
    lsb = pressure_or_altitude &&& 0xFF

    with {:ok, conn} <- Registers.write_p_tgt_msb(conn, <<msb>>),
         {:ok, conn} <- Registers.write_p_tgt_lsb(conn, <<lsb>>),
         do: {:ok, %{dev | conn: conn}}
  end

  @doc """
  T_TGT Temperature target value input in °C.
  """
  @spec temperature_target(t) :: {:ok, temperature} | {:error, reason :: any}
  def temperature_target(%MPL3115A2{conn: conn}) do
    with {:ok, <<data>>} <- Registers.read_t_tgt(conn), do: {:ok, data}
  end

  @doc """
  T_TGT Temperature target value input in °C.
  """
  @spec temperature_target(t, temperature) :: {:ok, t} | {:error, reason :: any}
  def temperature_target(%MPL3115A2{conn: conn} = dev, temperature) do
    with {:ok, conn} <- Registers.write_t_tgt(conn, <<temperature &&& 0xFF>>),
         do: {:ok, %{dev | conn: conn}}
  end

  @doc """
  P_WND Pressure/Altitude window value.

  In Altitude mode the result is in meters.
  In Pressure mode the result is in Pascals.
  """
  @spec pressure_altitude_window(t) :: {:ok, pressure | altitude} | {:error, reason :: any}
  def pressure_altitude_window(%MPL3115A2{conn: conn}) do
    with {:ok, <<msb>>} <- Registers.read_p_wnd_msb(conn),
         {:ok, <<lsb>>} <- Registers.read_p_wnd_lsb(conn),
         do: {:ok, (msb <<< 8) + lsb}
  end

  @doc """
  P_WND Pressure/Altitude window value.

  In Altitude mode the result is in meters.
  In Pressure mode the result is in Pascals.
  """
  @spec pressure_altitude_window(t, pressure | altitude) :: {:ok, t} | {:error, reason :: any}
  def pressure_altitude_window(%MPL3115A2{conn: conn} = dev, pressure_or_altitude) do
    msb = pressure_or_altitude >>> 8 &&& 0xFF
    lsb = pressure_or_altitude &&& 0xFF

    with {:ok, conn} <- Registers.write_p_wnd_msb(conn, <<msb>>),
         {:ok, conn} <- Registers.write_p_wnd_lsb(conn, <<lsb>>),
         do: {:ok, %{dev | conn: conn}}
  end

  @doc """
  T_WND Temperature alarm window value in °C.
  """
  @spec temperature_window(t) :: {:ok, temperature} | {:error, reason :: any}
  def temperature_window(%MPL3115A2{conn: conn}) do
    with {:ok, <<data>>} <- Registers.read_t_wnd(conn), do: {:ok, data}
  end

  @doc """
  T_WND Temperature alarm window value in °C.
  """
  @spec temperature_window(t, temperature) :: {:ok, t} | {:error, reason :: any}
  def temperature_window(%MPL3115A2{conn: conn} = dev, temperature) do
    with {:ok, conn} <- Registers.write_t_wnd(conn, <<temperature &&& 0xFF>>),
         do: {:ok, %{dev | conn: conn}}
  end

  @doc """
  P_MIN Captured minimum Pressure/Altitude value.

  Interpreted as a pressure in Pascals.
  """
  @spec minimum_pressure(t) :: {:ok, pressure} | {:error, reason :: any}
  def minimum_pressure(%MPL3115A2{conn: conn}) do
    with {:ok, <<msb>>} <- Registers.read_p_min_msb(conn),
         {:ok, <<csb>>} <- Registers.read_p_min_csb(conn),
         {:ok, <<lsb>>} <- Registers.read_p_min_lsb(conn),
         do: {:ok, to_pressure(<<msb, csb, lsb>>)}
  end

  @doc """
  P_MIN Captured minimum Pressure/Altitude value.

  Interpreted as a altitude in meters.
  """
  @spec minimum_altitude(t) :: {:ok, altitude} | {:error, reason :: any}
  def minimum_altitude(%MPL3115A2{conn: conn}) do
    with {:ok, <<msb>>} <- Registers.read_p_min_msb(conn),
         {:ok, <<csb>>} <- Registers.read_p_min_csb(conn),
         {:ok, <<lsb>>} <- Registers.read_p_min_lsb(conn),
         do: {:ok, to_altitude(<<msb, csb, lsb>>)}
  end

  @doc """
  P_MAX Captured maximum Pressure/Altitude value.
  """
  @spec maximum_pressure(t) :: {:ok, pressure} | {:error, reason :: any}
  def maximum_pressure(%MPL3115A2{conn: conn}) do
    with {:ok, <<msb>>} <- Registers.read_p_max_msb(conn),
         {:ok, <<csb>>} <- Registers.read_p_max_csb(conn),
         {:ok, <<lsb>>} <- Registers.read_p_max_lsb(conn),
         do: {:ok, to_pressure(<<msb, csb, lsb>>)}
  end

  @doc """
  P_MAX Captured maximum Pressure/Altitude value.
  """
  @spec maximum_altitude(t) :: {:ok, altitude} | {:error, reason :: any}
  def maximum_altitude(%MPL3115A2{conn: conn}) do
    with {:ok, <<msb>>} <- Registers.read_p_max_msb(conn),
         {:ok, <<csb>>} <- Registers.read_p_max_csb(conn),
         {:ok, <<lsb>>} <- Registers.read_p_max_lsb(conn),
         do: {:ok, to_altitude(<<msb, csb, lsb>>)}
  end

  @doc """
  T_MIN Captured minimum temperature value.
  """
  @spec minimum_temperature(t) :: {:ok, temperature} | {:error, reason :: any}
  def minimum_temperature(%MPL3115A2{conn: conn}) do
    with {:ok, <<msb>>} <- Registers.read_t_min_msb(conn),
         {:ok, <<lsb>>} <- Registers.read_t_min_lsb(conn),
         do: {:ok, to_temperature(<<msb, lsb>>)}
  end

  @doc """
  T_MAX Captured maximum temperature value.
  """
  @spec maximum_temperature(t) :: {:ok, temperature} | {:error, reason :: any}
  def maximum_temperature(%MPL3115A2{conn: conn}) do
    with {:ok, <<msb>>} <- Registers.read_t_max_msb(conn),
         {:ok, <<lsb>>} <- Registers.read_t_max_lsb(conn),
         do: {:ok, to_temperature(<<msb, lsb>>)}
  end

  defp fifo_read(conn, count) do
    with {:ok, fifo} <-
           Enum.reduce_while(1..count, {:ok, []}, fn _, {:ok, acc} ->
             with {:ok, <<msb>>} <- Registers.read_f_data(conn),
                  {:ok, <<csb>>} <- Registers.read_f_data(conn),
                  {:ok, <<lsb>>} <- Registers.read_f_data(conn) do
               {:cont, {:ok, [<<msb, csb, lsb>> | acc]}}
             else
               {:error, reason} -> {:halt, {:error, reason}}
             end
           end),
         do: {:ok, Enum.reverse(fifo)}
  end

  @doc """
  SBYB System Standby
  """
  @spec standby_mode?(t) :: boolean
  def standby_mode?(%MPL3115A2{conn: conn}) do
    with {:ok, data} <- Registers.read_ctrl_reg1(conn),
         true <- get_bool(data, 0),
         do: true,
         else: (_ -> false)
  end

  @doc """
  SBYB System Standby
  """
  @spec standby_mode(t, boolean) :: {:ok, t} | {:error, reason :: any}
  def standby_mode(%MPL3115A2{conn: conn} = dev, value) when is_boolean(value) do
    with {:ok, conn} <- Registers.update_ctrl_reg1(conn, &set_bit(&1, 0)),
         do: {:ok, %{dev | conn: conn}}
  end

  @doc """
  OST One-shot measurement

  OST bit will initiate a measurement immediately. If the SBYB bit is set to
  active, setting the OST bit will initiate an immediate measurement, the part
  will then return to acquiring data as per the setting of the ST bits in
  CTRL_REG2. In this mode, the OST bit does not clear itself and must be
  cleared and set again to initiate another immediate measurement.

  One Shot: When SBYB is 0, the OST bit is an auto-clear bit. When OST is set,
  the device initiates a measurement by going into active mode. Once a
  Pressure/Altitude and Temperature measurement is completed, it clears the
  OST bit and comes back to STANDBY mode. User shall read the value of the OST
  bit before writing to this bit again.
  """
  @spec oneshot_mode?(t) :: boolean
  def oneshot_mode?(%MPL3115A2{conn: conn}) do
    with {:ok, data} <- Registers.read_ctrl_reg1(conn),
         true <- get_bool(data, 1),
         do: true,
         else: (_ -> false)
  end

  @doc """
  OST One-shot measurement

  OST bit will initiate a measurement immediately. If the SBYB bit is set to
  active, setting the OST bit will initiate an immediate measurement, the part
  will then return to acquiring data as per the setting of the ST bits in
  CTRL_REG2. In this mode, the OST bit does not clear itself and must be
  cleared and set again to initiate another immediate measurement.

  One Shot: When SBYB is 0, the OST bit is an auto-clear bit. When OST is set,
  the device initiates a measurement by going into active mode. Once a
  Pressure/Altitude and Temperature measurement is completed, it clears the
  OST bit and comes back to STANDBY mode. User shall read the value of the OST
  bit before writing to this bit again.
  """
  @spec oneshot_mode(t, boolean) :: {:ok, t} | {:error, reason :: any}
  def oneshot_mode(%MPL3115A2{conn: conn} = dev, value) when is_boolean(value) do
    with {:ok, conn} <- Registers.update_ctrl_reg1(conn, &set_bit(&1, 1)),
         do: {:ok, %{dev | conn: conn}}
  end

  @doc """
  RST Software Reset.

  This bit is used to activate the software reset. The Boot mechanism can be
  enabled in STANDBY and ACTIVE mode.

  When the Boot bit is enabled the boot mechanism resets all functional block
  registers and loads the respective internal registers with default values.
  If the system was already in STANDBY mode, the reboot process will
  immediately begin; else if the system was in ACTIVE mode, the boot mechanism
  will automatically transition the system from ACTIVE mode to STANDBY mode,
  only then can the reboot process begin.

  The I2C communication system is reset to avoid accidental corrupted data access.
  """
  @spec reset(t) :: {:ok, t} | {:error, reason :: any}
  def reset(%MPL3115A2{conn: conn} = dev) do
    with {:ok, conn} <- Registers.update_ctrl_reg1(conn, &set_bit(&1, 2)),
         do: {:ok, %{dev | conn: conn}}
  end

  @doc """
  OS Oversample Ratio.
  """
  @spec oversample_ratio(t) :: {:ok, non_neg_integer} | {:error, reason :: any}
  def oversample_ratio(%MPL3115A2{conn: conn}) do
    with {:ok, <<data>>} <- Registers.read_ctrl_reg1(conn) do
      ratio =
        2
        |> :math.pow(data >>> 3 &&& 0x3)
        |> trunc()

      {:ok, ratio}
    end
  end

  @doc """
  OS Oversample Ratio.
  """
  @spec oversample_ratio(t, non_neg_integer) :: {:ok, t} | {:error, reason :: any}
  def oversample_ratio(%MPL3115A2{conn: conn} = dev, value)
      when is_integer(value) and value >= 1 do
    value =
      value
      |> :math.sqrt()
      |> band(0x3)

    with {:ok, conn} <-
           Registers.update_ctrl_reg1(conn, fn <<data>> ->
             head = data >>> 5
             tail = data &&& 0x7
             <<(head <<< 5) + (value <<< 3) + tail>>
           end),
         do: {:ok, %{dev | conn: conn}}
  end

  @doc """
  Oversample delay in milliseconds.
  """
  @spec oversample_delay(t) :: {:ok, non_neg_integer} | {:error, reason :: any}
  # credo:disable-for-next-line
  def oversample_delay(conn) do
    case oversample_ratio(conn) do
      {:ok, 1} -> {:ok, 6}
      {:ok, 2} -> {:ok, 10}
      {:ok, 4} -> {:ok, 18}
      {:ok, 8} -> {:ok, 34}
      {:ok, 16} -> {:ok, 66}
      {:ok, 32} -> {:ok, 130}
      {:ok, 64} -> {:ok, 258}
      {:ok, 128} -> {:ok, 512}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  RAW Raw output mode.

  RAW bit will output ADC data with no post processing, except for
  oversampling. No scaling or offsets will be applied in the digital domain.
  The FIFO must be disabled and all other functionality: Alarms, Deltas, and
  other interrupts are disabled.
  """
  @spec raw_output?(t) :: boolean
  def raw_output?(%MPL3115A2{conn: conn}) do
    with {:ok, data} <- Registers.read_ctrl_reg1(conn),
         true <- get_bool(data, 6),
         do: true,
         else: (_ -> false)
  end

  @doc """
  RAW Raw output mode.

  RAW bit will output ADC data with no post processing, except for
  oversampling. No scaling or offsets will be applied in the digital domain.
  The FIFO must be disabled and all other functionality: Alarms, Deltas, and
  other interrupts are disabled.
  """
  @spec raw_output(t, boolean) :: {:ok, t} | {:error, reason :: any}
  def raw_output(%MPL3115A2{conn: conn} = dev, value) when is_boolean(value) do
    with {:ok, conn} <- Registers.update_ctrl_reg1(conn, &set_bit(&1, 6, value)),
         do: {:ok, %{dev | conn: conn}}
  end

  @doc """
  ALT Altimeter-Barometer mode.

  Selects whether the device is in Altimeter or Barometer mode.
  Can be either `:barometer` or `:altimeter`.
  """
  @spec operating_mode(t) :: {:ok, mode} | {:error, reason :: any}
  def operating_mode(%MPL3115A2{conn: conn}) do
    with {:ok, <<data>>} <- Registers.read_ctrl_reg1(conn) do
      case get_bit(data, 7) do
        0 -> :barometer
        1 -> :altimeter
      end
    end
  end

  @doc """
  ALT Altimeter-Barometer mode.

  Selects whether the device is in Altimeter or Barometer mode.
  Can be either `:barometer` or `:altimeter`.
  """
  @spec operating_mode(t, mode) :: {:ok, t} | {:error, reason :: any}
  def operating_mode(%MPL3115A2{conn: conn} = dev, :barometer) do
    with {:ok, conn} <- Registers.update_ctrl_reg1(conn, &clear_bit(&1, 7)),
         do: {:ok, %{dev | conn: conn}}
  end

  def operating_mode(%MPL3115A2{conn: conn} = dev, :altimeter) do
    with {:ok, conn} <- Registers.update_ctrl_reg1(conn, &set_bit(&1, 7)),
         do: {:ok, %{dev | conn: conn}}
  end

  @doc """
  ST Auto acquisition time step.
  """
  @spec data_acquisition_time_step(t) :: {:ok, non_neg_integer} | {:error, reason :: any}
  def data_acquisition_time_step(%MPL3115A2{conn: conn}) do
    with {:ok, <<data>>} <- Registers.read_ctrl_reg2(conn), do: {:ok, :math.pow(2, data &&& 0xF)}
  end

  @doc """
  ST Auto acquisition time step.
  """
  @spec data_acquisition_time_step(t, non_neg_integer) :: {:ok, t} | {:error, reason :: any}
  def data_acquisition_time_step(%MPL3115A2{conn: conn} = dev, value)
      when is_integer(value) and value >= 0 do
    value =
      value
      |> :math.sqrt()

    with {:ok, conn} <-
           Registers.update_ctrl_reg2(conn, fn <<data>> ->
             <<(data >>> 3 <<< 3) + (value &&& 0xF)>>
           end),
         do: {:ok, %{dev | conn: conn}}
  end

  @doc """
  ALARM_SEL The bit selects the Target value for SRC_PW/SRC_TW and SRC_PTH/SRC_TTH

  Default value: 0
  0: The values in P_TGT_MSB, P_TGT_LSB and T_TGT are used (Default)
  1: The values in OUT_P/OUT_T are used for calculating the interrupts SRC_PW/SRC_TW and SRC_PTH/SRC_TTH.
  """
  @spec alarm_select(t) :: {:ok, 0 | 1} | {:error, reason :: any}
  def alarm_select(%MPL3115A2{conn: conn}) do
    with {:ok, data} <- Registers.read_ctrl_reg2(conn), do: {:ok, get_bit(data, 4)}
  end

  @doc """
  ALARM_SEL The bit selects the Target value for SRC_PW/SRC_TW and SRC_PTH/SRC_TTH

  Default value: 0
  0: The values in P_TGT_MSB, P_TGT_LSB and T_TGT are used (Default)
  1: The values in OUT_P/OUT_T are used for calculating the interrupts SRC_PW/SRC_TW and SRC_PTH/SRC_TTH.
  """
  @spec alarm_select(t, 0 | 1) :: {:ok, t} | {:error, reason :: any}
  def alarm_select(%MPL3115A2{conn: conn} = dev, value) when value in [0, 1] do
    with {:ok, conn} <- Registers.update_ctrl_reg2(conn, &set_bit(&1, 4, value)),
         do: {:ok, %{dev | conn: conn}}
  end

  @doc """
  LOAD_OUTPUT This is to load the target values for SRC_PW/SRC_TW and SRC_PTH/SRC_TTH.

  Default value: 0
  0: Do not load OUT_P/OUT_T as target values
  1: The next values of OUT_P/OUT_T are used to set the target values for the interrupts. Note:
      1. This bit must be set at least once if ALARM_SEL=1
      2. To reload the next OUT_P/OUT_T as the target values clear and set again.
  """
  @spec load_output(t) :: {:ok, 0 | 1} | {:error, reason :: any}
  def load_output(%MPL3115A2{conn: conn}) do
    with {:ok, data} <- Registers.read_ctrl_reg2(conn), do: {:ok, get_bit(data, 5)}
  end

  @doc """
  LOAD_OUTPUT This is to load the target values for SRC_PW/SRC_TW and SRC_PTH/SRC_TTH.

  Default value: 0
  0: Do not load OUT_P/OUT_T as target values
  1: The next values of OUT_P/OUT_T are used to set the target values for the interrupts. Note:
      1. This bit must be set at least once if ALARM_SEL=1
      2. To reload the next OUT_P/OUT_T as the target values clear and set again.
  """
  @spec load_output(t, 0 | 1) :: {:ok, t} | {:error, reason :: any}
  def load_output(%MPL3115A2{conn: conn} = dev, value) when value in [0, 1] do
    with {:ok, conn} <- Registers.update_ctrl_reg2(conn, &set_bit(&1, 5, value)),
         do: {:ok, %{dev | conn: conn}}
  end

  @doc """
  IPOL1 The IPOL bit selects the polarity of the interrupt signal.

  Select whether the interrupt pin should be used in an active high or active
  low configuration.  Defaults to active low.
  """
  @spec interrupt1_polarity(t) :: {:ok, :active_high | :active_low} | {:error, reason :: any}
  def interrupt1_polarity(%MPL3115A2{conn: conn}) do
    with {:ok, data} <- Registers.read_ctrl_reg3(conn) do
      mode =
        case get_bit(data, 5) do
          0 -> :active_low
          1 -> :active_high
        end

      {:ok, mode}
    end
  end

  @doc """
  IPOL1 The IPOL bit selects the polarity of the interrupt signal.

  Select whether the interrupt pin should be used in an active high or active
  low configuration.  Defaults to active low.
  """
  @spec interrupt1_polarity(t, :active_high | :active_low) :: {:ok, t} | {:error, reason :: any}
  def interrupt1_polarity(%MPL3115A2{conn: conn} = dev, :active_high) do
    with {:ok, conn} <- Registers.update_ctrl_reg3(conn, &set_bit(&1, 3)),
         do: {:ok, %{dev | conn: conn}}
  end

  def interrupt1_polarity(%MPL3115A2{conn: conn} = dev, :active_low) do
    with {:ok, conn} <- Registers.update_ctrl_reg3(conn, &clear_bit(&1, 3)),
         do: {:ok, %{dev | conn: conn}}
  end

  @doc """
  PP_OD1 This bit configures the interrupt pin to Push-Pull or in Open Drain mode.

  The default value is 0 which corresponds to Push-Pull mode. The open drain
  configuration can be used for connecting multiple interrupt signals on the
  same interrupt line. Push-Pull/Open Drain selection on interrupt pad INT1.

  Can be in either pull up or open drain mode. Defaults to pull up.
  """
  @spec interrupt1_pull_mode(t) :: {:ok, :pull_up | :open_drain} | {:error, reason :: any}
  def interrupt1_pull_mode(%MPL3115A2{conn: conn}) do
    with {:ok, data} <- Registers.read_ctrl_reg3(conn) do
      mode =
        case get_bit(data, 4) do
          0 -> :pull_up
          1 -> :open_drain
        end

      {:ok, mode}
    end
  end

  @doc """
  PP_OD1 This bit configures the interrupt pin to Push-Pull or in Open Drain mode.

  The default value is 0 which corresponds to Push-Pull mode. The open drain
  configuration can be used for connecting multiple interrupt signals on the
  same interrupt line. Push-Pull/Open Drain selection on interrupt pad INT1.

  Can be in either pull up or open drain mode. Defaults to pull up.
  """
  @spec interrupt1_pull_mode(t, :pull_up | :open_drain) :: {:ok, t} | {:error, reason :: any}
  def interrupt1_pull_mode(%MPL3115A2{conn: conn} = dev, :pull_up) do
    with {:ok, conn} <- Registers.update_ctrl_reg3(conn, &clear_bit(&1, 4)),
         do: {:ok, %{dev | conn: conn}}
  end

  def interrupt1_pull_mode(%MPL3115A2{conn: conn} = dev, :open_drain) do
    with {:ok, conn} <- Registers.update_ctrl_reg3(conn, &set_bit(&1, 4)),
         do: {:ok, %{dev | conn: conn}}
  end

  @doc """
  IPOL2 The IPOL bit selects the polarity of the interrupt signal.

  Select whether the interrupt pin should be used in an active high or active
  low configuration.  Defaults to active low.
  """
  @spec interrupt2_polarity(t) :: {:ok, :active_high | :active_low} | {:error, reason :: any}
  def interrupt2_polarity(%MPL3115A2{conn: conn}) do
    with {:ok, data} <- Registers.read_ctrl_reg3(conn) do
      mode =
        case get_bit(data, 1) do
          0 -> :active_low
          1 -> :active_high
        end

      {:ok, mode}
    end
  end

  @doc """
  IPOL2 The IPOL bit selects the polarity of the interrupt signal.

  Select whether the interrupt pin should be used in an active high or active
  low configuration.  Defaults to active low.
  """
  @spec interrupt2_polarity(t, :active_high | :active_low) :: {:ok, t} | {:error, reason :: any}
  def interrupt2_polarity(%MPL3115A2{conn: conn} = dev, :active_high) do
    with {:ok, conn} <- Registers.update_ctrl_reg3(conn, &set_bit(&1, 1)),
         do: {:ok, %{dev | conn: conn}}
  end

  def interrupt2_polarity(%MPL3115A2{conn: conn} = dev, :active_low) do
    with {:ok, conn} <- Registers.update_ctrl_reg3(conn, &clear_bit(&1, 1)),
         do: {:ok, %{dev | conn: conn}}
  end

  @doc """
  PP_OD2 This bit configures the interrupt pin to Push-Pull or in Open Drain mode.

  The default value is 0 which corresponds to Push-Pull mode. The open drain
  configuration can be used for connecting multiple interrupt signals on the
  same interrupt line. Push-Pull/Open Drain selection on interrupt pad INT1.

  Can be in either pull up or open drain mode. Defaults to pull up.
  """
  @spec interrupt2_pull_mode(t) :: {:ok, :pull_up | :open_drain} | {:error, reason :: any}
  def interrupt2_pull_mode(%MPL3115A2{conn: conn}) do
    with {:ok, data} <- Registers.read_ctrl_reg3(conn) do
      mode =
        case get_bit(data, 0) do
          0 -> :pull_up
          1 -> :open_drain
        end

      {:ok, mode}
    end
  end

  @doc """
  PP_OD2 This bit configures the interrupt pin to Push-Pull or in Open Drain mode.

  The default value is 0 which corresponds to Push-Pull mode. The open drain
  configuration can be used for connecting multiple interrupt signals on the
  same interrupt line. Push-Pull/Open Drain selection on interrupt pad INT1.

  Can be in either pull up or open drain mode. Defaults to pull up.
  """
  @spec interrupt2_pull_mode(t, :pull_up | :open_drain) :: {:ok, t} | {:error, reason :: any}
  def interrupt2_pull_mode(%MPL3115A2{conn: conn} = dev, :pull_up) do
    with {:ok, conn} <- Registers.update_ctrl_reg3(conn, &clear_bit(&1, 0)),
         do: {:ok, %{dev | conn: conn}}
  end

  def interrupt2_pull_mode(%MPL3115A2{conn: conn} = dev, :open_drain) do
    with {:ok, conn} <- Registers.update_ctrl_reg3(conn, &set_bit(&1, 0)),
         do: {:ok, %{dev | conn: conn}}
  end

  @doc """
  INT_EN_DRDY Data Ready Interrupt Enable.

  Defaults to `false`.
  """
  @spec interrupt_enable_data_ready?(t) :: boolean
  def interrupt_enable_data_ready?(%MPL3115A2{conn: conn}) do
    with {:ok, data} <- Registers.read_ctrl_reg4(conn),
         true <- get_bool(data, 7),
         do: true,
         else: (_ -> false)
  end

  @doc """
  INT_EN_DRDY Data Ready Interrupt Enable.

  Defaults to `false`.
  """
  @spec interrupt_enable_data_ready(t, boolean) :: {:ok, t} | {:error, reason :: any}
  def interrupt_enable_data_ready(%MPL3115A2{conn: conn} = dev, value) when is_boolean(value) do
    with {:ok, conn} <- Registers.update_ctrl_reg4(conn, &set_bit(&1, 7, value)),
         do: {:ok, %{dev | conn: conn}}
  end

  @doc """
  INT_EN_FIFO FIFO Interrupt Enable.

  Default value: false
  false: FIFO interrupt disabled
  true: FIFO interrupt enabled
  """
  @spec interrupt_enable_fifo?(t) :: boolean
  def interrupt_enable_fifo?(%MPL3115A2{conn: conn}) do
    with {:ok, data} <- Registers.read_ctrl_reg4(conn),
         true <- get_bool(data, 6),
         do: true,
         else: (_ -> false)
  end

  @doc """
  INT_EN_FIFO FIFO Interrupt Enable.

  Default value: false
  false: FIFO interrupt disabled
  true: FIFO interrupt enabled
  """
  @spec interrupt_enable_fifo(t, boolean) :: {:ok, t} | {:error, reason :: any}
  def interrupt_enable_fifo(%MPL3115A2{conn: conn} = dev, value) when is_boolean(value) do
    with {:ok, conn} <- Registers.update_ctrl_reg4(conn, &set_bit(&1, 6, value)),
         do: {:ok, %{dev | conn: conn}}
  end

  @doc """
  INT_EN_PW Pressure Window Interrupt Enable.

  Default value: false
  false: Pressure window interrupt disabled
  true: Pressure window interrupt enabled
  """
  @spec interrupt_enable_pressure_window?(t) :: boolean
  def interrupt_enable_pressure_window?(%MPL3115A2{conn: conn}) do
    with {:ok, data} <- Registers.read_ctrl_reg4(conn),
         true <- get_bool(data, 5),
         do: true,
         else: (_ -> false)
  end

  @doc """
  INT_EN_PW Pressure Window Interrupt Enable.

  Default value: false
  false: Pressure window interrupt disabled
  true: Pressure window interrupt enabled
  """
  @spec interrupt_enable_pressure_window(t, boolean) :: {:ok, t} | {:error, reason :: any}
  def interrupt_enable_pressure_window(%MPL3115A2{conn: conn} = dev, value)
      when is_boolean(value) do
    with {:ok, conn} <- Registers.update_ctrl_reg4(conn, &set_bit(&1, 5, value)),
         do: {:ok, %{dev | conn: conn}}
  end

  @doc """
  INT_EN_TW Temperature Window Interrupt Enable.

  Interrupt Enable.
  Default value: false
  false: Temperature window interrupt disabled
  true: Temperature window interrupt enabled
  """
  @spec interrupt_enable_temperature_window?(t) :: boolean
  def interrupt_enable_temperature_window?(%MPL3115A2{conn: conn}) do
    with {:ok, data} <- Registers.read_ctrl_reg4(conn),
         true <- get_bool(data, 4),
         do: true,
         else: (_ -> false)
  end

  @doc """
  INT_EN_TW Temperature Window Interrupt Enable.

  Interrupt Enable.
  Default value: false
  false: Temperature window interrupt disabled
  true: Temperature window interrupt enabled
  """
  @spec interrupt_enable_temperature_window(t, boolean) :: {:ok, t} | {:error, reason :: any}
  def interrupt_enable_temperature_window(%MPL3115A2{conn: conn} = dev, value)
      when is_boolean(value) do
    with {:ok, conn} <- Registers.update_ctrl_reg4(conn, &set_bit(&1, 4, value)),
         do: {:ok, %{dev | conn: conn}}
  end

  @doc """
  INT_EN_PTH Pressure Threshold Interrupt Enable.

  Default value: false
  false: Pressure Threshold interrupt disabled
  true: Pressure Threshold interrupt enabled
  """
  @spec interrupt_enable_pressure_threshold?(t) :: boolean
  def interrupt_enable_pressure_threshold?(%MPL3115A2{conn: conn}) do
    with {:ok, data} <- Registers.read_ctrl_reg4(conn),
         true <- get_bool(data, 3),
         do: true,
         else: (_ -> false)
  end

  @doc """
  INT_EN_PTH Pressure Threshold Interrupt Enable.

  Default value: false
  false: Pressure Threshold interrupt disabled
  true: Pressure Threshold interrupt enabled
  """
  @spec interrupt_enable_pressure_threshold(t, boolean) :: {:ok, t} | {:error, reason :: any}
  def interrupt_enable_pressure_threshold(%MPL3115A2{conn: conn} = dev, value)
      when is_boolean(value) do
    with {:ok, conn} <- Registers.update_ctrl_reg4(conn, &set_bit(&1, 3, value)),
         do: {:ok, %{dev | conn: conn}}
  end

  @doc """
  INT_EN_TTH Temperature Threshold Interrupt Enable.

  Default value: false
  false: Temperature Threshold interrupt disabled
  true: Temperature Threshold interrupt enabled
  """
  @spec interrupt_enable_temperature_threshold?(t) :: boolean
  def interrupt_enable_temperature_threshold?(%MPL3115A2{conn: conn}) do
    with {:ok, data} <- Registers.read_ctrl_reg4(conn),
         true <- get_bool(data, 2),
         do: true,
         else: (_ -> false)
  end

  @doc """
  INT_EN_TTH Temperature Threshold Interrupt Enable.

  Default value: false
  false: Temperature Threshold interrupt disabled
  true: Temperature Threshold interrupt enabled
  """
  @spec interrupt_enable_temperature_threshold(t, boolean) :: {:ok, t} | {:error, reason :: any}
  def interrupt_enable_temperature_threshold(%MPL3115A2{conn: conn} = dev, value)
      when is_boolean(value) do
    with {:ok, conn} <- Registers.update_ctrl_reg4(conn, &set_bit(&1, 2, value)),
         do: {:ok, %{dev | conn: conn}}
  end

  @doc """
  INT_EN_PCHG Pressure Change Interrupt Enable.

  Default value: false
  false: Pressure Change interrupt disabled
  true: Pressure Change interrupt enabled
  """
  @spec interrupt_enable_pressure_change?(t) :: boolean
  def interrupt_enable_pressure_change?(%MPL3115A2{conn: conn}) do
    with {:ok, data} <- Registers.read_ctrl_reg4(conn),
         true <- get_bool(data, 1),
         do: true,
         else: (_ -> false)
  end

  @doc """
  INT_EN_PCHG Pressure Change Interrupt Enable.

  Default value: false
  false: Pressure Change interrupt disabled
  true: Pressure Change interrupt enabled
  """
  @spec interrupt_enable_pressure_change(t, boolean) :: {:ok, t} | {:error, reason :: any}
  def interrupt_enable_pressure_change(%MPL3115A2{conn: conn} = dev, value)
      when is_boolean(value) do
    with {:ok, conn} <- Registers.update_ctrl_reg4(conn, &set_bit(&1, 1, value)),
         do: {:ok, %{dev | conn: conn}}
  end

  @doc """
  INT_EN_TCHG Temperature Change Interrupt Enable.

  Default value: false
  false: Temperature Change interrupt disabled
  true: Temperature Change interrupt enabled
  """
  @spec interrupt_enable_temperature_change?(t) :: boolean
  def interrupt_enable_temperature_change?(%MPL3115A2{conn: conn}) do
    with {:ok, data} <- Registers.read_ctrl_reg4(conn),
         true <- get_bool(data, 0),
         do: true,
         else: (_ -> false)
  end

  @doc """
  INT_EN_TCHG Temperature Change Interrupt Enable.

  Default value: false
  false: Temperature Change interrupt disabled
  true: Temperature Change interrupt enabled
  """
  @spec interrupt_enable_temperature_change(t, boolean) :: {:ok, t} | {:error, reason :: any}
  def interrupt_enable_temperature_change(%MPL3115A2{conn: conn} = dev, value)
      when is_boolean(value) do
    with {:ok, conn} <- Registers.update_ctrl_reg4(conn, &set_bit(&1, 0, value)),
         do: {:ok, %{dev | conn: conn}}
  end

  @doc """
  INT_CFG_DRDY Data Ready Interrupt Pin Select.

  `1` - Interrupt Pin 1
  `2` - Interrupt Pin 2
  """
  @spec interupt_data_ready_pin(t) :: {:ok, 1 | 2} | {:error, reason :: any}
  def interupt_data_ready_pin(%MPL3115A2{conn: conn}) do
    with {:ok, data} <- Registers.read_ctrl_reg5(conn) do
      {:ok, get_bit(data, 7) + 1}
    end
  end

  @doc """
  INT_CFG_DRDY Data Ready Interrupt Pin Select.

  `1` - Interrupt Pin 1
  `2` - Interrupt Pin 2
  """
  @spec interrupt_data_ready_pin(t, 1 | 2) :: {:ok, t} | {:error, reason :: any}
  def interrupt_data_ready_pin(%MPL3115A2{conn: conn} = dev, 1) do
    with {:ok, conn} <- Registers.update_ctrl_reg5(conn, &clear_bit(&1, 7)),
         do: {:ok, %{dev | conn: conn}}
  end

  def interrupt_data_ready_pin(%MPL3115A2{conn: conn} = dev, 2) do
    with {:ok, conn} <- Registers.update_ctrl_reg5(conn, &set_bit(&1, 7)),
         do: {:ok, %{dev | conn: conn}}
  end

  @doc """
  INT_CFG_FIFO FIFO Interrupt Pin Select.

  `1` - Interrupt Pin 1
  `2` - Interrupt Pin 2
  """
  @spec interrupt_fifo_pin(t) :: {:ok, 1 | 2} | {:error, reason :: any}
  def interrupt_fifo_pin(%MPL3115A2{conn: conn}) do
    with {:ok, data} <- Registers.read_ctrl_reg5(conn) do
      {:ok, get_bit(data, 6) + 1}
    end
  end

  @doc """
  INT_CFG_FIFO FIFO Interrupt Pin Select.

  `1` - Interrupt Pin 1
  `2` - Interrupt Pin 2
  """
  @spec interrupt_fifo_pin(t, 1 | 2) :: {:ok, t} | {:error, reason :: any}
  def interrupt_fifo_pin(%MPL3115A2{conn: conn} = dev, 1) do
    with {:ok, conn} <- Registers.update_ctrl_reg5(conn, &clear_bit(&1, 6)),
         do: {:ok, %{dev | conn: conn}}
  end

  def interrupt_fifo_pin(%MPL3115A2{conn: conn} = dev, 2) do
    with {:ok, conn} <- Registers.update_ctrl_reg5(conn, &set_bit(&1, 6)),
         do: {:ok, %{dev | conn: conn}}
  end

  @doc """
  INT_CFG_PW Pressure Window Interrupt Pin Select

  `1` - Interrupt Pin 1
  `2` - Interrupt Pin 2
  """
  @spec interrupt_pressure_window_pin(t) :: {:ok, 1 | 2} | {:error, reason :: any}
  def interrupt_pressure_window_pin(%MPL3115A2{conn: conn}) do
    with {:ok, data} <- Registers.read_ctrl_reg5(conn) do
      {:ok, get_bit(data, 5) + 1}
    end
  end

  @doc """
  INT_CFG_PW Pressure Window Interrupt Pin Select

  `1` - Interrupt Pin 1
  `2` - Interrupt Pin 2
  """
  @spec interrupt_pressure_window_pin(t, 1 | 2) :: {:ok, t} | {:error, reason :: any}
  def interrupt_pressure_window_pin(%MPL3115A2{conn: conn} = dev, 1) do
    with {:ok, conn} <- Registers.update_ctrl_reg5(conn, &clear_bit(&1, 5)),
         do: {:ok, %{dev | conn: conn}}
  end

  def interrupt_pressure_window_pin(%MPL3115A2{conn: conn} = dev, 2) do
    with {:ok, conn} <- Registers.update_ctrl_reg5(conn, &set_bit(&1, 5)),
         do: {:ok, %{dev | conn: conn}}
  end

  @doc """
  INT_CFG_TW Temperature Window Interrupt Pin Select

  `1` - Interrupt Pin 1
  `2` - Interrupt Pin 2
  """
  @spec interrupt_temperature_window_pin(t) :: {:ok, 1 | 2} | {:error, reason :: any}
  def interrupt_temperature_window_pin(%MPL3115A2{conn: conn}) do
    with {:ok, data} <- Registers.read_ctrl_reg5(conn) do
      {:ok, get_bit(data, 4) + 1}
    end
  end

  @doc """
  INT_CFG_TW Temperature Window Interrupt Pin Select

  `1` - Interrupt Pin 1
  `2` - Interrupt Pin 2
  """
  @spec interrupt_temperature_window_pin(t, 1 | 2) :: {:ok, t} | {:error, reason :: any}
  def interrupt_temperature_window_pin(%MPL3115A2{conn: conn} = dev, 1) do
    with {:ok, conn} <- Registers.update_ctrl_reg5(conn, &clear_bit(&1, 4)),
         do: {:ok, %{dev | conn: conn}}
  end

  def interrupt_temperature_window_pin(%MPL3115A2{conn: conn} = dev, 2) do
    with {:ok, conn} <- Registers.update_ctrl_reg5(conn, &set_bit(&1, 4)),
         do: {:ok, %{dev | conn: conn}}
  end

  @doc """
  INT_CFG_PTH Pressure Threshold Interrupt Pin Select

  `1` - Interrupt Pin 1
  `2` - Interrupt Pin 2
  """
  @spec interrupt_pressure_threshold_pin(t) :: {:ok, 1 | 2} | {:error, reason :: any}
  def interrupt_pressure_threshold_pin(%MPL3115A2{conn: conn}) do
    with {:ok, data} <- Registers.read_ctrl_reg5(conn) do
      {:ok, get_bit(data, 3) + 1}
    end
  end

  @doc """
  INT_CFG_PTH Pressure Threshold Interrupt Pin Select

  `1` - Interrupt Pin 1
  `2` - Interrupt Pin 2
  """
  @spec interrupt_pressure_threshold_pin(t, 1 | 2) :: {:ok, t} | {:error, reason :: any}
  def interrupt_pressure_threshold_pin(%MPL3115A2{conn: conn} = dev, 1) do
    with {:ok, conn} <- Registers.update_ctrl_reg5(conn, &clear_bit(&1, 3)),
         do: {:ok, %{dev | conn: conn}}
  end

  def interrupt_pressure_threshold_pin(%MPL3115A2{conn: conn} = dev, 2) do
    with {:ok, conn} <- Registers.update_ctrl_reg5(conn, &set_bit(&1, 3)),
         do: {:ok, %{dev | conn: conn}}
  end

  @doc """
  INT_CFG_TTH Temperature Threshold Interrupt Pin Select

  `1` - Interrupt Pin 1
  `2` - Interrupt Pin 2
  """
  @spec interrupt_temperature_threshold_pin(t) :: {:ok, 1 | 2} | {:error, reason :: any}
  def interrupt_temperature_threshold_pin(%MPL3115A2{conn: conn}) do
    with {:ok, data} <- Registers.read_ctrl_reg5(conn) do
      {:ok, get_bit(data, 2) + 1}
    end
  end

  @doc """
  INT_CFG_TTH Temperature Threshold Interrupt Pin Select

  `1` - Interrupt Pin 1
  `2` - Interrupt Pin 2
  """
  @spec interrupt_temperature_threshold_pin(t, 1 | 2) :: {:ok, t} | {:error, reason :: any}
  def interrupt_temperature_threshold_pin(%MPL3115A2{conn: conn} = dev, 1) do
    with {:ok, conn} <- Registers.update_ctrl_reg5(conn, &clear_bit(&1, 2)),
         do: {:ok, %{dev | conn: conn}}
  end

  def interrupt_temperature_threshold_pin(%MPL3115A2{conn: conn} = dev, 2) do
    with {:ok, conn} <- Registers.update_ctrl_reg5(conn, &set_bit(&1, 2)),
         do: {:ok, %{dev | conn: conn}}
  end

  @doc """
  INT_CFG_PCHG - Pressure Change Interrupt Pin Select

  `1` - Interrupt Pin 1
  `2` - Interrupt Pin 2
  """
  @spec interrupt_pressure_change_pin(t) :: {:ok, 1 | 2} | {:error, reason :: any}
  def interrupt_pressure_change_pin(%MPL3115A2{conn: conn}) do
    with {:ok, data} <- Registers.read_ctrl_reg5(conn) do
      {:ok, get_bit(data, 1) + 1}
    end
  end

  @doc """
  INT_CFG_PCHG - Pressure Change Interrupt Pin Select

  `1` - Interrupt Pin 1
  `2` - Interrupt Pin 2
  """
  @spec interrupt_pressure_change_pin(t, 1 | 2) :: {:ok, t} | {:error, reason :: any}
  def interrupt_pressure_change_pin(%MPL3115A2{conn: conn} = dev, 1) do
    with {:ok, conn} <- Registers.update_ctrl_reg5(conn, &clear_bit(&1, 1)),
         do: {:ok, %{dev | conn: conn}}
  end

  def interrupt_pressure_change_pin(%MPL3115A2{conn: conn} = dev, 2) do
    with {:ok, conn} <- Registers.update_ctrl_reg5(conn, &set_bit(&1, 1)),
         do: {:ok, %{dev | conn: conn}}
  end

  @doc """
  INT_CFG_TCHG - Temperature Change Interrupt Pin Select

  `1` - Interrupt Pin 1
  `2` - Interrupt Pin 2
  """
  @spec interrupt_temperature_change_pin(t) :: {:ok, 1 | 2} | {:error, reason :: any}
  def interrupt_temperature_change_pin(%MPL3115A2{conn: conn}) do
    with {:ok, data} <- Registers.read_ctrl_reg5(conn) do
      {:ok, get_bit(data, 0) + 1}
    end
  end

  @doc """
  INT_CFG_TCHG - Temperature Change Interrupt Pin Select

  `1` - Interrupt Pin 1
  `2` - Interrupt Pin 2
  """
  @spec interrupt_temperature_change_pin(t, 1 | 2) :: {:ok, t} | {:error, reason :: any}
  def interrupt_temperature_change_pin(%MPL3115A2{conn: conn} = dev, 1) do
    with {:ok, conn} <- Registers.update_ctrl_reg5(conn, &clear_bit(&1, 0)),
         do: {:ok, %{dev | conn: conn}}
  end

  def interrupt_temperature_change_pin(%MPL3115A2{conn: conn} = dev, 2) do
    with {:ok, conn} <- Registers.update_ctrl_reg5(conn, &set_bit(&1, 0)),
         do: {:ok, %{dev | conn: conn}}
  end

  @doc """
  OFF_P Pressure Offset

  Pressure user accessible offset trim value.
  """
  @spec pressure_offset(t) :: {:ok, non_neg_integer} | {:error, reason :: any}
  def pressure_offset(%MPL3115A2{conn: conn}) do
    with {:ok, <<data>>} <- Registers.read_off_p(conn), do: {:ok, data * 4}
  end

  @doc """
  OFF_P Pressure Offset

  Pressure user accessible offset trim value.
  """
  @spec pressure_offset(t, non_neg_integer) :: {:ok, t} | {:error, reason :: any}
  def pressure_offset(%MPL3115A2{conn: conn} = dev, value)
      when is_number(value) and value >= -512 and value <= 508 do
    value = trunc(value / 4)
    with {:ok, conn} <- Registers.write_off_p(conn, <<value>>), do: {:ok, %{dev | conn: conn}}
  end

  @doc """
  OFF_T Temperature Offset

  Temperature user accessible offset trim value.
  """
  @spec temperature_offset(t) :: {:ok, float} | {:error, reason :: any}
  def temperature_offset(%MPL3115A2{conn: conn}) do
    with {:ok, <<data>>} <- Registers.read_off_p(conn), do: {:ok, data * 0.0625}
  end

  @doc """
  OFF_T Temperature Offset

  Temperature user accessible offset trim value.
  """
  @spec temperature_offset(t, float) :: {:ok, t} | {:error, reason :: any}
  def temperature_offset(%MPL3115A2{conn: conn} = dev, value)
      when is_float(value) and value >= -8 and value <= 7.9375 do
    value = trunc(value / 0.0625)
    with {:ok, conn} <- Registers.write_off_t(conn, <<value>>), do: {:ok, %{dev | conn: conn}}
  end

  @doc """
  OFF_H Altitude Offset

  Altitude user accessible offset trim value.
  """
  @spec altitude_offset(t) :: {:ok, -128..127} | {:error, reason :: any}
  def altitude_offset(%MPL3115A2{conn: conn}) do
    with {:ok, <<data::signed-integer-size(8)>>} <- Registers.read_off_h(conn), do: {:ok, data}
  end

  @doc """
  OFF_H Altitude Offset

  Altitude user accessible offset trim value.
  """
  @spec altitude_offset(t, non_neg_integer) :: {:ok, t} | {:error, reason :: any}
  def altitude_offset(%MPL3115A2{conn: conn} = dev, value)
      when is_integer(value) and value >= -128 and value <= 127 do
    with {:ok, conn} <- Registers.write_off_h(conn, <<value::signed-integer-size(8)>>),
         do: {:ok, %{dev | conn: conn}}
  end

  defp to_altitude(
         <<whole::signed-integer-size(16), fractional::unsigned-integer-size(4), _::size(4)>>
       ),
       do: {:ok, whole + fractional / 16.0}

  defp to_pressure(
         <<whole::unsigned-integer-size(18), fractional::unsigned-integer-size(2), _::size(2)>>
       ),
       do: {:ok, whole + fractional / 4.0}

  defp to_temperature(
         <<whole::signed-integer-size(8), fractional::unsigned-integer-size(4), _::size(4)>>
       ),
       do: {:ok, whole + fractional / 16.0}

  defp to_temperature_delta(
         <<whole::signed-integer-size(8), fractional::unsigned-integer-size(4), _::size(4)>>
       ),
       do: {:ok, whole + fractional / 2.0}
end
