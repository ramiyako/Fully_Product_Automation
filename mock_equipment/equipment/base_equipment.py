"""
Base Equipment Class

Provides common SCPI command handling and equipment functionality
for all mock RF equipment types.
"""

from typing import Dict, Optional, Tuple
from abc import ABC, abstractmethod
import logging
import re
import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from state_manager import StateManager

logger = logging.getLogger(__name__)


class BaseEquipment(ABC):
    """
    Base class for all mock RF equipment

    Implements common SCPI commands and provides framework
    for equipment-specific commands.
    """

    def __init__(self, equipment_type: str, config: Optional[Dict] = None):
        """
        Initialize base equipment

        Args:
            equipment_type: Type of equipment
            config: Optional configuration
        """
        self.equipment_type = equipment_type
        self.config = config or {}
        self.state_manager = StateManager(equipment_type, config)

        logger.info(f"Base equipment initialized: {equipment_type}")

    @property
    def state(self):
        """Get equipment state"""
        return self.state_manager.state

    def process_command(self, command: str) -> str:
        """
        Process SCPI command and return response

        Args:
            command: SCPI command string

        Returns:
            Response string (empty for commands, data for queries)
        """
        # Add to command history
        self.state.add_command(command)

        # Clean up command
        command = command.strip()

        # Check if query (ends with ?)
        is_query = command.endswith('?')

        # Remove whitespace and convert to uppercase for matching
        cmd_normalized = command.upper().replace(' ', '')

        logger.debug(f"Processing command: {command} (query={is_query})")

        try:
            # Common IEEE 488.2 commands
            if cmd_normalized == '*IDN?':
                return self._idn()
            elif cmd_normalized == '*RST':
                return self._rst()
            elif cmd_normalized == '*CLS':
                return self._cls()
            elif cmd_normalized == '*OPC?':
                return '1'
            elif cmd_normalized == '*OPC':
                return ''
            elif cmd_normalized == '*ESR?':
                return '0'
            elif cmd_normalized == '*STB?':
                return '0'
            elif cmd_normalized.startswith('SYST:ERR?') or cmd_normalized == 'SYSTEM:ERROR?':
                return self._get_error()

            # Delegate to equipment-specific handler
            response = self.handle_command(command, is_query)

            # Clear any error if command succeeded
            if self.state.error_state:
                self.state_manager.clear_error()

            return response

        except Exception as e:
            error_msg = f"Command error: {str(e)}"
            logger.error(error_msg)
            self.state_manager.set_error(error_msg)
            return ''

    @abstractmethod
    def handle_command(self, command: str, is_query: bool) -> str:
        """
        Handle equipment-specific SCPI command

        Args:
            command: SCPI command string
            is_query: True if command is a query

        Returns:
            Response string

        Must be implemented by subclasses
        """
        pass

    def _idn(self) -> str:
        """Handle *IDN? query"""
        return f"{self.state.manufacturer},{self.state.model},{self.state.serial_number},{self.state.firmware_version}"

    def _rst(self) -> str:
        """Handle *RST command"""
        self.state_manager.reset()
        return ''

    def _cls(self) -> str:
        """Handle *CLS command"""
        self.state_manager.clear_error()
        return ''

    def _get_error(self) -> str:
        """Handle SYST:ERR? query"""
        if self.state.error_state:
            error = f'-1,"{self.state.error_message}"'
            self.state_manager.clear_error()
            return error
        return '0,"No error"'

    def parse_numeric_value(self, command: str, pattern: str) -> Optional[float]:
        """
        Parse numeric value from SCPI command

        Args:
            command: SCPI command string
            pattern: Regex pattern to extract value

        Returns:
            Parsed float value or None
        """
        match = re.search(pattern, command, re.IGNORECASE)
        if match:
            value_str = match.group(1)
            # Handle units (MHz, GHz, dBm, etc.)
            value_str = value_str.upper().replace('HZ', '').replace('MHZ', 'e6').replace('GHZ', 'e9')
            value_str = value_str.replace('KHZ', 'e3').replace('DBM', '').replace('DB', '')
            try:
                return float(eval(value_str))  # eval to handle scientific notation
            except:
                return None
        return None

    def format_frequency(self, freq_hz: float) -> str:
        """Format frequency for response"""
        return f"{freq_hz:.0f}"

    def format_power(self, power_dbm: float) -> str:
        """Format power for response"""
        return f"{power_dbm:.2f}"

    def format_boolean(self, value: bool) -> str:
        """Format boolean for response"""
        return '1' if value else '0'

    def parse_boolean(self, value: str) -> bool:
        """Parse boolean from command"""
        value = value.upper().strip()
        return value in ['1', 'ON', 'TRUE', 'YES']
