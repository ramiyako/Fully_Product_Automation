"""
Environment Configuration

Centralized configuration management for integration and production environments.
Supports environment variables and .env files.
"""

import os
from typing import Dict, Optional
from dataclasses import dataclass
import logging

logger = logging.getLogger(__name__)


@dataclass
class EquipmentEndpoint:
    """Equipment network endpoint configuration"""
    host: str
    port: int

    @property
    def address(self) -> str:
        """Get full address"""
        return f"{self.host}:{self.port}"


@dataclass
class EnvironmentConfig:
    """Environment configuration"""
    # Environment mode
    use_mock_equipment: bool

    # Equipment endpoints
    spectrum_analyzer: EquipmentEndpoint
    signal_generator: EquipmentEndpoint
    dut: EquipmentEndpoint

    # RF Physics simulation parameters (for mock mode)
    enable_harmonics: bool = True
    harmonic_order: int = 3
    noise_floor_dbm: float = -120.0
    enable_intermod: bool = True

    # Elasticsearch configuration
    elasticsearch_host: str = "localhost"
    elasticsearch_port: int = 9200

    # Test configuration
    test_timeout_seconds: int = 300

    @property
    def is_mock(self) -> bool:
        """Check if using mock equipment"""
        return self.use_mock_equipment


def load_env_file(env_file: str) -> Dict[str, str]:
    """
    Load environment variables from .env file

    Args:
        env_file: Path to .env file

    Returns:
        Dictionary of environment variables
    """
    env_vars = {}

    if not os.path.exists(env_file):
        logger.warning(f"Environment file not found: {env_file}")
        return env_vars

    try:
        with open(env_file, 'r') as f:
            for line in f:
                line = line.strip()
                # Skip comments and empty lines
                if not line or line.startswith('#'):
                    continue

                # Parse KEY=VALUE
                if '=' in line:
                    key, value = line.split('=', 1)
                    env_vars[key.strip()] = value.strip()

        logger.info(f"Loaded {len(env_vars)} variables from {env_file}")
    except Exception as e:
        logger.error(f"Error loading env file {env_file}: {e}")

    return env_vars


def get_environment_config(config_file: Optional[str] = None) -> EnvironmentConfig:
    """
    Get environment configuration

    Priority:
    1. Environment variables
    2. Config file (if specified)
    3. Default values

    Args:
        config_file: Optional path to .env config file

    Returns:
        EnvironmentConfig object
    """
    # Load from config file if specified
    file_vars = {}
    if config_file and os.path.exists(config_file):
        file_vars = load_env_file(config_file)

    def get_var(key: str, default: str = "") -> str:
        """Get variable with priority: ENV > file > default"""
        return os.getenv(key, file_vars.get(key, default))

    def get_bool(key: str, default: bool = False) -> bool:
        """Get boolean variable"""
        value = get_var(key, str(default)).lower()
        return value in ['true', '1', 'yes', 'on']

    def get_int(key: str, default: int = 0) -> int:
        """Get integer variable"""
        try:
            return int(get_var(key, str(default)))
        except ValueError:
            return default

    def get_float(key: str, default: float = 0.0) -> float:
        """Get float variable"""
        try:
            return float(get_var(key, str(default)))
        except ValueError:
            return default

    # Determine if using mock equipment
    use_mock = get_bool('USE_MOCK_EQUIPMENT', False)

    # Equipment endpoints
    if use_mock:
        # Mock equipment on localhost
        sa_host = get_var('MOCK_SPECTRUM_ANALYZER_IP', '127.0.0.1')
        sa_port = get_int('MOCK_SPECTRUM_ANALYZER_PORT', 5001)

        sg_host = get_var('MOCK_SIGNAL_GENERATOR_IP', '127.0.0.1')
        sg_port = get_int('MOCK_SIGNAL_GENERATOR_PORT', 5002)

        dut_host = get_var('MOCK_DUT_IP', '127.0.0.1')
        dut_port = get_int('MOCK_DUT_PORT', 5003)
    else:
        # Real equipment on Lab VLAN
        sa_host = get_var('SPECTRUM_ANALYZER_IP', '192.168.50.10')
        sa_port = get_int('SPECTRUM_ANALYZER_PORT', 5025)

        sg_host = get_var('SIGNAL_GENERATOR_IP', '192.168.50.20')
        sg_port = get_int('SIGNAL_GENERATOR_PORT', 5025)

        dut_host = get_var('DUT_IP', '192.168.50.30')
        dut_port = get_int('DUT_PORT', 5025)

    config = EnvironmentConfig(
        use_mock_equipment=use_mock,

        spectrum_analyzer=EquipmentEndpoint(host=sa_host, port=sa_port),
        signal_generator=EquipmentEndpoint(host=sg_host, port=sg_port),
        dut=EquipmentEndpoint(host=dut_host, port=dut_port),

        enable_harmonics=get_bool('MOCK_ENABLE_HARMONICS', True),
        harmonic_order=get_int('MOCK_HARMONIC_ORDER', 3),
        noise_floor_dbm=get_float('MOCK_NOISE_FLOOR_DBM', -120.0),
        enable_intermod=get_bool('MOCK_ENABLE_INTERMOD', True),

        elasticsearch_host=get_var('ELASTICSEARCH_HOST', 'localhost'),
        elasticsearch_port=get_int('ELASTICSEARCH_PORT', 9200),

        test_timeout_seconds=get_int('TEST_TIMEOUT_SECONDS', 300)
    )

    logger.info(f"Environment configuration loaded: mock={use_mock}")
    logger.info(f"  Spectrum Analyzer: {config.spectrum_analyzer.address}")
    logger.info(f"  Signal Generator: {config.signal_generator.address}")
    logger.info(f"  DUT: {config.dut.address}")

    return config


# Global configuration instance
_config: Optional[EnvironmentConfig] = None


def get_config(reload: bool = False, config_file: Optional[str] = None) -> EnvironmentConfig:
    """
    Get global configuration instance

    Args:
        reload: Force reload configuration
        config_file: Optional config file path

    Returns:
        EnvironmentConfig instance
    """
    global _config

    if _config is None or reload:
        # Try to find config file in standard locations
        if config_file is None:
            for path in [
                'config/integration.env',
                '/etc/rf-automation/integration.env',
                os.path.expanduser('~/.rf-automation/integration.env')
            ]:
                if os.path.exists(path):
                    config_file = path
                    logger.info(f"Found config file: {config_file}")
                    break

        _config = get_environment_config(config_file)

    return _config
