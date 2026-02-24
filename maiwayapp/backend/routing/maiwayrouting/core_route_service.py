"""
Minimal route service for Google Hybrid: exposes .stops and .trike_terminals only.
Used for /search-stops and find_routes_google_hybrid(stops=..., trike_terminals=...).
"""

import os
import logging
from typing import Dict, List, Any

from maiwayrouting.loaders import gtfs as gtfs_loader
from maiwayrouting.utils.trike_utils import load_trike_terminals


class UnifiedRouteService:
    """Lightweight service that loads only stops and tricycle terminals for the Google Hybrid path."""

    def __init__(self, data_dir: str = "routing_data"):
        self.data_dir = data_dir
        self.logger = logging.getLogger(__name__)
        self.stops: Dict[str, Dict[str, Any]] = {}
        self.trike_terminals: List[Dict[str, Any]] = []

        # Load stops (GTFS stops.txt)
        try:
            self.stops = gtfs_loader.load_stops(self.data_dir)
            self.logger.info("Loaded %d stops", len(self.stops))
        except Exception as e:
            self.logger.warning("Could not load stops: %s", e)

        # Load tricycle terminals
        pkg_root = os.path.dirname(os.path.abspath(__file__))
        trike_geojson = os.path.abspath(os.path.join(pkg_root, "..", self.data_dir, "tricycle_terminals.geojson"))
        if not os.path.exists(trike_geojson):
            trike_geojson = os.path.join(self.data_dir, "tricycle_terminals.geojson")
        self.trike_terminals = load_trike_terminals(trike_geojson)
        if self.trike_terminals:
            self.logger.info("Loaded %d tricycle terminals", len(self.trike_terminals))
        else:
            self.logger.info("No tricycle terminals loaded")
