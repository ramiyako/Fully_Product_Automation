"""
Network and Equipment Configuration
RF Automation Infrastructure

This module contains all IP addresses and network configuration
for RF equipment in the laboratory VLAN.

IMPORTANT: Update IP addresses according to your lab setup.

INTEGRATION MODE: This module now supports both real and mock equipment.
Set USE_MOCK_EQUIPMENT=true in config/integration.env to use mock equipment.
"""

from typing import Dict, Tuple

# Try to import environment config (available in integration mode)
try:
    from .environment_config import get_config
    _env_config_available = True
except ImportError:
    _env_config_available = False

# ============================================================================
# Equipment IP Addresses (Lab VLAN: 192.168.50.0/24)
# ============================================================================

# Default equipment IPs (real equipment on Lab VLAN)
_DEFAULT_EQUIPMENT_LIST = {
    # Spectrum Analyzer
    "SpectrumAnalyzer": "192.168.50.10",

    # Signal Generator
    "SignalGenerator": "192.168.50.11",

    # Device Under Test (DUT)
    "DUT": "192.168.50.20",

    # Additional equipment (add as needed)
    # "PowerSupply": "192.168.50.15",
    # "VectorNetworkAnalyzer": "192.168.50.12",
    # "OscilloscopeRF": "192.168.50.13",
}

# Default equipment ports
_DEFAULT_EQUIPMENT_PORTS = {
    "SpectrumAnalyzer": 5025,
    "SignalGenerator": 5025,
    "DUT": 5025,
}


def get_equipment_config() -> Dict[str, Tuple[str, int]]:
    """
    Get equipment configuration (IP and port)

    Returns equipment IPs based on environment configuration:
    - If USE_MOCK_EQUIPMENT=true: Returns localhost:500X for mocks
    - Otherwise: Returns real equipment IPs from Lab VLAN

    Returns:
        Dictionary mapping equipment name to (ip, port) tuple
    """
    if _env_config_available:
        try:
            config = get_config()

            if config.use_mock_equipment:
                # Return mock equipment endpoints
                return {
                    "SpectrumAnalyzer": (config.spectrum_analyzer.host, config.spectrum_analyzer.port),
                    "SignalGenerator": (config.signal_generator.host, config.signal_generator.port),
                    "DUT": (config.dut.host, config.dut.port),
                }
        except Exception as e:
            # Fall through to default if config fails
            import logging
            logging.warning(f"Failed to load environment config: {e}")

    # Return default real equipment
    return {
        name: (ip, _DEFAULT_EQUIPMENT_PORTS.get(name, 5025))
        for name, ip in _DEFAULT_EQUIPMENT_LIST.items()
    }


# Maintain backward compatibility
EQUIPMENT_LIST = {
    name: ip
    for name, (ip, port) in get_equipment_config().items()
}

# ============================================================================
# Equipment Communication Settings
# ============================================================================

# Default timeout for equipment communication (seconds)
DEFAULT_TIMEOUT = 30

# Retry attempts for failed connections
MAX_RETRY_ATTEMPTS = 3

# Delay between retry attempts (seconds)
RETRY_DELAY = 2

# SCPI command termination character
SCPI_TERMINATION = "\n"

# ============================================================================
# Elasticsearch Configuration
# ============================================================================

# Elasticsearch endpoint
ELASTIC_ENDPOINT = "http://localhost:9200"

# Elasticsearch index for test results
ELASTIC_INDEX_PREFIX = "rf-automation"

# Elasticsearch username (if security enabled)
ELASTIC_USERNAME = None

# Elasticsearch password (if security enabled)
ELASTIC_PASSWORD = None

# ============================================================================
# Kibana Configuration
# ============================================================================

KIBANA_ENDPOINT = "http://localhost:5601"

# ============================================================================
# Network Settings
# ============================================================================

# Lab VLAN subnet
LAB_VLAN_SUBNET = "192.168.50.0/24"

# Lab VLAN gateway
LAB_VLAN_GATEWAY = "192.168.50.1"

# DNS servers
DNS_SERVERS = ["8.8.8.8", "8.8.4.4"]

# ============================================================================
# Jenkins Configuration
# ============================================================================

JENKINS_URL = "http://localhost:8080"

# ============================================================================
# Test Configuration
# ============================================================================

# Default test execution timeout (seconds)
TEST_TIMEOUT = 3600  # 1 hour

# Screenshot directory
SCREENSHOT_DIR = "results/screenshots"

# Log directory
LOG_DIR = "logs"

# Results directory
RESULTS_DIR = "results"

# ============================================================================
# RF Test Parameters (Example - adjust per your requirements)
# ============================================================================

RF_TEST_PARAMS = {
    "frequency_range": {
        "min": 100e6,      # 100 MHz
        "max": 6e9,        # 6 GHz
    },
    "power_levels": {
        "min": -100,       # dBm
        "max": 20,         # dBm
    },
    "sweep_points": 1001,
    "rbw": 1e6,           # 1 MHz Resolution Bandwidth
    "vbw": 1e6,           # 1 MHz Video Bandwidth
}

# ============================================================================
# Calibration Parameters
# ============================================================================

CALIBRATION_CONFIG = {
    "cal_frequency": 1e9,  # 1 GHz
    "cal_power": 0,        # 0 dBm
    "cal_interval_days": 30,
    "cal_tolerance": 0.5,  # dB
}

# ============================================================================
# Helper Functions
# ============================================================================

def get_equipment_ip(equipment_name: str) -> str:
    """
    Get IP address for specified equipment.

    Args:
        equipment_name: Name of the equipment

    Returns:
        IP address string

    Raises:
        KeyError: If equipment not found in configuration
    """
    if equipment_name not in EQUIPMENT_LIST:
        raise KeyError(f"Equipment '{equipment_name}' not found in configuration")
    return EQUIPMENT_LIST[equipment_name]


def get_equipment_endpoint(equipment_name: str) -> Tuple[str, int]:
    """
    Get IP address and port for specified equipment.

    Args:
        equipment_name: Name of the equipment

    Returns:
        Tuple of (ip_address, port)

    Raises:
        KeyError: If equipment not found in configuration
    """
    config = get_equipment_config()
    if equipment_name not in config:
        raise KeyError(f"Equipment '{equipment_name}' not found in configuration")
    return config[equipment_name]


def validate_ip_reachable(ip_address: str) -> bool:
    """
    Check if an IP address is reachable via ping.

    Args:
        ip_address: IP address to check

    Returns:
        True if reachable, False otherwise
    """
    import subprocess
    try:
        result = subprocess.run(
            ["ping", "-c", "1", "-W", "1", ip_address],
            capture_output=True,
            timeout=5
        )
        return result.returncode == 0
    except (subprocess.TimeoutExpired, Exception):
        return False


def get_elastic_index_name(test_suite: str = "general") -> str:
    """
    Generate Elasticsearch index name with date suffix.

    Args:
        test_suite: Name of the test suite

    Returns:
        Full index name with date
    """
    from datetime import datetime
    date_suffix = datetime.now().strftime("%Y.%m")
    return f"{ELASTIC_INDEX_PREFIX}-{test_suite}-{date_suffix}"


if __name__ == "__main__":
    # Validation script - run to verify configuration
    print("=" * 60)
    print("RF Automation - Network Configuration Validation")
    print("=" * 60)

    print("\nConfigured Equipment:")
    for name, ip in EQUIPMENT_LIST.items():
        reachable = validate_ip_reachable(ip)
        status = "✓ REACHABLE" if reachable else "✗ NOT REACHABLE"
        print(f"  {name:25} {ip:15} [{status}]")

    print(f"\nElasticsearch: {ELASTIC_ENDPOINT}")
    print(f"Kibana:        {KIBANA_ENDPOINT}")
    print(f"Jenkins:       {JENKINS_URL}")

    print("\n" + "=" * 60)
