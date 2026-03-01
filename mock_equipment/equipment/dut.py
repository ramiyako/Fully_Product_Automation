"""
Mock Device Under Test (DUT)

Simulates a Device Under Test with signal processing capabilities.
Can operate in various modes (linear, bypass, amplify).
"""

from typing import Optional
import logging

from base_equipment import BaseEquipment
from state_manager import DUTState

logger = logging.getLogger(__name__)


class DUT(BaseEquipment):
    """
    Mock Device Under Test

    Simulates a DUT with configurable signal processing modes
    """

    def __init__(self, config: Optional[dict] = None):
        """Initialize DUT"""
        super().__init__('dut', config)
        logger.info("DUT initialized")

    @property
    def dut_state(self) -> DUTState:
        """Get DUT state"""
        return self.state

    def handle_command(self, command: str, is_query: bool) -> str:
        """
        Handle DUT specific SCPI commands

        Args:
            command: SCPI command
            is_query: True if query

        Returns:
            Response string
        """
        cmd_upper = command.upper().replace(' ', '')

        # Processing mode
        if 'MODE' in cmd_upper or 'PROCESSING' in cmd_upper:
            return self._handle_mode(command, is_query)

        # Gain/attenuation
        elif 'GAIN' in cmd_upper:
            return self._handle_gain(command, is_query)
        elif 'ATTEN' in cmd_upper:
            return self._handle_attenuation(command, is_query)

        # Status queries
        elif 'TEMP' in cmd_upper or 'TEMPERATURE' in cmd_upper:
            return self._handle_temperature(command, is_query)
        elif 'INPUT:POWER' in cmd_upper or 'INPUTPOWER' in cmd_upper:
            return self._handle_input_power(command, is_query)
        elif 'OUTPUT:POWER' in cmd_upper or 'OUTPUTPOWER' in cmd_upper:
            return self._handle_output_power(command, is_query)

        # Enable/disable
        elif 'OUTP' in cmd_upper or 'OUTPUT' in cmd_upper:
            return self._handle_output(command, is_query)

        else:
            logger.warning(f"Unknown command: {command}")
            return ''

    def _handle_mode(self, command: str, is_query: bool) -> str:
        """Handle processing mode"""
        if is_query:
            return self.dut_state.processing_mode

        cmd_upper = command.upper()

        # Set mode
        if 'LINEAR' in cmd_upper:
            self.dut_state.processing_mode = 'LINEAR'
            logger.info("Processing mode set to LINEAR")
        elif 'BYPASS' in cmd_upper:
            self.dut_state.processing_mode = 'BYPASS'
            logger.info("Processing mode set to BYPASS")
        elif 'AMPLIFY' in cmd_upper or 'AMP' in cmd_upper:
            self.dut_state.processing_mode = 'AMPLIFY'
            logger.info("Processing mode set to AMPLIFY")

        return ''

    def _handle_gain(self, command: str, is_query: bool) -> str:
        """Handle gain setting"""
        if is_query:
            return self.format_power(self.dut_state.gain_db)

        value = self.parse_numeric_value(command, r'GAIN\s+(\S+)')
        if value is not None:
            self.dut_state.gain_db = value
            logger.info(f"Gain set to {value} dB")

        return ''

    def _handle_attenuation(self, command: str, is_query: bool) -> str:
        """Handle attenuation setting"""
        if is_query:
            return self.format_power(self.dut_state.attenuation_db)

        value = self.parse_numeric_value(command, r'ATTEN(?:UATION)?\s+(\S+)')
        if value is not None:
            self.dut_state.attenuation_db = value
            logger.info(f"Attenuation set to {value} dB")

        return ''

    def _handle_temperature(self, command: str, is_query: bool) -> str:
        """Handle temperature query"""
        if is_query:
            # Simulate temperature with small variation
            import random
            temp = self.dut_state.temperature_c + random.uniform(-0.5, 0.5)
            return f"{temp:.1f}"
        return ''

    def _handle_input_power(self, command: str, is_query: bool) -> str:
        """Handle input power query"""
        if is_query:
            return self.format_power(self.dut_state.input_power_dbm)
        return ''

    def _handle_output_power(self, command: str, is_query: bool) -> str:
        """Handle output power query"""
        if is_query:
            # Calculate output based on mode
            if self.dut_state.processing_mode == 'LINEAR':
                output = self.dut_state.input_power_dbm - self.dut_state.attenuation_db
            elif self.dut_state.processing_mode == 'AMPLIFY':
                output = self.dut_state.input_power_dbm + self.dut_state.gain_db - self.dut_state.attenuation_db
            else:  # BYPASS
                output = self.dut_state.input_power_dbm

            self.dut_state.output_power_dbm = output
            return self.format_power(output)
        return ''

    def _handle_output(self, command: str, is_query: bool) -> str:
        """Handle output enable/disable"""
        if is_query:
            return self.format_boolean(self.dut_state.output_enabled)

        cmd_upper = command.upper()

        if any(x in cmd_upper for x in ['ON', '1']):
            self.dut_state.output_enabled = True
            logger.info("Output enabled")
        elif any(x in cmd_upper for x in ['OFF', '0']):
            self.dut_state.output_enabled = False
            logger.info("Output disabled")

        return ''

    def process_signal(self, input_power_dbm: float) -> float:
        """
        Process input signal through DUT

        Args:
            input_power_dbm: Input signal power

        Returns:
            Output signal power
        """
        self.dut_state.input_power_dbm = input_power_dbm

        if not self.dut_state.output_enabled:
            self.dut_state.output_power_dbm = -200.0  # Off
            return self.dut_state.output_power_dbm

        # Apply processing based on mode
        if self.dut_state.processing_mode == 'LINEAR':
            output = input_power_dbm - self.dut_state.attenuation_db
        elif self.dut_state.processing_mode == 'AMPLIFY':
            output = input_power_dbm + self.dut_state.gain_db - self.dut_state.attenuation_db
        else:  # BYPASS
            output = input_power_dbm

        self.dut_state.output_power_dbm = output
        return output
