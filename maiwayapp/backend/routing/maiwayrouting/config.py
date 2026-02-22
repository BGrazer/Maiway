"""
Configuration management for MaiWay routing engine
"""

import os
from dataclasses import dataclass, field
from typing import Optional

# Resolve routing root (backend/routing) so data paths work when run from backend/ or anywhere
_THIS_DIR = os.path.dirname(os.path.abspath(__file__))
_ROUTING_ROOT = os.path.dirname(_THIS_DIR)  # backend/routing


def _default_data_dir() -> str:
    return os.getenv("DATA_DIR") or os.path.join(_ROUTING_ROOT, "routing_data")


def _default_fares_dir() -> str:
    return os.getenv("FARES_DIR") or os.path.join(_ROUTING_ROOT, "routing_data", "fares")


@dataclass(slots=True)
class AppConfig:
    """Application-wide configuration resolved from environment variables."""

    # Data paths (resolved relative to backend/routing when env not set)
    data_dir: str = field(default_factory=_default_data_dir)
    fares_dir: str = field(default_factory=_default_fares_dir)

    # External tokens
    mapbox_token: str = field(default_factory=lambda: os.getenv("MAPBOX_TOKEN", ""))
    google_maps_api_key: str = field(default_factory=lambda: os.getenv("GOOGLE_MAPS_API_KEY") or os.getenv("GOOGLE_API_KEY", ""))

    # Graph parameters
    max_walking_distance: float = field(default_factory=lambda: float(os.getenv("MAX_WALKING_DISTANCE", "0.3")))
    # Absolute max distance from pin to nearest stop before we abort
    # Increased to allow suburban first/last-mile walking before falling back
    max_walking_to_stop_km: float = field(default_factory=lambda: float(os.getenv("MAX_WALKING_TO_STOP_KM", "2.5")))
    # NEW distance constraints – more forgiving defaults
    max_walk_segment_km: float = field(default_factory=lambda: float(os.getenv("MAX_WALK_SEG_KM", "0.8")))
    max_total_walk_km: float = field(default_factory=lambda: float(os.getenv("MAX_TOTAL_WALK_KM", "1.6")))
    overshoot_buffer_km: float = field(default_factory=lambda: float(os.getenv("OVERSHOOT_BUFFER_KM", "1.0")))

    # Routing parameters
    transfer_penalty: float = field(default_factory=lambda: float(os.getenv("TRANSFER_PENALTY", "10.0")))
    max_walking_segments: int = field(default_factory=lambda: int(os.getenv("MAX_WALKING_SEGMENTS", "3")))

    # Alternative path generation parameters (edge-penalised K-diverse)
    alt_path_k: int = field(default_factory=lambda: int(os.getenv("ALT_PATH_K", "6")))
    alt_path_penalty: float = field(default_factory=lambda: float(os.getenv("ALT_PATH_PENALTY", "5.0")))
    alt_path_retry_limit: int = field(default_factory=lambda: int(os.getenv("ALT_PATH_RETRY_LIMIT", "3")))
    
    # Multi-source routing parameters
    max_candidate_stops: int = field(default_factory=lambda: int(os.getenv("MAX_CANDIDATE_STOPS", "20")))
    backtrack_penalty: float = field(default_factory=lambda: float(os.getenv("BACKTRACK_PENALTY", "0.8")))
    walk_speed_kmph: float = field(default_factory=lambda: float(os.getenv("WALK_SPEED_KMPH", "5.0")))
    
    # Cache parameters
    nearest_cache_size: int = field(default_factory=lambda: int(os.getenv("NEAREST_CACHE_SIZE", "1000")))
    network_cache_size: int = field(default_factory=lambda: int(os.getenv("NETWORK_CACHE_SIZE", "5000")))
    
    # Transfer penalty constants
    transfer_penalty_min: float = field(default_factory=lambda: float(os.getenv("TRANSFER_PENALTY_MIN", "120.0")))
    lrt_transfer_penalty: float = field(default_factory=lambda: float(os.getenv("LRT_TRANSFER_PENALTY", "4.0")))
    bus_transfer_penalty: float = field(default_factory=lambda: float(os.getenv("BUS_TRANSFER_PENALTY", "15.0")))
    jeep_transfer_penalty: float = field(default_factory=lambda: float(os.getenv("JEEP_TRANSFER_PENALTY", "15.0")))
    walking_penalty: float = field(default_factory=lambda: float(os.getenv("WALKING_PENALTY", "100.0")))
    
    # Speed constants for routing (km/h)
    lrt_speed_kmph: float = field(default_factory=lambda: float(os.getenv("LRT_SPEED_KMPH", "40.0")))
    bus_speed_kmph: float = field(default_factory=lambda: float(os.getenv("BUS_SPEED_KMPH", "15.0")))
    jeep_speed_kmph: float = field(default_factory=lambda: float(os.getenv("JEEP_SPEED_KMPH", "20.0")))
    
    # Graph building parameters  
    walk_radius_km: float = field(default_factory=lambda: float(os.getenv("WALK_RADIUS_KM", "0.8")))
    sparse_edge_limit_normal: int = field(default_factory=lambda: int(os.getenv("SPARSE_EDGE_LIMIT_NORMAL", "4")))
    sparse_edge_limit_lrt: int = field(default_factory=lambda: int(os.getenv("SPARSE_EDGE_LIMIT_LRT", "8")))

    # API server
    host: str = field(default_factory=lambda: os.getenv("HOST", "0.0.0.0"))
    port: int = field(default_factory=lambda: int(os.getenv("PORT", "5000")))
    debug: bool = field(default_factory=lambda: os.getenv("DEBUG", "False").lower() == "true")

    # Logging
    log_level: str = field(default_factory=lambda: os.getenv("LOG_LEVEL", "INFO"))
    log_file: Optional[str] = field(default_factory=lambda: os.getenv("LOG_FILE"))

    # ------------------------------------------------------------------
    # convenience helpers used by legacy code below
    # ------------------------------------------------------------------
    def validate(self) -> None:  # noqa: D401
        if not os.path.exists(self.data_dir):
            raise ValueError(f"Data directory does not exist: {self.data_dir}")
        if not self.mapbox_token:
            raise ValueError("Mapbox token is required")
        if self.max_walking_distance <= 0:
            raise ValueError("Max walking distance must be positive")

    # Compatibility getters
    def get_graph_builder_config(self) -> dict:  # noqa: D401
        return {
            "data_dir": self.data_dir,
            "max_walking_distance": self.max_walking_distance,
        }

    def get_router_config(self) -> dict:  # noqa: D401
        return {
            "transfer_penalty": self.transfer_penalty,
            "max_walking_segments": self.max_walking_segments,
        }

    def get_api_config(self) -> dict:  # noqa: D401
        return {"host": self.host, "port": self.port, "debug": self.debug}


# Global singleton (keeps previous import style working)
config = AppConfig() 