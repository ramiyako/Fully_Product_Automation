"""
Mock Spectrum Analyzer

Simulates an RF spectrum analyzer with SCPI interface and RF physics.
Supports frequency sweeps with realistic spectrum including harmonics and noise.
"""

from typing import Optional, List
import logging
import numpy as np

from .base_equipment import BaseEquipment
from ..state_manager import SpectrumAnalyzerState
from ..rf_physics import RFPhysicsEngine, SignalSource, RFPathParameters

logger = logging.getLogger(__name__)


class SpectrumAnalyzer(BaseEquipment):
    """
    Mock RF Spectrum Analyzer

    Implements SCPI commands for spectrum analysis with high-fidelity
    RF physics simulation including harmonics, noise, and intermodulation.
    """

    def __init__(self, config: Optional[dict] = None):
        """Initialize spectrum analyzer"""
        super().__init__('spectrum_analyzer', config)

        # Initialize RF physics engine
        self.rf_engine = RFPhysicsEngine(config)

        # Signal sources (to be set externally or via simulation)
        self.signal_sources: List[SignalSource] = []

        logger.info("Spectrum Analyzer initialized with RF physics")

    @property
    def sa_state(self) -> SpectrumAnalyzerState:
        """Get spectrum analyzer state"""
        return self.state

    def handle_command(self, command: str, is_query: bool) -> str:
        """
        Handle spectrum analyzer specific SCPI commands

        Args:
            command: SCPI command
            is_query: True if query

        Returns:
            Response string
        """
        cmd_upper = command.upper().replace(' ', '')

        # Frequency commands
        if 'FREQ:CENT' in cmd_upper or 'FREQUENCY:CENTER' in cmd_upper:
            return self._handle_center_frequency(command, is_query)
        elif 'FREQ:SPAN' in cmd_upper or 'FREQUENCY:SPAN' in cmd_upper:
            return self._handle_span(command, is_query)
        elif 'FREQ:START' in cmd_upper or 'FREQUENCY:START' in cmd_upper:
            return self._handle_start_frequency(command, is_query)
        elif 'FREQ:STOP' in cmd_upper or 'FREQUENCY:STOP' in cmd_upper:
            return self._handle_stop_frequency(command, is_query)

        # Amplitude commands
        elif 'DISP:WIND:TRAC:Y:RLEV' in cmd_upper or 'AMPLITUDE:REFERENCE' in cmd_upper:
            return self._handle_reference_level(command, is_query)
        elif 'INP:ATT' in cmd_upper or 'ATTENUATION' in cmd_upper:
            return self._handle_attenuation(command, is_query)

        # Bandwidth commands
        elif 'BAND:RES' in cmd_upper or 'RBW' in cmd_upper:
            return self._handle_rbw(command, is_query)
        elif 'BAND:VID' in cmd_upper or 'VBW' in cmd_upper:
            return self._handle_vbw(command, is_query)

        # Sweep commands
        elif 'SWE:POIN' in cmd_upper or 'SWEEP:POINTS' in cmd_upper:
            return self._handle_sweep_points(command, is_query)
        elif 'SWE:TIME' in cmd_upper or 'SWEEP:TIME' in cmd_upper:
            return self._handle_sweep_time(command, is_query)

        # Trace commands
        elif 'TRAC' in cmd_upper and 'DATA' in cmd_upper:
            return self._handle_trace_data(command, is_query)
        elif 'INIT:IMM' in cmd_upper or 'INITIATE:IMMEDIATE' in cmd_upper:
            return self._handle_initiate(command, is_query)

        # Marker commands
        elif 'CALC:MARK' in cmd_upper or 'MARKER' in cmd_upper:
            return self._handle_marker(command, is_query)

        else:
            logger.warning(f"Unknown command: {command}")
            return ''

    def _handle_center_frequency(self, command: str, is_query: bool) -> str:
        """Handle center frequency"""
        if is_query:
            return self.format_frequency(self.sa_state.center_frequency_hz)

        value = self.parse_numeric_value(command, r'(?:FREQ(?:UENCY)?:CENT(?:ER)?)\s+(\S+)')
        if value is not None:
            if value < 1000:
                value = value * 1e9  # GHz
            elif value < 1e6:
                value = value * 1e6  # MHz

            self.sa_state.center_frequency_hz = value
            self._update_start_stop()
            logger.info(f"Center frequency set to {value/1e9:.3f} GHz")

        return ''

    def _handle_span(self, command: str, is_query: bool) -> str:
        """Handle span"""
        if is_query:
            return self.format_frequency(self.sa_state.span_hz)

        value = self.parse_numeric_value(command, r'(?:FREQ(?:UENCY)?:SPAN)\s+(\S+)')
        if value is not None:
            if value < 1000:
                value = value * 1e9  # GHz
            elif value < 1e6:
                value = value * 1e6  # MHz

            self.sa_state.span_hz = value
            self._update_start_stop()
            logger.info(f"Span set to {value/1e6:.1f} MHz")

        return ''

    def _handle_start_frequency(self, command: str, is_query: bool) -> str:
        """Handle start frequency"""
        if is_query:
            return self.format_frequency(self.sa_state.start_frequency_hz)

        value = self.parse_numeric_value(command, r'(?:FREQ(?:UENCY)?:START)\s+(\S+)')
        if value is not None:
            if value < 1000:
                value = value * 1e9
            elif value < 1e6:
                value = value * 1e6

            self.sa_state.start_frequency_hz = value
            self._update_center_span()
            logger.info(f"Start frequency set to {value/1e9:.3f} GHz")

        return ''

    def _handle_stop_frequency(self, command: str, is_query: bool) -> str:
        """Handle stop frequency"""
        if is_query:
            return self.format_frequency(self.sa_state.stop_frequency_hz)

        value = self.parse_numeric_value(command, r'(?:FREQ(?:UENCY)?:STOP)\s+(\S+)')
        if value is not None:
            if value < 1000:
                value = value * 1e9
            elif value < 1e6:
                value = value * 1e6

            self.sa_state.stop_frequency_hz = value
            self._update_center_span()
            logger.info(f"Stop frequency set to {value/1e9:.3f} GHz")

        return ''

    def _update_start_stop(self):
        """Update start/stop from center/span"""
        self.sa_state.start_frequency_hz = self.sa_state.center_frequency_hz - self.sa_state.span_hz / 2
        self.sa_state.stop_frequency_hz = self.sa_state.center_frequency_hz + self.sa_state.span_hz / 2

    def _update_center_span(self):
        """Update center/span from start/stop"""
        self.sa_state.center_frequency_hz = (self.sa_state.start_frequency_hz + self.sa_state.stop_frequency_hz) / 2
        self.sa_state.span_hz = self.sa_state.stop_frequency_hz - self.sa_state.start_frequency_hz

    def _handle_reference_level(self, command: str, is_query: bool) -> str:
        """Handle reference level"""
        if is_query:
            return self.format_power(self.sa_state.reference_level_dbm)

        value = self.parse_numeric_value(command, r'(?:RLEV|REFERENCE)\s+(\S+)')
        if value is not None:
            self.sa_state.reference_level_dbm = value
            logger.info(f"Reference level set to {value} dBm")

        return ''

    def _handle_attenuation(self, command: str, is_query: bool) -> str:
        """Handle input attenuation"""
        if is_query:
            return self.format_power(self.sa_state.attenuation_db)

        value = self.parse_numeric_value(command, r'(?:ATT(?:ENUATION)?)\s+(\S+)')
        if value is not None:
            self.sa_state.attenuation_db = value
            logger.info(f"Attenuation set to {value} dB")

        return ''

    def _handle_rbw(self, command: str, is_query: bool) -> str:
        """Handle resolution bandwidth"""
        if is_query:
            return self.format_frequency(self.sa_state.rbw_hz)

        value = self.parse_numeric_value(command, r'(?:RBW|RES(?:OLUTION)?)\s+(\S+)')
        if value is not None:
            if value < 1e3:
                value = value * 1e3  # kHz
            self.sa_state.rbw_hz = value
            logger.info(f"RBW set to {value} Hz")

        return ''

    def _handle_vbw(self, command: str, is_query: bool) -> str:
        """Handle video bandwidth"""
        if is_query:
            return self.format_frequency(self.sa_state.vbw_hz)

        value = self.parse_numeric_value(command, r'(?:VBW|VID(?:EO)?)\s+(\S+)')
        if value is not None:
            if value < 1e3:
                value = value * 1e3  # kHz
            self.sa_state.vbw_hz = value
            logger.info(f"VBW set to {value} Hz")

        return ''

    def _handle_sweep_points(self, command: str, is_query: bool) -> str:
        """Handle sweep points"""
        if is_query:
            return str(self.sa_state.sweep_points)

        value = self.parse_numeric_value(command, r'(?:POIN(?:TS)?)\s+(\S+)')
        if value is not None:
            self.sa_state.sweep_points = int(value)
            logger.info(f"Sweep points set to {int(value)}")

        return ''

    def _handle_sweep_time(self, command: str, is_query: bool) -> str:
        """Handle sweep time"""
        if is_query:
            return f"{self.sa_state.sweep_time_s:.3f}"

        value = self.parse_numeric_value(command, r'(?:TIME)\s+(\S+)')
        if value is not None:
            self.sa_state.sweep_time_s = value
            logger.info(f"Sweep time set to {value} s")

        return ''

    def _handle_initiate(self, command: str, is_query: bool) -> str:
        """Handle sweep initiation"""
        logger.info("Initiating sweep")
        self._perform_sweep()
        return ''

    def _handle_trace_data(self, command: str, is_query: bool) -> str:
        """Handle trace data query"""
        if not is_query:
            return ''

        if self.sa_state.last_sweep_data is None:
            # Perform sweep if not done
            self._perform_sweep()

        # Return trace data as comma-separated values
        trace_str = ','.join([f"{val:.2f}" for val in self.sa_state.last_sweep_data])
        return trace_str

    def _handle_marker(self, command: str, is_query: bool) -> str:
        """Handle marker commands"""
        cmd_upper = command.upper()

        if 'X' in cmd_upper and not is_query:
            # Set marker frequency
            value = self.parse_numeric_value(command, r'(?:MARK(?:ER)?.*?X)\s+(\S+)')
            if value is not None:
                if value < 1000:
                    value = value * 1e9
                elif value < 1e6:
                    value = value * 1e6
                self.sa_state.marker_frequency_hz = value
                self.sa_state.marker_enabled = True
                logger.info(f"Marker set to {value/1e9:.3f} GHz")

        elif 'Y' in cmd_upper and is_query:
            # Return marker power
            if self.sa_state.last_sweep_data is None:
                self._perform_sweep()
            return self._get_marker_power()

        return ''

    def _get_marker_power(self) -> str:
        """Get power at marker frequency"""
        if self.sa_state.last_sweep_data is None or not self.sa_state.marker_enabled:
            return "-100.0"

        # Find closest frequency point
        frequencies = np.linspace(
            self.sa_state.start_frequency_hz,
            self.sa_state.stop_frequency_hz,
            self.sa_state.sweep_points
        )
        idx = np.argmin(np.abs(frequencies - self.sa_state.marker_frequency_hz))
        power = self.sa_state.last_sweep_data[idx]

        return self.format_power(power)

    def _perform_sweep(self):
        """Perform spectrum sweep with RF physics simulation"""
        logger.info("Performing spectrum sweep")

        # Create frequency points
        frequencies = np.linspace(
            self.sa_state.start_frequency_hz,
            self.sa_state.stop_frequency_hz,
            self.sa_state.sweep_points
        )

        # Calculate spectrum using RF physics
        if self.signal_sources:
            # Use actual signal sources
            spectrum = self.rf_engine.calculate_spectrum(
                self.signal_sources,
                frequencies,
                self.sa_state.rbw_hz
            )
        else:
            # Just noise floor
            spectrum = self.rf_engine.generate_noise(
                frequencies,
                self.sa_state.rbw_hz,
                10.0  # Default noise figure
            )

        # Apply attenuation
        spectrum = spectrum - self.sa_state.attenuation_db

        # Store sweep data
        self.sa_state.last_sweep_data = spectrum.tolist()
        from datetime import datetime
        self.sa_state.last_sweep_time = datetime.now()

        logger.info(f"Sweep completed: {len(self.sa_state.last_sweep_data)} points")

    def set_signal_sources(self, sources: List[SignalSource]):
        """
        Set external signal sources for spectrum simulation

        Args:
            sources: List of SignalSource objects
        """
        self.signal_sources = sources
        logger.info(f"Signal sources updated: {len(sources)} sources")
