# Mock RF Equipment Documentation

High-fidelity RF equipment simulation for testing without physical hardware.

## Overview

The mock equipment system provides realistic simulation of:
- **Spectrum Analyzer** - RF spectrum measurement with sweep capability
- **Signal Generator** - Configurable RF signal output
- **Device Under Test (DUT)** - Signal processing simulation

All mock equipment implements SCPI protocol over TCP/IP and includes high-fidelity RF physics simulation.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│              Mock Equipment Container                │
├─────────────────────────────────────────────────────┤
│                                                       │
│  ┌──────────────────────────────────────────────┐   │
│  │         FastAPI HTTP Server (8000)           │   │
│  │  - Health checks                             │   │
│  │  - Admin interface                           │   │
│  │  - State inspection                          │   │
│  └──────────────────────────────────────────────┘   │
│                       │                               │
│  ┌──────────────────────────────────────────────┐   │
│  │        SCPI TCP Server (5001-5003)           │   │
│  │  - SCPI command processing                   │   │
│  │  - Query responses                           │   │
│  └──────────────────────────────────────────────┘   │
│                       │                               │
│  ┌──────────────────────────────────────────────┐   │
│  │         Equipment Implementation             │   │
│  │  - State management                          │   │
│  │  - Command handlers                          │   │
│  └──────────────────────────────────────────────┘   │
│                       │                               │
│  ┌──────────────────────────────────────────────┐   │
│  │         RF Physics Engine                    │   │
│  │  - Harmonic generation                       │   │
│  │  - Noise floor modeling                      │   │
│  │  - Intermodulation products                  │   │
│  │  - Frequency response                        │   │
│  └──────────────────────────────────────────────┘   │
│                                                       │
└─────────────────────────────────────────────────────┘
```

## RF Physics Engine

### Capabilities

#### 1. Harmonics
- **2nd Order**: -30 dBc (typical)
- **3rd Order**: -40 dBc (typical)
- **Higher Orders**: Configurable up to 5th harmonic
- **Accurate frequency placement**: Integer multiples of fundamental

#### 2. Noise Floor
- **Thermal Noise**: -174 dBm/Hz base
- **Equipment NF**: Configurable (default 10 dB)
- **RBW-dependent**: Scales with resolution bandwidth
- **Realistic variation**: ±1 dB random fluctuation

#### 3. Intermodulation
- **IM3 Products**: 2f1-f2, 2f2-f1
- **IM5 Products**: 3f1-2f2, 3f2-2f1
- **IP3-based calculation**: Accurate power levels
- **Multi-tone support**: Multiple signal intermodulation

#### 4. Frequency Response
- **Filter shapes**: Gaussian rolloff
- **Configurable BW**: 3dB bandwidth control
- **Realistic selectivity**: 6th order filter response

## Equipment Types

### Spectrum Analyzer

**SCPI Port**: 5001 (default)
**HTTP Admin**: 8001 (default)

**Key Features:**
- Frequency sweep: 0.1 MHz to 10 GHz
- RBW: 1 Hz to 10 MHz
- Configurable sweep points: 101-10001
- Marker functionality
- Trace data export

**Supported SCPI Commands:**
```scpi
*IDN?                          # Identification
*RST                           # Reset
FREQ:CENT <freq>              # Set center frequency
FREQ:SPAN <span>              # Set span
FREQ:START <freq>             # Set start frequency
FREQ:STOP <freq>              # Set stop frequency
BAND:RES <bw>                 # Set RBW
SWE:POIN <points>             # Set sweep points
INIT:IMM                      # Initiate sweep
TRAC:DATA?                    # Get trace data
CALC:MARK1:X <freq>           # Set marker frequency
CALC:MARK1:Y?                 # Get marker power
```

**Example Usage:**
```python
import socket

# Connect
sock = socket.create_connection(('127.0.0.1', 5001))

# Configure
sock.sendall(b'FREQ:CENT 1e9\n')
sock.sendall(b'FREQ:SPAN 10e6\n')
sock.sendall(b'BAND:RES 1000\n')

# Measure
sock.sendall(b'INIT:IMM\n')
time.sleep(1)

# Get data
sock.sendall(b'TRAC:DATA?\n')
data = sock.recv(65536).decode()
print(f"Trace: {data}")
```

### Signal Generator

**SCPI Port**: 5002 (default)
**HTTP Admin**: 8002 (default)

**Key Features:**
- Frequency range: 10 MHz to 6 GHz
- Power range: -100 to +20 dBm
- Output enable/disable
- Modulation support (future)

**Supported SCPI Commands:**
```scpi
*IDN?                          # Identification
*RST                           # Reset
FREQ <freq>                   # Set frequency
POW <power>                   # Set power
OUTP ON|OFF                   # Output control
OUTP?                         # Query output state
FREQ?                         # Query frequency
POW?                          # Query power
```

### Device Under Test (DUT)

**SCPI Port**: 5003 (default)
**HTTP Admin**: 8003 (default)

**Key Features:**
- Multiple processing modes: LINEAR, BYPASS, AMPLIFY
- Configurable gain/attenuation
- Temperature monitoring
- Power monitoring

**Supported SCPI Commands:**
```scpi
*IDN?                          # Identification
*RST                           # Reset
MODE <mode>                   # Set processing mode
GAIN <db>                     # Set gain
ATTEN <db>                    # Set attenuation
OUTP ON|OFF                   # Output control
INPUT:POWER?                  # Query input power
OUTPUT:POWER?                 # Query output power
TEMP?                         # Query temperature
```

## HTTP Admin Interface

Each mock equipment provides an HTTP admin interface for debugging and monitoring.

### Endpoints

**GET /health**
```json
{
  "status": "healthy",
  "equipment_type": "spectrum_analyzer",
  "model": "MOCK-SA-5000",
  "scpi_port": 5001
}
```

**GET /state**
```json
{
  "equipment_type": "spectrum_analyzer",
  "state": {
    "center_frequency_hz": 1000000000,
    "span_hz": 10000000,
    "rbw_hz": 1000,
    "sweep_points": 401,
    "last_sweep_time": "2026-03-01T10:30:00"
  }
}
```

**POST /command**
```json
{
  "command": "*IDN?"
}
```

Response:
```json
{
  "response": "Mock Instruments Inc.,MOCK-SA-5000,MOCK-12345,1.0.0",
  "success": true
}
```

**POST /reset**
```json
{
  "status": "reset successful"
}
```

## Configuration

### Environment Variables

```bash
# Equipment type
EQUIPMENT_TYPE=spectrum_analyzer|signal_generator|dut

# Network
SCPI_PORT=5001              # TCP SCPI port
HTTP_PORT=8000              # HTTP admin port
HTTP_HOST=0.0.0.0           # HTTP bind address

# RF Physics
ENABLE_HARMONICS=true       # Enable harmonic simulation
HARMONIC_ORDER=3            # Number of harmonics to simulate
NOISE_FLOOR_DBM=-120        # Noise floor level
ENABLE_INTERMOD=true        # Enable intermodulation
```

### Docker Compose Example

```yaml
services:
  mock-sa:
    image: rf-mock-equipment:latest
    environment:
      - EQUIPMENT_TYPE=spectrum_analyzer
      - SCPI_PORT=5001
      - ENABLE_HARMONICS=true
      - HARMONIC_ORDER=3
    ports:
      - "5001:5001"
      - "8001:8000"
```

## Advanced Usage

### Simulating Specific Scenarios

**1. Add test signal for SA to measure:**
```bash
curl -X POST http://localhost:8001/sa/set_signal_source \
  -d "frequency_hz=1000000000" \
  -d "power_dbm=-20" \
  -d "enabled=true"
```

**2. Trigger sweep manually:**
```bash
curl -X POST http://localhost:8001/sa/perform_sweep
```

**3. Get equipment state:**
```bash
curl http://localhost:8001/state | jq
```

### Performance Tuning

**Reduce harmonic order for faster simulations:**
```yaml
environment:
  - HARMONIC_ORDER=2  # Only 2nd harmonic
```

**Disable intermodulation if not needed:**
```yaml
environment:
  - ENABLE_INTERMOD=false
```

## Troubleshooting

### Equipment Not Responding

```bash
# Check container status
docker ps | grep mock

# Check logs
docker logs mock-sa

# Test TCP connection
nc -zv 127.0.0.1 5001
```

### SCPI Communication Errors

```bash
# Test basic connectivity
echo "*IDN?" | nc 127.0.0.1 5001

# Expected response:
# Mock Instruments Inc.,MOCK-SA-5000,MOCK-12345,1.0.0
```

### RF Physics Issues

If spectrum doesn't look realistic:
1. Check `ENABLE_HARMONICS` is true
2. Verify `NOISE_FLOOR_DBM` setting
3. Check signal source is configured (for SA)
4. Review container logs for RF engine warnings

## Extending Mock Equipment

### Adding New Commands

Edit `mock_equipment/equipment/<equipment_type>.py`:

```python
def handle_command(self, command: str, is_query: bool) -> str:
    cmd_upper = command.upper()

    # Add your new command
    if 'MYCMD' in cmd_upper:
        return self._handle_mycmd(command, is_query)

    # ... existing code
```

### Customizing RF Physics

Edit `mock_equipment/rf_physics.py` to modify:
- Harmonic levels
- Noise characteristics
- Intermodulation behavior
- Frequency response

## See Also

- [Integration Setup Guide](INTEGRATION_SETUP.md)
- [PoPo Tests](POPO_TESTS.md)
- [RF Physics Simulation](RF_PHYSICS_SIMULATION.md)
