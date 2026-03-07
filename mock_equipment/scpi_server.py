"""
SCPI Server

TCP server implementing SCPI protocol for mock RF equipment.
Handles multiple concurrent connections and command processing.
"""

import asyncio
import logging
from typing import Optional

logger = logging.getLogger(__name__)


class SCPIServer:
    """
    SCPI TCP Server

    Implements SCPI communication protocol over TCP/IP
    """

    def __init__(self, equipment, host: str = '0.0.0.0', port: int = 5025):
        """
        Initialize SCPI server

        Args:
            equipment: Equipment instance to handle commands
            host: Host to bind to
            port: Port to listen on
        """
        self.equipment = equipment
        self.host = host
        self.port = port
        self.server: Optional[asyncio.Server] = None
        self.connections = set()

        logger.info(f"SCPI Server initialized on {host}:{port}")

    async def handle_client(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter):
        """
        Handle SCPI client connection

        Args:
            reader: Stream reader
            writer: Stream writer
        """
        addr = writer.get_extra_info('peername')
        logger.info(f"Client connected from {addr}")
        self.connections.add(writer)

        try:
            while True:
                # Read command (terminated by \n)
                data = await reader.readline()

                if not data:
                    break

                # Decode command
                command = data.decode('utf-8').strip()

                if not command:
                    continue

                logger.debug(f"Received from {addr}: {command}")

                # Process command
                try:
                    response = self.equipment.process_command(command)

                    # Send response if query
                    if command.strip().endswith('?') and response:
                        response_data = f"{response}\n".encode('utf-8')
                        writer.write(response_data)
                        await writer.drain()
                        logger.debug(f"Sent to {addr}: {response}")

                except Exception as e:
                    logger.error(f"Error processing command '{command}': {e}")
                    # SCPI devices typically don't send error responses inline
                    # Error is retrieved via SYST:ERR? query

        except asyncio.CancelledError:
            logger.info(f"Connection cancelled for {addr}")
        except Exception as e:
            logger.error(f"Error handling client {addr}: {e}")
        finally:
            self.connections.discard(writer)
            logger.info(f"Client disconnected: {addr}")
            try:
                writer.close()
                await writer.wait_closed()
            except:
                pass

    async def start(self):
        """Start SCPI server"""
        self.server = await asyncio.start_server(
            self.handle_client,
            self.host,
            self.port
        )

        addrs = ', '.join(str(sock.getsockname()) for sock in self.server.sockets)
        logger.info(f"SCPI Server listening on {addrs}")

    async def stop(self):
        """Stop SCPI server"""
        if self.server:
            logger.info("Stopping SCPI server...")
            self.server.close()
            await self.server.wait_closed()

            # Close all connections
            for writer in self.connections:
                try:
                    writer.close()
                    await writer.wait_closed()
                except:
                    pass

            self.connections.clear()
            logger.info("SCPI server stopped")

    async def run_forever(self):
        """Run server forever"""
        await self.start()
        await asyncio.Event().wait()  # Run forever
