defmodule MPL3115A2.Commands do
  alias MPL3115A2.Registers
  use Bitwise

  @moduledoc """
  Commands for reading and modifying the device's registers.
  """

  @doc """
  Tries to configure the device according to sane defaults.

  `config` is a map containing any of the following keys:

    - `:standby` set to `true` to put the device in standby, otherwise defaults to `false`.
    - `:oversample` set to the oversample rate you want. Valid values are two's complements from `1` to `128`.  Defaults to `128`.
    - `:mode`, set to either `:altimeter` or `:barometer`. Defaults to `:altimeter`.
    - `:event_on_new_temperature` set to `false` to disable.  Defaults to `true`.
    - `:event_on_new_pressure` set to `false` to disable. Defaults to `true`.
    - `:data_ready_event_mode` set to `false` to disable. Defaults to `true`.
  """
  def initialize!(pid, config) do
    standby =
      case Map.get(config, :standby, false) do
        true -> 0x00
        false -> 0x01
      end

    oversample =
      case Map.get(config, :oversample, 128) do
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
      case Map.get(config, :mode, :altimeter) do
        :altimeter -> 0x80
        :barometer -> 0x00
      end

    tdefe =
      case Map.get(config, :event_on_new_temperature, true) do
        true -> 0x01
        false -> 0x00
      end

    pdefe =
      case Map.get(config, :event_on_new_pressure, true) do
        true -> 0x02
        false -> 0x00
      end

    drem =
      case Map.get(config, :data_ready_event_mode, true) do
        true -> 0x04
        false -> 0x00
      end

    with :ok <- Registers.control_register1(pid, standby ||| oversample ||| mode),
         :ok <- Registers.pt_data_configuration(pid, tdefe ||| pdefe ||| drem) do
      :ok
    end
  end

  @doc """
  PTOW Pressure/Altitude OR Temperature data overwrite.
  """
  def pressure_or_temperature_data_overwrite(pid) do
    pid
    |> Registers.data_ready_status()
    |> get_bit(7)
    |> b
  end

  @doc """
  POW Pressure/Altitude data overwrite.
  """
  def pressure_data_overwrite(pid) do
    pid
    |> Registers.data_ready_status()
    |> get_bit(6)
    |> b
  end

  @doc """
  TOW Temperature data overwrite.
  """
  def temperature_data_overwrite(pid) do
    pid
    |> Registers.data_ready_status()
    |> get_bit(5)
    |> b
  end

  @doc """
  PTDR Pressure/Altitude OR Temperature data ready.
  """
  def pressure_or_temperature_data_ready(pid) do
    pid
    |> Registers.data_ready_status()
    |> get_bit(3)
    |> b
  end

  @doc """
  PDR Pressure/Altitude new data available.
  """
  def pressure_data_available(pid) do
    pid
    |> Registers.data_ready_status()
    |> get_bit(2)
    |> b
  end

  @doc """
  TDR Temperature new Data Available.
  """
  def temperature_data_available(pid) do
    pid
    |> Registers.data_ready_status()
    |> get_bit(1)
    |> b
  end

  @doc """
  OUT_P Altitude in meters.
  """
  def altitude(pid), do: pid |> Registers.pressure_data_out() |> to_altitude()

  @doc """
  OUT_P Pressure in Pascals.
  """
  def pressure(pid), do: pid |> Registers.pressure_data_out() |> to_pressure()

  @doc """
  OUT_T Temperature in ℃.
  """
  def temperature(pid) do
    <<whole::signed-integer-size(8), fractional::unsigned-integer-size(4),
      _::unsigned-integer-size(4)>> = Registers.temperature_data_out(pid)

    whole + fractional / 16.0
  end

  @doc """
  OUT_P_DELTA Altitude delta in meters.
  """
  def altitude_delta(pid) do
    <<whole::signed-integer-size(16), fractional::unsigned-integer-size(4),
      _::unsigned-integer-size(4)>> = Registers.pressure_data_out_delta(pid)

    whole + fractional / 16.0
  end

  @doc """
  OUT_P_DELTA Pressure delta in Pascals.
  """
  def pressure_delta(pid) do
    <<whole::signed-integer-size(18), fractional::unsigned-integer-size(2),
      _::unsigned-integer-size(2)>> = Registers.pressure_data_out_delta(pid)

    whole + fractional / 4.0
  end

  @doc """
  OUT_T_DELTA Temperature delta in ℃.
  """
  def temperature_delta(pid) do
    <<whole::signed-integer-size(8), fractional::unsigned-integer-size(4),
      _::unsigned-integer-size(4)>> = Registers.temperature_data_out_delta(pid)

    whole + fractional / 2.0
  end

  @doc """
  WHO_AM_I Should always respond with 0x0c.
  """
  def who_am_i(pid) do
    <<reg>> = Registers.who_am_i(pid)
    reg
  end

  @doc """
  F_OVF FIFO overflow events detected?
  """
  def fifo_overflow?(pid) do
    pid
    |> Registers.fifo_status()
    |> get_bit(7)
    |> b
  end

  @doc """
  F_WMRK_FLAG FIFO watermark events detected?
  """
  def fifo_watermark?(pid) do
    pid
    |> Registers.fifo_status()
    |> get_bit(6)
    |> b
  end

  @doc """
  F_CNT FIFO sample count
  """
  def fifo_sample_count(pid) do
    <<reg>> = Registers.fifo_status(pid)
    reg &&& 0x1F
  end

  @doc """
  F_DATA Read FIFO data in Altitude mode.
  """
  def fifo_read_altitude(pid) do
    pid
    |> fifo_read
    |> Enum.map(&to_altitude(&1))
  end

  @doc """
  F_DATA Read FIFO data in Barometer mode.
  """
  def fifo_read_pressure(pid) do
    pid
    |> fifo_read
    |> Enum.map(&to_pressure(&1))
  end

  @doc """
  F_MODE FIFO mode, can be either `:fifo_disabled`, `:circular_buffer` or `:halt_on_overflow`.
  """
  def fifo_overflow_mode(pid) do
    <<reg>> = Registers.fifo_setup(pid)

    case reg >>> 6 do
      0 -> :fifo_disabled
      1 -> :circular_buffer
      2 -> :halt_on_overflow
    end
  end

  def fifo_overflow_mode(pid, :fifo_disabled) do
    <<reg>> = Registers.fifo_setup(pid)
    reg = reg &&& 0x7F
    Registers.fifo_setup(pid, reg)
  end

  def fifo_overflow_mode(pid, :circular_buffer) do
    <<reg>> = Registers.fifo_setup(pid)
    reg = reg &&& 0x7F + (1 <<< 6)
    Registers.fifo_setup(pid, reg)
  end

  def fifo_overflow_mode(pid, :halt_on_overflow) do
    <<reg>> = Registers.fifo_setup(pid)
    reg = reg &&& 0x7F + (1 <<< 7)
    Registers.fifo_setup(pid, reg)
  end

  @doc """
  F_WMRK FIFO Event Sample Count Watermark.
  """
  def fifo_event_sample_count_watermark(pid) do
    <<reg>> = Registers.fifo_setup(pid)
    reg &&& 0x1F
  end

  def fifo_event_sample_count_watermark(pid, count) do
    <<reg>> = Registers.fifo_setup(pid)
    reg = (reg >>> 5 <<< 5) + (count &&& 0x1F)
    Registers.fifo_setup(pid, reg)
  end

  @doc """
  TIME_DLY

  The time delay register contains the number of ticks of data sample time
  since the last byte of the FIFO was written. This register starts to
  increment on FIFO overflow or data wrap and clears when last byte of FIFO is
  read.
  """
  def time_delay(pid) do
    <<reg>> = Registers.time_delay(pid)
    reg
  end

  @doc """
  SYSMOD System Mode, either `:standby` or `:active`.
  """
  def system_mode(pid) do
    mode =
      pid
      |> Registers.system_mode()
      |> get_bit(0)

    case mode do
      0 -> :standby
      1 -> :active
    end
  end

  @doc """
  SRC_DRDY Data ready interrupt status.

  `true` indicates that Pressure/Altitude or Temperature data ready interrupt
  is active indicating the presence of new data and/or a data overwrite,
  otherwise it is `false`.
  """
  def data_ready_interrupt?(pid) do
    pid
    |> Registers.interrupt_source()
    |> get_bit(7)
    |> b
  end

  @doc """
  SRC_FIFO FIFO interrupt status.

  `true` indicates that a FIFO interrupt event such as an overflow event has
  occurred. `false` indicates that no FIFO interrupt event has occurred.
  """
  def fifo_interrupt?(pid) do
    pid
    |> Registers.interrupt_source()
    |> get_bit(6)
    |> b
  end

  @doc """
  SRC_PW Altitude/Pressure alerter status near or equal to target Pressure/Altitude.

  Near is within target value ± window value. Window value needs to be non
  zero for interrupt to trigger.
  """
  def altitude_pressure_interrupt?(pid) do
    pid
    |> Registers.interrupt_source()
    |> get_bit(5)
    |> b
  end

  @doc """
  SRC_TW Temperature alerter status bit near or equal to target temperature.

  Near is within target value ± window value. Window value needs to be non zero
  for interrupt to trigger.
  """
  def temperature_interrupt?(pid) do
    pid
    |> Registers.interrupt_source()
    |> get_bit(4)
    |> b
  end

  @doc """
  SRC_PTH Altitude/Pressure threshold interrupt.

  With the window set to a non zero value, the trigger will occur on crossing
  any of the thresholds: upper, center or lower. If the window is set to 0, it
  will only trigger on crossing the center threshold.
  """
  def altitude_pressure_threshold_interrupt?(pid) do
    pid
    |> Registers.interrupt_source()
    |> get_bit(3)
    |> b
  end

  @doc """
  SRC_TTH Temperature threshold interrupt.

  With the window set to a non zero value, the trigger will occur on crossing
  any of the thresholds: upper, center or lower. If the window is set to 0, it
  will only trigger on crossing the center threshold.
  """
  def temperature_threshold_interrupt?(pid) do
    pid
    |> Registers.interrupt_source()
    |> get_bit(2)
    |> b
  end

  @doc """
  SRC_PCHG Delta P interrupt status.
  """
  def altitude_pressure_delta_interrupt?(pid) do
    pid
    |> Registers.interrupt_source()
    |> get_bit(1)
    |> b
  end

  @doc """
  SRC_TCHG Delta T interrupt status.
  """
  def temperature_delta_interrupt?(pid) do
    pid
    |> Registers.interrupt_source()
    |> get_bit(0)
    |> b
  end

  @doc """
  DREM Data ready event mode.

  If the DREM bit is set `true` and one or more of the data ready event flags
  (PDEFE, TDEFE) are enabled, then an event flag will be raised upon change in
  state of the data. If the DREM bit is `false` and one or more of the data
  ready event flags are enabled, then an event flag will be raised whenever
  the system acquires a new set of data.

  Default value: `false`.
  """
  def data_ready_event_mode(pid) do
    pid
    |> Registers.pt_data_configuration()
    |> get_bit(2)
    |> b
  end

  def data_ready_event_mode(pid, true) do
    reg =
      pid
      |> Registers.pt_data_configuration()
      |> set_bit(2)

    Registers.pt_data_configuration(pid, reg)
  end

  def data_ready_event_mode(pid, false) do
    reg =
      pid
      |> Registers.pt_data_configuration()
      |> clear_bit(2)

    Registers.pt_data_configuration(pid, reg)
  end

  @doc """
  PDEFE Data event flag enable on new Pressure/Altitude data.

  Default value: `false`.
  """
  def pressure_altitude_event_flag_enable(pid) do
    pid
    |> Registers.pt_data_configuration()
    |> get_bit(1)
    |> b
  end

  def pressure_altitude_event_flag_enable(pid, true) do
    reg =
      pid
      |> Registers.pt_data_configuration()
      |> set_bit(1)

    Registers.pt_data_configuration(pid, reg)
  end

  def pressure_altitude_event_flag_enable(pid, false) do
    reg =
      pid
      |> Registers.pt_data_configuration()
      |> clear_bit(1)

    Registers.pt_data_configuration(pid, reg)
  end

  @doc """
  TDEFE Data event flag enable on new Temperature data.

  Default value: `false`.
  """
  def temperature_event_flag_enable(pid) do
    pid
    |> Registers.pt_data_configuration()
    |> get_bit(0)
    |> b
  end

  def temperature_event_flag_enable(pid, true) do
    reg =
      pid
      |> Registers.pt_data_configuration()
      |> set_bit(0)

    Registers.pt_data_configuration(pid, reg)
  end

  def temperature_event_flag_enable(pid, false) do
    reg =
      pid
      |> Registers.pt_data_configuration()
      |> clear_bit(0)

    Registers.pt_data_configuration(pid, reg)
  end

  @doc """
  BAR_IN Barometric input for altitude calculations.

  Input is equivalent sea level pressure for measurement location.
  """
  def barometric_pressure_input(pid) do
    <<msb, lsb>> = Registers.barometric_input(pid)
    ((msb <<< 8) + lsb) * 2
  end

  def barometric_pressure_input(pid, pascals) do
    pascals = pascals |> div(2)
    Registers.barometric_input(pid, pascals)
  end

  @doc """
  P_TGT Altitude/Pressure target value.

  This value works in conjunction with the window value (P_WND).

  In Altitude mode the result is in meters.
  In Pressure mode the result is in Pascals.
  """
  def pressure_altitude_target(pid) do
    <<msb, lsb>> = Registers.pressure_target(pid)
    (msb <<< 8) + lsb
  end

  def pressure_altitude_target(pid, value) do
    msb = value >>> 8 &&& 0xFF
    lsb = value &&& 0xFF
    Registers.pressure_target(pid, <<msb, lsb>>)
  end

  @doc """
  T_TGT Temperature target value input in °C.
  """
  def temperature_target(pid) do
    <<reg>> = Registers.temperature_target(pid)
    reg
  end

  def temperature_target(pid, value) do
    Registers.temperature_target(pid, value &&& 0xFF)
  end

  @doc """
  P_WND Pressure/Altitude window value.

  In Altitude mode the result is in meters.
  In Pressure mode the result is in Pascals.
  """
  def pressure_altitude_window(pid) do
    <<msb, lsb>> = Registers.pressure_altitude_window(pid)
    (msb <<< 8) + lsb
  end

  @doc """
  T_WND Temperature alarm window value in °C.
  """
  def temperature_window(pid) do
    <<reg>> = Registers.temperature_window(pid)
    reg
  end

  @doc """
  P_MIN Captured minimum Pressure/Altitude value.
  """
  def minimum_pressure(pid) do
    pid
    |> Registers.minimum_pressure_data(pid)
    |> to_pressure
  end

  @doc """
  P_MAX Captured maximum Pressure/Altitude value.
  """
  def maximum_pressure(pid) do
    pid
    |> Registers.maximum_pressure_data()
    |> to_pressure
  end

  @doc """
  T_MIN Captured minimum temperature value.
  """
  def minimum_temperature(pid) do
    pid
    |> Registers.minimum_temperature_data()
    |> to_temperature()
  end

  @doc """
  T_MAX Captured maximum temperature value.
  """
  def maximum_temperature(pid) do
    pid
    |> Registers.maximum_temperature_data()
    |> to_temperature
  end

  @doc """
  SBYB System Standby
  """
  def standby?(pid) do
    pid
    |> Registers.control_register1()
    |> get_bit(0)
    |> b
  end

  def standby(pid, true) do
    reg =
      pid
      |> Registers.control_register1()
      |> set_bit(0)

    Registers.control_register1(pid, reg)
  end

  def standby(pid, false) do
    reg =
      pid
      |> Registers.control_register1()
      |> clear_bit(0)

    Registers.control_register1(pid, reg)
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
  def one_shot(pid) do
    pid
    |> Registers.control_register1()
    |> get_bit(1)
    |> b
  end

  def one_shot(pid, true) do
    reg =
      pid
      |> Registers.control_register1()
      |> set_bit(1)

    Registers.control_register1(pid, reg)
  end

  def one_shot(pid, false) do
    reg =
      pid
      |> Registers.control_register1()
      |> clear_bit(1)

    Registers.control_register1(pid, reg)
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

  At the end of the boot process the RST bit is de-asserted to `false`. Reading
  this bit will return a value of `false`.

  Default value: `false`
  `false`: Device reset disabled
  `true`: Device reset enabled
  """
  def reset(pid) do
    pid
    |> Registers.control_register1()
    |> get_bit(2)
    |> b
  end

  def reset!(pid) do
    reg =
      pid
      |> Registers.control_register1()
      |> set_bit(2)

    Registers.control_register1(pid, reg)
  end

  @doc """
  OS Oversample Ratio.

  These bits select the oversampling ratio.
  """
  def oversample_ratio(pid) do
    <<reg>> = Registers.control_register1(pid)
    :math.pow(2, reg >>> 3 &&& 0x3) |> trunc
  end

  def oversample_ratio(pid, value) do
    value = :math.sqrt(value) &&& 0x3
    <<reg>> = Registers.control_register1(pid)
    head = reg >>> 5
    tail = reg &&& 0x7
    reg = (head <<< 5) + (value <<< 3) + tail
    Registers.control_register1(pid, reg)
  end

  @doc """
  Oversample delay in ms.
  """
  def oversample_delay(pid) do
    case oversample_ratio(pid) do
      1 -> 6
      2 -> 10
      4 -> 18
      8 -> 34
      16 -> 66
      32 -> 130
      64 -> 258
      128 -> 512
    end
  end

  @doc """
  RAW Raw output mode.

  RAW bit will output ADC data with no post processing, except for
  oversampling. No scaling or offsets will be applied in the digital domain.
  The FIFO must be disabled and all other functionality: Alarms, Deltas, and
  other interrupts are disabled.
  """
  def raw?(pid) do
    pid
    |> Registers.control_register1()
    |> get_bit(6)
    |> b
  end

  def raw(pid, true) do
    reg =
      pid
      |> Registers.control_register1()
      |> set_bit(6)

    Registers.control_register1(pid, reg)
  end

  def raw(pid, false) do
    reg =
      pid
      |> Registers.control_register1()
      |> clear_bit(6)

    Registers.control_register1(pid, reg)
  end

  @doc """
  ALT Altimeter-Barometer mode.

  Selects whether the device is in Altimeter or Barometer mode.
  Can be either `:barometer` or `:altimeter`.
  """
  def altimeter_or_barometer(pid) do
    mode =
      pid
      |> Registers.control_register1()
      |> get_bit(7)

    case mode do
      0 -> :barometer
      1 -> :altimeter
    end
  end

  def altimeter_or_barometer(pid, :barometer) do
    reg =
      pid
      |> Registers.control_register1()
      |> clear_bit(7)

    Registers.control_register1(pid, reg)
  end

  def altimeter_or_barometer(pid, :altimeter) do
    reg =
      pid
      |> Registers.control_register1()
      |> set_bit(7)

    Registers.control_register1(pid, reg)
  end

  @doc """
  ST Auto acquisition time step.
  """
  def data_acquisition_time_step(pid) do
    <<reg>> = Registers.control_register2(pid)
    :math.pow(2, reg &&& 0xF)
  end

  def data_acquisition_time_step(pid, value) do
    value = :math.sqrt(value)
    <<reg>> = Registers.control_register2(pid)
    reg = (reg >>> 3 <<< 3) + (value &&& 0xF)
    Registers.control_register2(pid, reg)
  end

  @doc """
  ALARM_SEL The bit selects the Target value for SRC_PW/SRC_TW and SRC_PTH/SRC_TTH

  Default value: 0
  0: The values in P_TGT_MSB, P_TGT_LSB and T_TGT are used (Default)
  1: The values in OUT_P/OUT_T are used for calculating the interrupts SRC_PW/SRC_TW and SRC_PTH/SRC_TTH.
  """
  def alarm_select(pid) do
    pid
    |> Registers.control_register2()
    |> get_bit(4)
  end

  def alarm_select(pid, i) when i == 0 or i == 1 do
    reg =
      pid
      |> Registers.control_register2()
      |> set_bit(4, i)

    Registers.control_register2(pid, reg)
  end

  @doc """
  LOAD_OUTPUT This is to load the target values for SRC_PW/SRC_TW and SRC_PTH/SRC_TTH.

  Default value: 0
  0: Do not load OUT_P/OUT_T as target values
  1: The next values of OUT_P/OUT_T are used to set the target values for the interrupts. Note:
  1. This bit must be set at least once if ALARM_SEL=1
  2. To reload the next OUT_P/OUT_T as the target values clear and set again.
  """
  def load_output(pid) do
    pid
    |> Registers.control_register2()
    |> get_bit(5)
  end

  def load_output(pid, i) when i == 0 or i == 1 do
    reg =
      pid
      |> Registers.control_register2()
      |> set_bit(4, i)

    Registers.control_register2(pid, reg)
  end

  @doc """
  IPOL1 The IPOL bit selects the polarity of the interrupt signal.

  When IPOL is ‘0’ (default value) any interrupt event will signalled with a
  logical ‘0'. Interrupt Polarity active high, or active low on interrupt pad
  INT1.
  Default value: 0
  0: Active low
  1: Active high
  """
  def interrupt1_polarity(pid) do
    pid
    |> Registers.control_register3()
    |> get_bit(5)
  end

  def interrupt1_polarity(pid, i) when i == 0 or i == 1 do
    reg =
      pid
      |> Registers.control_register3()
      |> set_bit(5, i)

    Registers.control_register3(pid, reg)
  end

  @doc """
  PP_OD1 This bit configures the interrupt pin to Push-Pull or in Open Drain mode.

  The default value is 0 which corresponds to Push-Pull mode. The open drain
  configuration can be used for connecting multiple interrupt signals on the
  same interrupt line. Push-Pull/Open Drain selection on interrupt pad INT1.

  Default value: 0
  0: Internal Pullup
  1: Open drain
  """
  def interrupt1_pp_or_od(pid) do
    pid
    |> Registers.control_register3()
    |> get_bit(4)
  end

  def interrupt1_pp_or_od(pid, i) when i == 0 or i == 1 do
    reg =
      pid
      |> Registers.control_register3()
      |> set_bit(4, i)

    Registers.control_register3(pid, reg)
  end

  @doc """
  IPOL2 Interrupt Polarity active high, or active low on interrupt pad INT2.

  Default value: 0
  0: Active low
  1: Active high
  """
  def interrupt2_polarity(pid) do
    pid
    |> Registers.control_register3()
    |> get_bit(1)
  end

  def interrupt2_polarity(pid, i) when i == 0 or i == 1 do
    reg =
      pid
      |> Registers.control_register3()
      |> set_bit(1, i)

    Registers.control_register3(pid, reg)
  end

  @doc """
  PP_OD2 Push-Pull/Open Drain selection on interrupt pad INT2.

  Default value: 0
  0: Internal Pull-up
  1: Open drain
  """
  def interrupt2_pp_or_od(pid) do
    pid
    |> Registers.control_register3()
    |> get_bit(0)
  end

  def interrupt2_pp_or_od(pid, i) when i == 0 or i == 1 do
    reg =
      pid
      |> Registers.control_register3()
      |> set_bit(0, i)

    Registers.control_register3(pid, reg)
  end

  @doc """
  INT_EN_DRDY Data Ready Interrupt Enable.

  Default value: 0
  0: Data Ready interrupt disabled
  1: Data Ready interrupt enabled
  """
  def interrupt_enable_data_ready(pid) do
    pid
    |> Registers.control_register4()
    |> get_bit(7)
  end

  def interrupt_enable_data_ready(pid, i) when i == 0 or i == 1 do
    reg =
      pid
      |> Registers.control_register4()
      |> set_bit(7, i)

    Registers.control_register4(pid, reg)
  end

  @doc """
  INT_EN_FIFO FIFO Interrupt Enable.

  Default value: 0
  0: FIFO interrupt disabled
  1: FIFO interrupt enabled
  """
  def interrupt_enable_fifo(pid) do
    pid
    |> Registers.control_register4()
    |> get_bit(6)
  end

  def interrupt_enable_fifo(pid, i) when i == 0 or i == 1 do
    reg =
      pid
      |> Registers.control_register4()
      |> set_bit(6, i)

    Registers.control_register4(pid, reg)
  end

  @doc """
  INT_EN_PW Pressure Window Interrupt Enable.

  Default value: 0
  0: Pressure window interrupt disabled
  1: Pressure window interrupt enabled
  """
  def interrupt_enable_pressure_window(pid) do
    pid
    |> Registers.control_register4()
    |> get_bit(5)
  end

  def interrupt_enable_pressure_window(pid, i) when i == 0 or i == 1 do
    reg =
      pid
      |> Registers.control_register4()
      |> set_bit(5, i)

    Registers.control_register4(pid, reg)
  end

  @doc """
  INT_EN_TW Temperature Window Interrupt Enable.

  Interrupt Enable.
  Default value: 0
  0: Temperature window interrupt disabled
  1: Temperature window interrupt enabled
  """
  def interrupt_enable_temperature_window(pid) do
    pid
    |> Registers.control_register4()
    |> get_bit(4)
  end

  def interrupt_enable_temperature_window(pid, i) when i == 0 or i == 1 do
    reg =
      pid
      |> Registers.control_register4()
      |> set_bit(4, i)

    Registers.control_register4(pid, reg)
  end

  @doc """
  INT_EN_PTH Pressure Threshold Interrupt Enable.

  Default value: 0
  0: Pressure Threshold interrupt disabled
  1: Pressure Threshold interrupt enabled
  """
  def interrupt_enable_pressure_threshold(pid) do
    pid
    |> Registers.control_register4()
    |> get_bit(3)
  end

  def interrupt_enable_pressure_threshold(pid, i) when i == 0 or i == 1 do
    reg =
      pid
      |> Registers.control_register4()
      |> set_bit(3, i)

    Registers.control_register4(pid, reg)
  end

  @doc """
  INT_EN_TTH Temperature Threshold Interrupt Enable.

  Default value: 0
  0: Temperature Threshold interrupt disabled
  1: Temperature Threshold interrupt enabled
  """
  def interrupt_enable_temperature_threshold(pid) do
    pid
    |> Registers.control_register4()
    |> get_bit(2)
  end

  def interrupt_enable_temperature_threshold(pid, i) when i == 0 or i == 1 do
    reg =
      pid
      |> Registers.control_register4()
      |> set_bit(2, i)

    Registers.control_register4(pid, reg)
  end

  @doc """
  INT_EN_PCHG Pressure Change Interrupt Enable.

  Default value: 0
  0: Pressure Change interrupt disabled
  1: Pressure Change interrupt enabled
  """
  def interrupt_enable_pressure_change(pid) do
    pid
    |> Registers.control_register4()
    |> get_bit(1)
  end

  def interrupt_enable_pressure_change(pid, i) when i == 0 or i == 1 do
    reg =
      pid
      |> Registers.control_register4()
      |> set_bit(1, i)

    Registers.control_register4(pid, reg)
  end

  @doc """
  INT_EN_TCHG Temperature Change Interrupt Enable.

  Default value: 0
  0: Temperature Change interrupt disabled
  1: Temperature Change interrupt enabled
  """
  def interrupt_enable_temperature_change(pid) do
    pid
    |> Registers.control_register4()
    |> get_bit(0)
  end

  def interrupt_enable_temperature_change(pid, i) when i == 0 or i == 1 do
    reg =
      pid
      |> Registers.control_register4()
      |> set_bit(0, i)

    Registers.control_register4(pid, reg)
  end

  @doc """
  INT_CFG_DRDY Data Ready Interrupt Pin Select.

  `1` - Interrupt Pin 1
  `2` - Interrupt Pin 2
  """
  def interrupt_pin_data_ready(pid) do
    pid
    |> Registers.control_register5()
    |> get_bit(7)
    |> interrupt_pin_select
  end

  def interrupt_pin_data_ready(pid, i) when i == 2 or i == 1 do
    reg =
      pid
      |> Registers.control_register5()
      |> set_bit(7, rem(2, i))

    Registers.control_register5(pid, reg)
  end

  @doc """
  INT_CFG_FIFO FIFO Interrupt Pin Select.

  `1` - Interrupt Pin 1
  `2` - Interrupt Pin 2
  """
  def interrupt_pin_fifo(pid) do
    pid
    |> Registers.control_register5()
    |> get_bit(6)
    |> interrupt_pin_select
  end

  def interrupt_pin_fifo(pid, i) when i == 2 or i == 1 do
    reg =
      pid
      |> Registers.control_register5()
      |> set_bit(6, rem(2, i))

    Registers.control_register5(pid, reg)
  end

  @doc """
  INT_CFG_PW Pressure Window Interrupt Pin Select

  `1` - Interrupt Pin 1
  `2` - Interrupt Pin 2
  """
  def interrupt_pin_pressure_window(pid) do
    pid
    |> Registers.control_register5()
    |> get_bit(5)
    |> interrupt_pin_select
  end

  def interrupt_pin_pressure_window(pid, i) when i == 2 or i == 1 do
    reg =
      pid
      |> Registers.control_register5()
      |> set_bit(5, rem(2, i))

    Registers.control_register5(pid, reg)
  end

  @doc """
  INT_CFG_TW Temperature Window Interrupt Pin Select

  `1` - Interrupt Pin 1
  `2` - Interrupt Pin 2
  """
  def interrupt_pin_temperature_window(pid) do
    pid
    |> Registers.control_register5()
    |> get_bit(4)
    |> interrupt_pin_select
  end

  def interrupt_pin_temperature_window(pid, i) when i == 2 or i == 1 do
    reg =
      pid
      |> Registers.control_register5()
      |> set_bit(4, rem(2, i))

    Registers.control_register5(pid, reg)
  end

  @doc """
  INT_CFG_PTH Pressure Threshold Interrupt Pin Select

  `1` - Interrupt Pin 1
  `2` - Interrupt Pin 2
  """
  def interrupt_pin_pressure_threshold(pid) do
    pid
    |> Registers.control_register5()
    |> get_bit(3)
    |> interrupt_pin_select
  end

  def interrupt_pin_pressure_threshold(pid, i) when i == 2 or i == 1 do
    reg =
      pid
      |> Registers.control_register5()
      |> set_bit(3, rem(2, i))

    Registers.control_register5(pid, reg)
  end

  @doc """
  INT_CFG_TTH Temperature Threshold Interrupt Pin Select

  `1` - Interrupt Pin 1
  `2` - Interrupt Pin 2
  """
  def interrupt_pin_temperature_threshold(pid) do
    pid
    |> Registers.control_register5()
    |> get_bit(2)
    |> interrupt_pin_select
  end

  def interrupt_pin_temperature_threshold(pid, i) when i == 2 or i == 1 do
    reg =
      pid
      |> Registers.control_register5()
      |> set_bit(2, rem(2, i))

    Registers.control_register5(pid, reg)
  end

  @doc """
  INT_CFG_PCHG - Pressure Change Interrupt Pin Select

  `1` - Interrupt Pin 1
  `2` - Interrupt Pin 2
  """
  def interrupt_pin_pressure_change(pid) do
    pid
    |> Registers.control_register5()
    |> get_bit(1)
    |> interrupt_pin_select
  end

  def interrupt_pin_pressure_change(pid, i) when i == 2 or i == 1 do
    reg =
      pid
      |> Registers.control_register5()
      |> set_bit(1, rem(2, i))

    Registers.control_register5(pid, reg)
  end

  @doc """
  INT_CFG_TCHG - Temperature Change Interrupt Pin Select

  `1` - Interrupt Pin 1
  `2` - Interrupt Pin 2
  """
  def interrupt_pin_temperature_change(pid) do
    pid
    |> Registers.control_register5()
    |> get_bit(0)
    |> interrupt_pin_select
  end

  def interrupt_pin_temperature_change(pid, i) when i == 2 or i == 1 do
    reg =
      pid
      |> Registers.control_register5()
      |> set_bit(0, rem(2, i))

    Registers.control_register5(pid, reg)
  end

  @doc """
  OFF_P Pressure Offset

  Pressure user accessible offset trim value.
  """
  def pressure_offset(pid) do
    value =
      pid
      |> Registers.pressure_data_user_offset()

    value * 4
  end

  def pressure_offset(pid, value) do
    pid
    |> Registers.pressure_data_user_offset((value / 4) |> trunc)
  end

  @doc """
  OFF_T Temperature Offset

  Temperature user accessible offset trim value.
  """

  # FIXME: These need to convert the data correctly.
  def temperature_offset(pid) do
    value =
      pid
      |> Registers.temperature_data_user_offset()

    value
  end

  def temperature_offset(pid, value) do
    pid
    |> Registers.temperature_data_user_offset(value)
  end

  @doc """
  OFF_H Altitude Offset

  Altitude user accessible offset trim value.
  """

  # FIXME: These need to convert the data correctly.
  def altitude_offset(pid) do
    value =
      pid
      |> Registers.altitude_data_user_offset()

    value
  end

  def altitude_offset(pid, value) do
    pid
    |> Registers.altitude_data_user_offset(value)
  end

  defp interrupt_pin_select(0), do: 2
  defp interrupt_pin_select(1), do: 1

  defp fifo_read(pid) do
    1..fifo_sample_count(pid)
    |> Enum.map(fn _ ->
      msb = Registers.fifo_data_access(pid)
      csb = Registers.fifo_data_access(pid)
      lsb = Registers.fifo_data_access(pid)
      msb <> csb <> lsb
    end)
  end

  defp to_altitude(
         <<whole::signed-integer-size(16), fractional::unsigned-integer-size(4),
           _::unsigned-integer-size(4)>>
       ),
       do: whole + fractional / 16.0

  defp to_pressure(
         <<whole::unsigned-integer-size(18), fractional::unsigned-integer-size(2),
           _::unsigned-integer-size(2)>>
       ),
       do: whole + fractional / 4.0

  defp to_temperature(
         <<whole::signed-integer-size(8), fractional::unsigned-integer-size(4),
           _::unsigned-integer-size(4)>>
       ),
       do: whole + fractional / 16.0

  defp get_bit(<<byte>>, bit), do: byte >>> bit &&& 1
  defp set_bit(byte, bit), do: set_bit(byte, bit, 1)
  defp set_bit(<<byte>>, bit, 1), do: byte ||| 1 <<< bit
  defp set_bit(byte, bit, 0), do: clear_bit(byte, bit)
  defp clear_bit(<<byte>>, bit), do: byte ||| ~~~(1 <<< bit)

  defp b(0), do: false
  defp b(1), do: true
end
