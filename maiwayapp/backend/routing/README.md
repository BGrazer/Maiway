# MaiWay - Multi-Criteria Routing Engine

A Python-based routing API for commuter apps. Uses **Google Directions API (transit)** plus MaiWay inference: bus→jeepney substitution, fares, tricycle injection, and segment formatting. Stops and tricycle terminals are loaded from GTFS and GeoJSON for search and fallback logic.

## Current approach (Google Hybrid)

- **Routing**: Google Directions API (transit + walking) → MaiWay adapter (segment mapping, fares, bus/jeep substitution, three-route synthesis: fastest / cheapest / convenient).
- **Stops**: GTFS `stops.txt` for `/search-stops` and “walk to nearest stop” fallback.
- **Tricycle**: Optional first/last-mile injection when origin/destination are near TODA terminals (convenient preference).
- **Fares**: LRT/bus/jeep tables in `routing_data/fares/`; Mapbox for walking/tricycle polylines when available.

## Quick Start

### Prerequisites

- Python 3.8+
- GTFS data files
- Mapbox API key

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd gtfs
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Set up environment variables:
```bash
export MAPBOX_TOKEN="your_mapbox_api_key"
export DATA_DIR="data"
```

4. Run the application:
```bash
python routing.py
```

## Configuration

### Environment Variables

- MAPBOX_TOKEN: Mapbox API key for polyline generation
- GOOGLE_MAPS_API_KEY or GOOGLE_API_KEY: (Optional) For Google hybrid routing. When set, enable "Use Google Hybrid" in app preferences to use Google Directions API (transit) + MaiWay inference layer
- DATA_DIR: Directory containing GTFS data files
- MAX_WALKING_DISTANCE: Maximum walking distance between stops (default: 0.3 km)
- MAX_TRICYCLE_DISTANCE: Maximum tricycle connection distance (default: 1.5 km)
- TRANSFER_PENALTY: Penalty for transfers (default: 10.0)
- MAX_WALKING_SEGMENTS: Maximum walking segments per route (default: 3)

### GTFS Data Structure

```
data/
├── agency.txt
├── routes.txt
├── stops.txt
├── trips.txt
├── stop_times.txt
├── shapes.txt
├── fares/
│   ├── lrt1_sj.csv
│   ├── lrt1_sv.csv
│   ├── pub_aircon.csv
│   ├── pub_ordinary.csv
│   └── puj.csv
└── tricycle.geojson
```

## API Endpoints

### Health Check
```
GET /health
```

### Route Finding
```
POST /route
{
    "start": {"lat": 14.5837, "lon": 120.9843},
    "end": {"lat": 14.5806, "lon": 120.9866},
    "mode": "fastest",
    "use_google": false
}
```
When `use_google: true`, uses Google Directions API (transit) + MaiWay inference layer. Requires GOOGLE_MAPS_API_KEY.

### Google Hybrid (dedicated endpoint)
```
POST /route-google
{
    "start": {"lat": 14.5837, "lon": 120.9843},
    "end": {"lat": 14.5806, "lon": 120.9866},
    "preferences": ["fastest", "cheapest", "convenient"]
}
```

### Stop Search
```
GET /search-stops?q=station
```

## Architecture

### Core Components

- GraphBuilder: Builds routing graph from GTFS data
- AStarRouter: Implements A* pathfinding with multiple cost functions
- FareCalculator: Handles fare calculations for different modes
- ShapeGenerator: Generates polylines using Mapbox and GTFS shapes
- RouteConsolidator: Merges consecutive route segments
- TrikeConnector: Handles tricycle terminal connections

### Routing Modes

1. **Fastest**: Optimizes for shortest distance using mode-weighted kilometers
   - Uses mode weights: LRT (1.0x) < Bus (1.2x) < Jeep (1.5x)
   - Prefers faster modes when distances are comparable
   
2. **Cheapest**: Optimizes for lowest fare cost with real per-edge pricing
   - Uses fare tables from `routing_data/fares/*.csv`
   - Fallback rates: Jeep ₱1.0/km, Bus ₱1.2/km, LRT ₱1.5/km
   - Small distance component prevents unreasonable detours
   
3. **Convenient**: Balances distance, fare, and mode preferences
   - Mixed scoring: 0.5×distance + 0.5×fare
   - LRT bonus (-1.5) encourages rail usage
   - Larger walk radius (1.5km) to reach LRT stations

### Transport Modes

- LRT/MRT: Fixed rail transit with GTFS shapes
- Bus: Public bus service with Mapbox polylines
- Jeepney: Local jeepney service with Mapbox polylines
- Tricycle: Local tricycle service with distance restrictions
- Walking: Pedestrian connections with Mapbox polylines

## Multi-Source Routing

### Overview

The routing engine now uses advanced multi-source routing to intelligently select boarding and alighting stops. Instead of simply choosing the nearest stops, the system:

1. **Builds candidate pools** of forward-facing stops (≤20 per location)
2. **Filters by progress** - only includes stops that move toward the destination
3. **Runs integrated A* search** that considers both walking and transit costs
4. **Validates results** for walking limits and overshoot constraints

### Benefits

- **Better stop selection**: Chooses stops that make sense for the overall journey
- **Prevents backtracking**: Eliminates routes that go in the wrong direction
- **True cost optimization**: Weighs walking vs transit costs in one search
- **Guaranteed differentiation**: Fastest, cheapest, and convenient routes are truly different

### Algorithm Details

#### Candidate Pool Generation
```python
# Forward-facing stops within walking distance
candidates = collect_candidate_stops(
    origin_lat, origin_lon, dest_lat, dest_lon,
    stops, max_walk_km=0.8, max_candidates=20
)
```

#### Multi-Source A* Search
```python
# Generate multiple alternatives for route diversity
paths = find_route_astar_multi(
    complete_graph, origin_candidates, dest_candidates,
    cost_func=make_cost_function(mode), max_k=3
)

# Select best path based on mode criteria
if mode == 'fastest':
    best = min(paths, key=lambda p: total_distance(p))
elif mode == 'cheapest':  
    best = min(paths, key=lambda p: total_fare(p))
else:  # convenient
    best = min(paths, key=lambda p: convenient_score(p))
```

#### Validation Layer
- Total walking distance ≤ `max_total_walk_km` (default: 1.5 km)
- Path overshoot ≤ 110% of straight-line distance
- Individual walking segments ≤ `max_walking_to_stop_km` (default: 2.5 km)

### Configuration

New environment variables:
```bash
MAX_CANDIDATE_STOPS=20      # Candidate pool size
BACKTRACK_PENALTY=0.8       # Penalty for regression (minutes/km)
WALK_SPEED_KMPH=5.0         # Walking speed for time calculations
MAX_TOTAL_WALK_KM=1.5       # Total walking limit
```

## Polyline Generation

### Mapbox Integration
- Uses Mapbox Directions API for accurate road-following polylines
- Supports both driving and walking profiles
- Implements JSON file-based caching to reduce API calls
- Handles all transport modes except LRT/MRT

### GTFS Shapes
- LRT/MRT routes use GTFS shapes.txt for accurate rail alignment
- Provides precise station-to-station routing
- Maintains historical route accuracy

### Caching Strategy
- Polylines are cached in mapbox_polyline_cache.json
- Reduces API costs and improves response times
- Cache persists across application restarts

## Performance

- Graph building: ~10 seconds for Manila GTFS data
- Route finding: Sub-millisecond to tens of milliseconds
- Polyline generation: Cached responses are instant
- API response: Typically under 100ms for cached routes

## Development

### Running Tests
```bash
python -m pytest tests/
```

### Code Structure
```
/
├── routing.py
├── requirements.txt
├── README.md
├── Dockerfile

├── data/
│   ├── fares/
│   ├── gtfs_manila/
│   ├── routes-geojson/
│   ├── [GTFS and geojson files...]
│   └── [backups, if needed]
├── cache/
│   └── [cache files]
├── scripts/
│   ├── filter_stops.py
│   ├── build_lrt_edges.py
│   ├── fix_lrt_distances.py
│   └── [other data-prep or utility scripts]
├── tests/
│   ├── test_multimodal_20.py
│   ├── test_lrt_multimodal.py
│   └── [other test files]
├── logs/
│   ├── maiway_20250713.log
│   ├── maiway_20250712.log
│   ├── maiway_20250709.log
│   ├── maiway_20250708.log
│   └── [other log files]
├── maiwayrouting/
│   ├── __init__.py
│   ├── config.py
│   ├── logger.py
│   ├── exceptions.py
│   ├── unified_route_service.py
│   ├── unified_shape_generator.py
│   ├── networkx_cost_functions.py
│   ├── models/
│   │   └── route_segments.py
│   ├── utils/
│   │   ├── fare_utils.py
│   │   └── geo_utils.py
│   ├── graph/
│   │   └── graph_builder.py
│   ├── routing/
│   │   └── algorithms.py
│   └── logging.json
```