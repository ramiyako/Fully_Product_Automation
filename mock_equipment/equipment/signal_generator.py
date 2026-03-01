"""
Mock Signal Generator

Simulates an RF signal generator with SCPI interface.
Supports frequency, power, and modulation control.
"""

from typing import Optional
import logging

from .base_equipment import BaseEquipment
from ..state_manager import SignalGeneratorState

logger = logging.getLogger(__name__)


class SignalGenerator(BaseEquipment):
    """
    Mock RF Signal Generator

    Implements SCPI commands for signal generation control
    """

    def __init__(self, config: Optional[dict] = None):
        """Initialize signal generator"""
        super().__init__('signal_generator', config)
        logger.info("Signal Generator initialized")

    @property
    def sg_state(self) -> SignalGeneratorState:
        """Get signal generator state"""
        return self.state

    def handle_command(self, command: str, is_query: bool) -> str:
        """
        Handle signal generator specific SCPI commands

        Args:
            command: SCPI command
            is_query: True if query

        Returns:
            Response string
        """
        cmd_upper = command.upper().replace(' ', '')

        # Frequency commands
        if 'FREQ' in cmd_upper or 'FREQUENCY' in cmd_upper:
            return self._handle_frequency(command, is_query)

        # Power commands
        elif 'POW' in cmd_upper or 'POWER' in cmd_upper or 'AMPL' in cmd_upper:
            return self._handle_power(command, is_query)

        # Output enable/disable
        elif 'OUTP' in cmd_upper or 'OUTPUT' in cmd_upper:
            return self._handle_output(command, is_query)

        # Modulation
        elif 'MOD' in cmd_upper or 'MODULATION' in cmd_upper:
            return self._handle_modulation(command, is_query)

        # Reference
        elif 'ROSC' in cmd_upper or 'REFERENCE' in cmd_upper:
            return self._handle_reference(command, is_query)

        else:
            logger.warning(f"Unknown command: {command}")
            return ''

    def _handle_frequency(self, command: str, is_query: bool) -> str:
        """Handle frequency commands"""
        if is_query:
            return self.format_frequency(self.sg_state.frequency_hz)

        # Set frequency
        value = self.parse_numeric_value(command, r'(?:FREQ(?:UENCY)?(?::CW)?)\s+(\S+)')
        if value is not None:
            # Handle units (assume Hz if < 1e6, MHz if < 1e3, otherwise Hz)
            if value < 1000:
                # Likely GHz
                value = value * 1e9
            elif value < 1e6:
                # Likely MHz
                value = value * 1e6

            self.sg_state.frequency_hz = value
            logger.info(f"Frequency set to {value/1e9:.3f} GHz")

        return ''

    def _handle_power(self, command: str, is_query: bool) -> str:
        """Handle power commands"""
        cmd_upper = command.upper()

        if is_query:
            if 'OFFS' in cmd_upper:
                return self.format_power(self.sg_state.power_offset_db)
            else:
                return self.format_power(self.sg_state.power_dbm)

        # Set power level
        if 'OFFS' in cmd_upper:
            value = self.parse_numeric_value(command, r'(?:POW(?:ER)?(?::OFFS(?:ET)?)?)\s+(\S+)')
            if value is not None:
                self.sg_state.power_offset_db = value
                logger.info(f"Power offset set to {value} dB")
        else:
            value = self.parse_numeric_value(command, r'(?:POW(?:ER)?(?::AMPL(?:ITUDE)?)?)\s+(\S+)')
            if value is not None:
                self.sg_state.power_dbm = value
                logger.info(f"Power set to {value} dBm")

        return ''

    def _handle_output(self, command: str, is_query: bool) -> str:
        """Handle output enable/disable"""
        if is_query:
            return self.format_boolean(self.sg_state.output_enabled)

        cmd_upper = command.upper()

        # Check for ON/OFF or 1/0
        if any(x in cmd_upper for x in ['ON', '1', 'TRUE']):
            self.sg_state.output_enabled = True
            logger.info("Output enabled")
        elif any(x in cmd_upper for x in ['OFF', '0', 'FALSE']):
            self.sg_state.output_enabled = False
            logger.info("Output disabled")

        return ''

    def _handle_modulation(self, command: str, is_query: bool) -> str:
        """Handle modulation commands"""
        cmd_upper = command.upper()

        if is_query:
            if 'TYPE' in cmd_upper:
                return self.sg_state.modulation_type
            else:
                return self.format_boolean(self.sg_state.modulation_enabled)

        # Enable/disable modulation
        if 'TYPE' in cmd_upper:
            # Extract modulation type
            for mod_type in ['AM', 'FM', 'PM', 'OFF']:
                if mod_type in cmd_upper:
                    self.sg_state.modulation_type = mod_type
                    self.sg_state.modulation_enabled = (mod_type != 'OFF')
                    logger.info(f"Modulation type set to {mod_type}")
                    break
        else:
            if any(x in cmd_upper for x in ['ON', '1']):
                self.sg_state.modulation_enabled = True
                logger.info("Modulation enabled")
            elif any(x in cmd_upper for x in ['OFF', '0']):
                self.sg_state.modulation_enabled = False
                logger.info("Modulation disabled")

        return ''

    def _handle_reference(self, command: str, is_query: bool) -> str:
        """Handle reference oscillator commands"""
        cmd_upper = command.upper()

        if is_query:
            if 'FREQ' in cmd_upper:
                return self.format_frequency(self.sg_state.reference_frequency_hz)
            else:
                return self.sg_state.reference_source

        # Set reference source
        if 'INT' in cmd_upper:
            self.sg_state.reference_source = 'INT'
            logger.info("Reference source set to internal")
        elif 'EXT' in cmd_upper:
            self.sg_state.reference_source = 'EXT'
            logger.info("Reference source set to external")

        # Set reference frequency
        value = self.parse_numeric_value(command, r'FREQ(?:UENCY)?\s+(\S+)')
        if value is not None:
            if value < 100:
                value = value * 1e6  # Assume MHz
            self.sg_state.reference_frequency_hz = value
            logger.info(f"Reference frequency set to {value/1e6:.1f} MHz")

        return ''

    def get_output_signal(self) -> Optional[dict]:
        """
        Get current output signal parameters

        Returns:
            Dictionary with signal parameters or None if output disabled
        """
        if not self.sg_state.output_enabled:
            return None

        return {
            'frequency_hz': self.sg_state.frequency_hz,
            'power_dbm': self.sg_state.power_dbm + self.sg_state.power_offset_db,
            'modulation_enabled': self.sg_state.modulation_enabled,
            'modulation_type': self.sg_state.modulation_type
        }
