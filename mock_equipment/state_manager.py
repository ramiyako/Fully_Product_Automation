"""
Equipment State Manager

Manages the internal state of mock RF equipment including
configuration, measurements, and operational status.
"""

from typing import Dict, Any, Optional
from dataclasses import dataclass, field
from datetime import datetime
import logging

logger = logging.getLogger(__name__)


@dataclass
class EquipmentState:
    """Base equipment state"""
    manufacturer: str = "Mock Instruments Inc."
    model: str = "MOCK-1000"
    serial_number: str = "MOCK-12345"
    firmware_version: str = "1.0.0"

    # Operational state
    output_enabled: bool = False
    error_state: bool = False
    error_message: str = ""

    # Timestamps
    last_command_time: Optional[datetime] = None
    power_on_time: datetime = field(default_factory=datetime.now)

    # Command history (last 100 commands)
    command_history: list = field(default_factory=list)

    def add_command(self, command: str):
        """Add command to history"""
        self.command_history.append({
            'command': command,
            'timestamp': datetime.now().isoformat()
        })
        # Keep only last 100 commands
        if len(self.command_history) > 100:
            self.command_history.pop(0)
        self.last_command_time = datetime.now()


@dataclass
class SignalGeneratorState(EquipmentState):
    """Signal Generator specific state"""
    model: str = "MOCK-SG-3000"

    # RF Output parameters
    frequency_hz: float = 1e9  # 1 GHz default
    power_dbm: float = -10.0
    power_offset_db: float = 0.0

    # Modulation
    modulation_enabled: bool = False
    modulation_type: str = "OFF"

    # Reference
    reference_source: str = "INT"  # INT or EXT
    reference_frequency_hz: float = 10e6


@dataclass
class SpectrumAnalyzerState(EquipmentState):
    """Spectrum Analyzer specific state"""
    model: str = "MOCK-SA-5000"

    # Frequency settings
    center_frequency_hz: float = 1e9
    span_hz: float = 100e6
    start_frequency_hz: float = 950e6
    stop_frequency_hz: float = 1050e6

    # Amplitude settings
    reference_level_dbm: float = 0.0
    attenuation_db: float = 10.0

    # Bandwidth settings
    rbw_hz: float = 1000.0
    vbw_hz: float = 1000.0

    # Sweep settings
    sweep_points: int = 401
    sweep_time_s: float = 0.1

    # Trace settings
    trace_mode: str = "WRIT"  # WRIT, AVER, MAXH, MINH
    detector_mode: str = "RMS"  # RMS, POS, NEG, SAM

    # Markers
    marker_enabled: bool = False
    marker_frequency_hz: float = 1e9

    # Last sweep data
    last_sweep_data: Optional[list] = None
    last_sweep_time: Optional[datetime] = None


@dataclass
class DUTState(EquipmentState):
    """Device Under Test specific state"""
    model: str = "MOCK-DUT-2000"

    # Signal processing mode
    processing_mode: str = "LINEAR"  # LINEAR, BYPASS, AMPLIFY

    # Path parameters
    gain_db: float = 0.0
    attenuation_db: float = 0.0

    # Status
    temperature_c: float = 25.0
    input_power_dbm: float = -100.0
    output_power_dbm: float = -100.0


class StateManager:
    """
    Manages equipment state with persistence and validation
    """

    def __init__(self, equipment_type: str, config: Optional[Dict[str, Any]] = None):
        """
        Initialize state manager

        Args:
            equipment_type: Type of equipment (spectrum_analyzer, signal_generator, dut)
            config: Optional configuration dictionary
        """
        self.equipment_type = equipment_type
        self.config = config or {}

        # Create appropriate state object
        if equipment_type == "signal_generator":
            self.state = SignalGeneratorState()
        elif equipment_type == "spectrum_analyzer":
            self.state = SpectrumAnalyzerState()
        elif equipment_type == "dut":
            self.state = DUTState()
        else:
            self.state = EquipmentState()

        # Apply configuration overrides
        self._apply_config()

        logger.info(f"State Manager initialized for {equipment_type}: {self.state.model}")

    def _apply_config(self):
        """Apply configuration to state"""
        for key, value in self.config.items():
            if hasattr(self.state, key):
                setattr(self.state, key, value)
                logger.debug(f"Applied config: {key} = {value}")

    def reset(self):
        """Reset equipment to default state"""
        logger.info(f"Resetting {self.equipment_type}")

        # Store original model info
        manufacturer = self.state.manufacturer
        model = self.state.model
        serial = self.state.serial_number
        firmware = self.state.firmware_version
        power_on = self.state.power_on_time

        # Create new state
        if self.equipment_type == "signal_generator":
            self.state = SignalGeneratorState()
        elif self.equipment_type == "spectrum_analyzer":
            self.state = SpectrumAnalyzerState()
        elif self.equipment_type == "dut":
            self.state = DUTState()
        else:
            self.state = EquipmentState()

        # Restore identity
        self.state.manufacturer = manufacturer
        self.state.model = model
        self.state.serial_number = serial
        self.state.firmware_version = firmware
        self.state.power_on_time = power_on

        # Reapply configuration
        self._apply_config()

    def get_state_dict(self) -> Dict[str, Any]:
        """Get state as dictionary"""
        state_dict = {}
        for key, value in self.state.__dict__.items():
            if isinstance(value, datetime):
                state_dict[key] = value.isoformat()
            elif isinstance(value, list) and key == 'command_history':
                # Only return last 10 commands for API
                state_dict[key] = value[-10:]
            else:
                state_dict[key] = value
        return state_dict

    def set_error(self, message: str):
        """Set error state"""
        self.state.error_state = True
        self.state.error_message = message
        logger.error(f"Equipment error: {message}")

    def clear_error(self):
        """Clear error state"""
        self.state.error_state = False
        self.state.error_message = ""
        logger.info("Error state cleared")
