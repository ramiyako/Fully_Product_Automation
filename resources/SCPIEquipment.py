"""
SCPI Equipment Communication Library

Robot Framework library for SCPI equipment communication.
Supports both real equipment (TCP/SCPI) and mock equipment.
"""

import socket
import time
import logging
from typing import Optional, Dict

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class SCPIEquipment:
    """
    SCPI Equipment Communication Library

    Provides keywords for Robot Framework to communicate with
    SCPI-compatible RF equipment.
    """

    ROBOT_LIBRARY_SCOPE = 'GLOBAL'

    def __init__(self):
        """Initialize SCPI library"""
        self.connections: Dict[str, socket.socket] = {}
        self.timeout = 30.0
        logger.info("SCPI Equipment Library initialized")

    def connect_to_equipment(self, equipment_name: str, host: str, port: int = 5025) -> None:
        """
        Connect to SCPI equipment via TCP

        Args:
            equipment_name: Name of equipment (for tracking)
            host: IP address or hostname
            port: TCP port (default 5025)

        Example:
            | Connect To Equipment | SpectrumAnalyzer | 192.168.50.10 | 5025 |
            | Connect To Equipment | SignalGenerator | 127.0.0.1 | 5002 |
        """
        if equipment_name in self.connections:
            logger.info(f"Already connected to {equipment_name}")
            return

        logger.info(f"Connecting to {equipment_name} at {host}:{port}")

        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(self.timeout)
            sock.connect((host, port))

            self.connections[equipment_name] = sock
            logger.info(f"Connected to {equipment_name}")

        except Exception as e:
            logger.error(f"Failed to connect to {equipment_name}: {e}")
            raise ConnectionError(f"Could not connect to {equipment_name} at {host}:{port}: {e}")

    def disconnect_from_equipment(self, equipment_name: str) -> None:
        """
        Disconnect from SCPI equipment

        Args:
            equipment_name: Name of equipment

        Example:
            | Disconnect From Equipment | SpectrumAnalyzer |
        """
        if equipment_name not in self.connections:
            logger.warning(f"Not connected to {equipment_name}")
            return

        try:
            self.connections[equipment_name].close()
            del self.connections[equipment_name]
            logger.info(f"Disconnected from {equipment_name}")
        except Exception as e:
            logger.error(f"Error disconnecting from {equipment_name}: {e}")

    def disconnect_all(self) -> None:
        """
        Disconnect from all equipment

        Example:
            | Disconnect All |
        """
        for equipment_name in list(self.connections.keys()):
            self.disconnect_from_equipment(equipment_name)

    def send_scpi_command(self, equipment_name: str, command: str) -> None:
        """
        Send SCPI command to equipment (no response expected)

        Args:
            equipment_name: Name of equipment
            command: SCPI command string

        Example:
            | Send SCPI Command | SpectrumAnalyzer | *RST |
            | Send SCPI Command | SignalGenerator | FREQ 1e9 |
        """
        if equipment_name not in self.connections:
            raise RuntimeError(f"Not connected to {equipment_name}")

        # Add terminator if not present
        if not command.endswith('\n'):
            command = command + '\n'

        logger.debug(f"Sending to {equipment_name}: {command.strip()}")

        try:
            self.connections[equipment_name].sendall(command.encode('utf-8'))
            time.sleep(0.1)  # Small delay for command processing
        except Exception as e:
            logger.error(f"Error sending command to {equipment_name}: {e}")
            raise RuntimeError(f"Failed to send command to {equipment_name}: {e}")

    def query_scpi(self, equipment_name: str, query: str) -> str:
        """
        Query SCPI equipment and return response

        Args:
            equipment_name: Name of equipment
            query: SCPI query string (must end with ?)

        Returns:
            Response string from equipment

        Example:
            | ${idn}= | Query SCPI | SpectrumAnalyzer | *IDN? |
            | ${freq}= | Query SCPI | SignalGenerator | FREQ? |
        """
        if equipment_name not in self.connections:
            raise RuntimeError(f"Not connected to {equipment_name}")

        # Add terminator if not present
        if not query.endswith('\n'):
            query = query + '\n'

        logger.debug(f"Querying {equipment_name}: {query.strip()}")

        try:
            # Send query
            self.connections[equipment_name].sendall(query.encode('utf-8'))

            # Receive response
            response = b''
            start_time = time.time()

            while True:
                if time.time() - start_time > self.timeout:
                    raise TimeoutError(f"Query timeout for {equipment_name}")

                try:
                    chunk = self.connections[equipment_name].recv(4096)
                    if not chunk:
                        break

                    response += chunk

                    # Check for newline terminator
                    if b'\n' in response:
                        break

                except socket.timeout:
                    if response:
                        break
                    raise

            result = response.decode('utf-8').strip()
            logger.debug(f"Response from {equipment_name}: {result}")

            return result

        except Exception as e:
            logger.error(f"Error querying {equipment_name}: {e}")
            raise RuntimeError(f"Failed to query {equipment_name}: {e}")

    def set_timeout(self, timeout_seconds: float) -> None:
        """
        Set communication timeout

        Args:
            timeout_seconds: Timeout in seconds

        Example:
            | Set Timeout | 60 |
        """
        self.timeout = float(timeout_seconds)
        logger.info(f"Timeout set to {timeout_seconds}s")

        # Update existing connections
        for sock in self.connections.values():
            sock.settimeout(self.timeout)

    def is_connected(self, equipment_name: str) -> bool:
        """
        Check if connected to equipment

        Args:
            equipment_name: Name of equipment

        Returns:
            True if connected, False otherwise

        Example:
            | ${connected}= | Is Connected | SpectrumAnalyzer |
            | Should Be True | ${connected} |
        """
        return equipment_name in self.connections


# For standalone testing
if __name__ == "__main__":
    # Test connection to mock equipment
    lib = SCPIEquipment()

    print("Testing SCPI Equipment Library")
    print("=" * 60)

    # Connect to mock equipment (assumes mock server running)
    try:
        lib.connect_to_equipment("TestEquipment", "127.0.0.1", 5001)

        # Query IDN
        idn = lib.query_scpi("TestEquipment", "*IDN?")
        print(f"IDN: {idn}")

        # Send reset
        lib.send_scpi_command("TestEquipment", "*RST")
        print("Reset sent")

        # Disconnect
        lib.disconnect_all()
        print("Disconnected")

    except Exception as e:
        print(f"Error: {e}")
