from __future__ import annotations

"""Centralised logging utilities used across MaiWay.

This module houses ``MaiWayLogger`` (a thin wrapper around Python's
:pyclass:`logging.Logger`) plus :pyfunc:`get_logger` to obtain
per-module loggers that inherit the unified formatting & handlers.

Keeping logging setup in one location avoids re-declaring handlers in
multiple modules and makes it trivial to adjust log format or level
from a single place.
"""

import logging
import os
import sys
from datetime import datetime
from typing import Optional

# ----------------------------------------------------------------------------
# Internal helper – initialise handlers only once per process
# ----------------------------------------------------------------------------

_CONSOLE_FORMAT = "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
_FILE_FORMAT = (
    "%(asctime)s - %(name)s - %(levelname)s - %(funcName)s:%(lineno)d - %(message)s"
)


def _create_root_logger(level: int = logging.INFO) -> logging.Logger:
    root = logging.getLogger("maiway")
    if root.handlers:
        return root  # already configured

    root.setLevel(level)

    # Console handler -------------------------------------------------------
    ch = logging.StreamHandler(sys.stdout)
    ch.setLevel(level)
    ch.setFormatter(logging.Formatter(_CONSOLE_FORMAT))
    root.addHandler(ch)

    # File handler ----------------------------------------------------------
    log_dir = os.getenv("MAIWAY_LOG_DIR", "logs")
    os.makedirs(log_dir, exist_ok=True)
    fname = f"maiway_{datetime.now().strftime('%Y%m%d')}.log"
    fh = logging.FileHandler(os.path.join(log_dir, fname))
    fh.setLevel(logging.DEBUG)
    fh.setFormatter(logging.Formatter(_FILE_FORMAT))
    root.addHandler(fh)

    return root


# Build the singleton root logger ASAP so that get_logger works everywhere
_root_logger = _create_root_logger()


class MaiWayLogger:
    """Wrapper that exposes convenient helpers but proxies to stdlib Logger."""

    def __init__(self, name: str = "maiway"):  # name param kept for back-compat
        self._log = logging.getLogger(name)

    # Proxy common methods --------------------------------------------------
    def info(self, msg: str, *a, **k):  # noqa: D401
        self._log.info(msg, *a, **k)

    def debug(self, msg: str, *a, **k):
        self._log.debug(msg, *a, **k)

    def warning(self, msg: str, *a, **k):
        self._log.warning(msg, *a, **k)

    def error(self, msg: str, *a, **k):
        self._log.error(msg, *a, **k)

    def critical(self, msg: str, *a, **k):
        self._log.critical(msg, *a, **k)

    # Custom helpers --------------------------------------------------------
    def log_route_request(
        self,
        origin: tuple,
        destination: tuple,
        mode: str,
        duration_ms: float,
        success: bool,
    ) -> None:
        self.info(
            "Route request: %s -> %s, mode=%s, duration=%.2fms, success=%s",
            origin,
            destination,
            mode,
            duration_ms,
            success,
        )

    def log_api_call(self, api_name: str, duration_ms: float, success: bool) -> None:
        self.info("API call: %s, duration=%.2fms, success=%s", api_name, duration_ms, success)


# Public helpers ------------------------------------------------------------

def get_logger(name: str | None = None) -> logging.Logger:
    """Return a child logger of the root *maiway* logger with the given name."""

    if not name or name == "maiway":
        return _root_logger
    return _root_logger.getChild(name)


# Convenience global instance used by legacy code --------------------------
logger: MaiWayLogger = MaiWayLogger("maiway") 