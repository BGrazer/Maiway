"""Deprecated shim – import the unified logger from utils.logging.

This file remains only so that existing imports like::

    from maiwayrouting.logger import logger

keep working after the refactor.  It re-exports the new implementation
from :pymod:`maiwayrouting.utils.logging` and will be removed in the
next major version.
"""

from maiwayrouting.utils.logging import MaiWayLogger, logger, get_logger  # noqa: F401 