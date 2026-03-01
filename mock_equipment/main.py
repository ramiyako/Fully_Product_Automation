"""
Mock RF Equipment Server

FastAPI application providing HTTP admin interface and TCP SCPI server
for mock RF equipment (Spectrum Analyzer, Signal Generator, DUT).
"""

import asyncio
import logging
import os
import sys
from contextlib import asynccontextmanager
from typing import Optional

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import uvicorn

# Add current directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from equipment.signal_generator import SignalGenerator
from equipment.spectrum_analyzer import SpectrumAnalyzer
from equipment.dut import DUT
from scpi_server import SCPIServer
from rf_physics import SignalSource

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Global variables
scpi_server: Optional[SCPIServer] = None
equipment = None


# Pydantic models for API
class CommandRequest(BaseModel):
    command: str


class CommandResponse(BaseModel):
    response: str
    success: bool


class HealthResponse(BaseModel):
    status: str
    equipment_type: str
    model: str
    scpi_port: int


class StateResponse(BaseModel):
    equipment_type: str
    state: dict


# Lifespan context manager
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manage application lifespan"""
    global scpi_server, equipment

    # Startup
    logger.info("Starting mock equipment server...")

    # Get configuration from environment
    equipment_type = os.getenv('EQUIPMENT_TYPE', 'spectrum_analyzer')
    scpi_port = int(os.getenv('SCPI_PORT', '5025'))

    # Create equipment
    config = {
        'enable_harmonics': os.getenv('ENABLE_HARMONICS', 'true').lower() == 'true',
        'enable_intermod': os.getenv('ENABLE_INTERMOD', 'true').lower() == 'true',
        'harmonic_order': int(os.getenv('HARMONIC_ORDER', '3')),
        'noise_floor_dbm': float(os.getenv('NOISE_FLOOR_DBM', '-120')),
    }

    if equipment_type == 'signal_generator':
        equipment = SignalGenerator(config)
    elif equipment_type == 'spectrum_analyzer':
        equipment = SpectrumAnalyzer(config)
    elif equipment_type == 'dut':
        equipment = DUT(config)
    else:
        raise ValueError(f"Unknown equipment type: {equipment_type}")

    # Start SCPI server
    scpi_server = SCPIServer(equipment, port=scpi_port)
    asyncio.create_task(scpi_server.run_forever())

    logger.info(f"Mock {equipment_type} ready on SCPI port {scpi_port}")

    yield

    # Shutdown
    logger.info("Shutting down...")
    if scpi_server:
        await scpi_server.stop()


# Create FastAPI app
app = FastAPI(
    title="Mock RF Equipment Server",
    description="HTTP admin interface for mock RF equipment",
    version="1.0.0",
    lifespan=lifespan
)


@app.get("/", response_model=HealthResponse)
async def root():
    """Root endpoint"""
    return {
        "status": "running",
        "equipment_type": equipment.equipment_type,
        "model": equipment.state.model,
        "scpi_port": scpi_server.port if scpi_server else 0
    }


@app.get("/health", response_model=HealthResponse)
async def health():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "equipment_type": equipment.equipment_type,
        "model": equipment.state.model,
        "scpi_port": scpi_server.port if scpi_server else 0
    }


@app.get("/state", response_model=StateResponse)
async def get_state():
    """Get equipment state"""
    return {
        "equipment_type": equipment.equipment_type,
        "state": equipment.state_manager.get_state_dict()
    }


@app.post("/command", response_model=CommandResponse)
async def send_command(request: CommandRequest):
    """
    Send SCPI command to equipment (for testing/debugging)

    This allows sending commands via HTTP instead of SCPI TCP
    """
    try:
        response = equipment.process_command(request.command)
        return {
            "response": response,
            "success": True
        }
    except Exception as e:
        logger.error(f"Command error: {e}")
        return {
            "response": str(e),
            "success": False
        }


@app.post("/reset")
async def reset_equipment():
    """Reset equipment to default state"""
    try:
        equipment.state_manager.reset()
        return {"status": "reset successful"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/connections")
async def get_connections():
    """Get active SCPI connections"""
    if scpi_server:
        return {
            "count": len(scpi_server.connections),
            "connections": [
                str(writer.get_extra_info('peername'))
                for writer in scpi_server.connections
            ]
        }
    return {"count": 0, "connections": []}


# Spectrum Analyzer specific endpoints
@app.post("/sa/set_signal_source")
async def set_signal_source(frequency_hz: float, power_dbm: float, enabled: bool = True):
    """
    Set signal source for spectrum analyzer simulation

    Only available for spectrum_analyzer equipment type
    """
    if equipment.equipment_type != 'spectrum_analyzer':
        raise HTTPException(status_code=400, detail="Only available for spectrum analyzer")

    try:
        source = SignalSource(
            frequency_hz=frequency_hz,
            power_dbm=power_dbm,
            enabled=enabled
        )
        equipment.set_signal_sources([source])
        return {"status": "signal source set", "frequency_ghz": frequency_hz / 1e9, "power_dbm": power_dbm}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/sa/perform_sweep")
async def perform_sweep():
    """
    Trigger spectrum sweep

    Only available for spectrum_analyzer equipment type
    """
    if equipment.equipment_type != 'spectrum_analyzer':
        raise HTTPException(status_code=400, detail="Only available for spectrum analyzer")

    try:
        equipment._perform_sweep()
        return {
            "status": "sweep completed",
            "points": len(equipment.sa_state.last_sweep_data) if equipment.sa_state.last_sweep_data else 0
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


def main():
    """Main entry point"""
    port = int(os.getenv('HTTP_PORT', '8000'))
    host = os.getenv('HTTP_HOST', '0.0.0.0')

    logger.info(f"Starting HTTP server on {host}:{port}")

    uvicorn.run(
        "mock_equipment.main:app",
        host=host,
        port=port,
        log_level="info"
    )


if __name__ == "__main__":
    main()
