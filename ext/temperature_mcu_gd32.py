# GD32F303 support for sensor_type: temperature_mcu (out-of-tree overlay)
#
# Upstream klippy/extras/temperature_mcu.py has no entry for MCU=gd32f303
# (reported by firmware built with Klipper PR #7369), so it falls through to
# config_unknown() and raises config_error. Manual sensor_temperature1 /
# sensor_adc1 overrides do not help: they are applied only after the
# MCU-specific config function has returned.
#
# This module wraps PrinterTemperatureMCU.config_unknown at config load time:
# for gd32f303* it applies typical GD32F30x datasheet calibration, for any
# other MCU it defers to the original (which still raises). No tracked file
# of the Klipper checkout is modified, so the overlay survives git pull /
# rebase and Moonraker keeps reporting a clean repo.
#
# Install:  ext/install.sh  (symlinks this file into ~/klipper/klippy/extras/
#           and hides it via .git/info/exclude)
# Enable:   add an empty [temperature_mcu_gd32] section to printer.cfg
# Remove:   once upstream temperature_mcu.py handles gd32f303 natively
#           (install.sh reports this); the wrapper is then simply never called.
#
# Calibration is TYPICAL (GD32F303 has no factory temperature constants);
# expect an error of a few degrees C. Fine-tune with sensor_temperature1 /
# sensor_adc1 in the temperature_mcu section itself.
#
# This file may be distributed under the terms of the GNU GPLv3 license.
import functools
import logging

# GD32F30x datasheet, internal temperature sensor (typical values)
V25 = 1.45          # V, sensor output at 25 C
AVG_SLOPE = 0.0041  # V/C, output decreases as temperature rises
VREF = 3.3          # V, ADC reference (VDDA)

PREFIXES = ('gd32f303',)

def _config_gd32f303(sensor):
    # Same model as upstream config_stm32f1: linear, negative slope
    sensor.slope = VREF / -AVG_SLOPE
    sensor.base_temperature = sensor.calc_base(25., V25 / VREF)

def _install(config):
    from . import temperature_mcu
    cls = temperature_mcu.PrinterTemperatureMCU
    # Modules stay in sys.modules across RESTART: wrap only once
    if getattr(cls, '_gd32_overlay_installed', False):
        return
    if not all(callable(getattr(cls, attr, None))
               for attr in ('config_unknown', 'calc_base')):
        raise config.error(
            "temperature_mcu_gd32: upstream temperature_mcu изменился,"
            " проверьте/удалите оверлей")
    orig = cls.config_unknown
    @functools.wraps(orig)
    def config_unknown(self):
        mcu_type = getattr(self, 'mcu_type', '')
        if not mcu_type.startswith(PREFIXES):
            return orig(self)
        logging.info("temperature_mcu_gd32: using GD32F303 datasheet"
                     " calibration for %s", mcu_type)
        _config_gd32f303(self)
    cls.config_unknown = config_unknown
    cls._gd32_overlay_installed = True

class TemperatureMcuGd32:
    def __init__(self, config):
        _install(config)

def load_config(config):
    return TemperatureMcuGd32(config)
