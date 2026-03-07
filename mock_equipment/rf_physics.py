"""
RF Physics Simulation Engine

High-fidelity RF signal simulation including:
- Harmonics (2nd, 3rd, and higher order)
- Intermodulation products (IM3, IM5)
- Noise floor modeling
- Frequency response
- Path loss and attenuation
- Dynamic range and compression
"""

import numpy as np
from typing import Dict, List, Tuple, Optional
from dataclasses import dataclass
import logging

logger = logging.getLogger(__name__)


@dataclass
class SignalSource:
    """Represents a single RF signal source"""
    frequency_hz: float
    power_dbm: float
    phase_deg: float = 0.0
    enabled: bool = True


@dataclass
class RFPathParameters:
    """RF signal path characteristics"""
    cable_loss_db: float = 1.0  # Cable insertion loss
    connector_loss_db: float = 0.5  # Connector loss
    gain_db: float = 0.0  # Amplifier gain (if any)
    noise_figure_db: float = 10.0  # Noise figure
    p1db_compression_dbm: float = 10.0  # 1dB compression point
    ip3_dbm: float = 20.0  # Third-order intercept point


class RFPhysicsEngine:
    """
    RF Physics Simulation Engine

    Provides realistic RF signal behavior including harmonics,
    intermodulation, noise, and frequency response.
    """

    def __init__(self, config: Optional[Dict] = None):
        """
        Initialize RF physics engine

        Args:
            config: Configuration dictionary with simulation parameters
        """
        self.config = config or {}

        # Noise floor parameters
        self.thermal_noise_dbm_hz = -174.0  # Thermal noise density

        # Harmonic parameters
        self.enable_harmonics = self.config.get('enable_harmonics', True)
        self.harmonic_order = self.config.get('harmonic_order', 3)
        self.harmonic_levels_dbc = self.config.get('harmonic_levels_dbc', [-30, -40, -50])  # 2nd, 3rd, 4th

        # Intermodulation parameters
        self.enable_intermod = self.config.get('enable_intermod', True)

        # Frequency response parameters
        self.enable_freq_response = self.config.get('enable_freq_response', True)

        logger.info(f"RF Physics Engine initialized: harmonics={self.enable_harmonics}, "
                   f"order={self.harmonic_order}, intermod={self.enable_intermod}")

    def calculate_noise_floor(self,
                              rbw_hz: float,
                              noise_figure_db: float = 10.0) -> float:
        """
        Calculate noise floor in dBm

        Args:
            rbw_hz: Resolution bandwidth in Hz
            noise_figure_db: Noise figure of the system

        Returns:
            Noise floor in dBm
        """
        # Noise floor = -174 dBm/Hz + 10*log10(RBW) + NF
        noise_floor_dbm = self.thermal_noise_dbm_hz + 10 * np.log10(rbw_hz) + noise_figure_db
        return noise_floor_dbm

    def generate_noise(self,
                       frequency_points: np.ndarray,
                       rbw_hz: float,
                       noise_figure_db: float = 10.0) -> np.ndarray:
        """
        Generate realistic noise spectrum

        Args:
            frequency_points: Frequency points in Hz
            rbw_hz: Resolution bandwidth
            noise_figure_db: Noise figure

        Returns:
            Noise power array in dBm
        """
        noise_floor = self.calculate_noise_floor(rbw_hz, noise_figure_db)

        # Add random variation to make it realistic (±1 dB)
        noise_variation = np.random.normal(0, 0.5, len(frequency_points))
        noise_spectrum = noise_floor + noise_variation

        return noise_spectrum

    def calculate_harmonics(self,
                           fundamental_freq_hz: float,
                           fundamental_power_dbm: float,
                           frequency_points: np.ndarray) -> np.ndarray:
        """
        Calculate harmonic components

        Args:
            fundamental_freq_hz: Fundamental frequency in Hz
            fundamental_power_dbm: Fundamental power in dBm
            frequency_points: Frequency points to calculate spectrum at

        Returns:
            Harmonic spectrum in dBm
        """
        if not self.enable_harmonics:
            return np.full_like(frequency_points, -200.0, dtype=float)

        spectrum = np.full_like(frequency_points, -200.0, dtype=float)

        # Calculate harmonics up to specified order
        for order in range(2, self.harmonic_order + 1):
            harmonic_freq = fundamental_freq_hz * order

            # Get harmonic level (default based on order)
            if order - 2 < len(self.harmonic_levels_dbc):
                harmonic_level_dbc = self.harmonic_levels_dbc[order - 2]
            else:
                # Extrapolate for higher orders
                harmonic_level_dbc = self.harmonic_levels_dbc[-1] - (order - len(self.harmonic_levels_dbc)) * 10

            harmonic_power_dbm = fundamental_power_dbm + harmonic_level_dbc

            # Find closest frequency point
            idx = np.argmin(np.abs(frequency_points - harmonic_freq))

            # Add harmonic with some bandwidth spreading (realistic spectral shape)
            span = max(1, len(frequency_points) // 200)
            for i in range(max(0, idx - span), min(len(frequency_points), idx + span + 1)):
                offset = abs(i - idx)
                # Gaussian-like rolloff
                power_offset = -0.5 * offset if offset > 0 else 0
                spectrum[i] = max(spectrum[i], harmonic_power_dbm + power_offset)

        return spectrum

    def calculate_intermodulation(self,
                                  signals: List[SignalSource],
                                  frequency_points: np.ndarray,
                                  ip3_dbm: float = 20.0) -> np.ndarray:
        """
        Calculate intermodulation products for multi-tone signals

        Args:
            signals: List of signal sources
            frequency_points: Frequency points in Hz
            ip3_dbm: Third-order intercept point in dBm

        Returns:
            Intermodulation spectrum in dBm
        """
        if not self.enable_intermod or len(signals) < 2:
            return np.full_like(frequency_points, -200.0, dtype=float)

        spectrum = np.full_like(frequency_points, -200.0, dtype=float)

        # Calculate IM3 products for all pairs of signals
        for i, sig1 in enumerate(signals):
            if not sig1.enabled:
                continue

            for sig2 in signals[i+1:]:
                if not sig2.enabled:
                    continue

                # Average power of two tones
                p_avg = (sig1.power_dbm + sig2.power_dbm) / 2

                # IM3 product level using intercept point formula
                # IM3 = 2*P - IP3 (simplified)
                im3_power_dbm = 2 * p_avg - ip3_dbm

                # IM3 frequencies: 2*f1 - f2 and 2*f2 - f1
                im3_freq_1 = 2 * sig1.frequency_hz - sig2.frequency_hz
                im3_freq_2 = 2 * sig2.frequency_hz - sig1.frequency_hz

                for im3_freq in [im3_freq_1, im3_freq_2]:
                    if im3_freq > 0:  # Only positive frequencies
                        idx = np.argmin(np.abs(frequency_points - im3_freq))
                        if 0 <= idx < len(frequency_points):
                            spectrum[idx] = max(spectrum[idx], im3_power_dbm)

        return spectrum

    def apply_path_loss(self,
                       signal_power_dbm: float,
                       path_params: RFPathParameters) -> float:
        """
        Apply path loss and gain through RF signal path

        Args:
            signal_power_dbm: Input signal power
            path_params: RF path parameters

        Returns:
            Output signal power in dBm
        """
        output_power = signal_power_dbm
        output_power -= path_params.cable_loss_db
        output_power -= path_params.connector_loss_db
        output_power += path_params.gain_db

        # Check for compression
        if output_power > path_params.p1db_compression_dbm:
            # Apply compression (simple model)
            excess = output_power - path_params.p1db_compression_dbm
            output_power = path_params.p1db_compression_dbm + excess / 3  # Soft compression

        return output_power

    def calculate_frequency_response(self,
                                    center_freq_hz: float,
                                    frequency_points: np.ndarray,
                                    bandwidth_3db_hz: Optional[float] = None) -> np.ndarray:
        """
        Calculate frequency response (filter shape)

        Args:
            center_freq_hz: Center frequency
            frequency_points: Frequency points
            bandwidth_3db_hz: 3dB bandwidth (None for flat response)

        Returns:
            Frequency response in dB
        """
        if not self.enable_freq_response or bandwidth_3db_hz is None:
            return np.zeros_like(frequency_points)

        # Gaussian filter response
        freq_offset = frequency_points - center_freq_hz
        sigma = bandwidth_3db_hz / (2 * np.sqrt(2 * np.log(2)))
        response_db = -10 * np.log10(1 + (freq_offset / sigma) ** 6)  # 6th order for steeper rolloff

        return response_db

    def calculate_spectrum(self,
                          signals: List[SignalSource],
                          frequency_points: np.ndarray,
                          rbw_hz: float = 1000.0,
                          path_params: Optional[RFPathParameters] = None,
                          bandwidth_3db_hz: Optional[float] = None) -> np.ndarray:
        """
        Calculate complete realistic spectrum including all effects

        Args:
            signals: List of signal sources
            frequency_points: Frequency points for spectrum
            rbw_hz: Resolution bandwidth
            path_params: RF path parameters (optional)
            bandwidth_3db_hz: Filter bandwidth (optional)

        Returns:
            Complete spectrum in dBm
        """
        if path_params is None:
            path_params = RFPathParameters()

        # Initialize spectrum with noise floor
        spectrum = self.generate_noise(frequency_points, rbw_hz, path_params.noise_figure_db)

        # Add fundamental signals
        for signal in signals:
            if not signal.enabled:
                continue

            # Apply path loss to signal
            signal_power = self.apply_path_loss(signal.power_dbm, path_params)

            # Add fundamental to spectrum
            idx = np.argmin(np.abs(frequency_points - signal.frequency_hz))
            spectrum[idx] = 10 * np.log10(
                10 ** (spectrum[idx] / 10) + 10 ** (signal_power / 10)
            )

            # Add harmonics
            harmonic_spectrum = self.calculate_harmonics(
                signal.frequency_hz,
                signal_power,
                frequency_points
            )

            # Combine with existing spectrum (power addition)
            spectrum = 10 * np.log10(
                10 ** (spectrum / 10) + 10 ** (harmonic_spectrum / 10)
            )

        # Add intermodulation products
        if len(signals) > 1:
            im_spectrum = self.calculate_intermodulation(
                signals,
                frequency_points,
                path_params.ip3_dbm
            )
            spectrum = 10 * np.log10(
                10 ** (spectrum / 10) + 10 ** (im_spectrum / 10)
            )

        # Apply frequency response
        if bandwidth_3db_hz is not None:
            for signal in signals:
                if signal.enabled:
                    freq_response = self.calculate_frequency_response(
                        signal.frequency_hz,
                        frequency_points,
                        bandwidth_3db_hz
                    )
                    spectrum += freq_response

        return spectrum

    def measure_power(self,
                     signal_power_dbm: float,
                     measurement_uncertainty_db: float = 0.5) -> float:
        """
        Simulate power measurement with realistic uncertainty

        Args:
            signal_power_dbm: Actual signal power
            measurement_uncertainty_db: Measurement uncertainty (std dev)

        Returns:
            Measured power with added uncertainty
        """
        measurement_error = np.random.normal(0, measurement_uncertainty_db)
        return signal_power_dbm + measurement_error
