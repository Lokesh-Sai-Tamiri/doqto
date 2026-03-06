"""Real-time module for Socket.io."""

from realtime.socket_manager import SocketManager, sio
from realtime.events import register_events

__all__ = ["SocketManager", "sio", "register_events"]
