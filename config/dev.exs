import Config
config :circuits_gpio, default_backend: CircuitsFT232H.GPIO.Backend
config :circuits_spi, default_backend: CircuitsFT232H.SPI.Backend
config :circuits_i2c, default_backend: CircuitsFT232H.I2C.Backend
