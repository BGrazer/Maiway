from __future__ import annotations

"""CSV fare table loaders used by RouteService."""

from pathlib import Path
from typing import Dict
import pandas as pd

__all__ = ["load_fares"]


def load_fares(data_dir: str) -> Dict[str, pd.DataFrame]:
    """Return dict with DataFrames for each fare table.

    Keys: 'Bus', 'Jeep', 'LRT_REG', 'LRT_DISCOUNTED'.  Missing files are
    skipped gracefully so the caller can fall back to distance buckets.
    """

    fares_dir = Path(data_dir) / "fares"
    out: Dict[str, pd.DataFrame] = {}

    # ------------------------------
    # Helper: generic CSV reader
    # ------------------------------
    def _read(name: str, key: str):
        """Read simple distance‐bucket CSVs (bus / jeep)."""
        path = fares_dir / name
        if path.exists():
            out[key] = pd.read_csv(path)

    # ----------------------------------------
    # Helper: LRT table -> station matrix
    # ----------------------------------------
    def _read_lrt(name: str, key: str):
        """Read the new three-column LRT fare CSV and pivot into matrix.

        Expected columns:
        Station, To, Fare (PHP)
        The last column name may vary; we just grab the third column.
        """
        path = fares_dir / name
        if not path.exists():
            return

        df_raw = pd.read_csv(path)
        if df_raw.shape[1] < 3:
            # malformed; store as-is so caller can fallback gracefully
            out[key] = df_raw
            return

        # Use first, second, and *last* column to be robust to header wording
        col_station = df_raw.columns[0]
        col_to = df_raw.columns[1]
        col_fare = df_raw.columns[-1]

        pivot = (
            df_raw.pivot_table(
                index=col_station,
                columns=col_to,
                values=col_fare,
                aggfunc="first",
            )
        )
        out[key] = pivot

    # Distance-based modes
    _read("bus.csv", "Bus")
    _read("jeep.csv", "Jeep")

    # LRT tables (support both legacy and new filenames)
    _read_lrt("lrt1_single_journey_fare.csv", "LRT_REG")
    _read_lrt("lrt1_studentdiscount_fare.csv", "LRT_DISCOUNTED")
    _read_lrt("lrt1_stored_valuecard_fare.csv", "LRT_STORED")
    # Legacy filenames kept for backward compatibility
    _read_lrt("lrt1_sj.csv", "LRT_REG")
    _read_lrt("lrt1_sv.csv", "LRT_DISCOUNTED")
    return out 