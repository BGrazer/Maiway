# MaiWay Routing – FAQ

## 1. Why do I only see one route and it’s all walking?

**What’s going on**

- The app asks **Google Directions API** with **`mode=transit`**.
- For your origin and destination, **Google is returning a single route**, and that route has **no transit legs** (only walking). That usually means:
  - Google has **no (or very limited) transit data** for that area (e.g. Intramuros / Port Area), or
  - The trip is short enough that Google suggests walking only, or
  - There are no transit options it knows about between those two points.

So you get **one route** that is **walking-only**. The backend then labels that same route as “fastest”, “cheapest”, and “convenient”, so the app can show one option (or three identical cards).

**Can we “bypass” and get different routes (e.g. walk to a stop, then use Google)?**

Yes. This is implemented as a **fallback** in the Google adapter:

1. **Walk to a transit stop**  
   Use our GTFS stops (or a small offset from your origin) to pick a nearby transit stop.
2. **Call Google from that stop to your destination**  
   Request transit from “stop location” → “destination”. Google is more likely to return bus/LRT options when the origin is at or near a known stop.
3. **Combine**  
   One route = “Walk from origin → stop” + “Google transit from stop → destination”.

Google does **not** support waypoints for `mode=transit`, so we cannot do “A → waypoint → B” in a single request. The “bypass” has to be two steps: our walking leg to a stop, then a separate Google transit request from that stop. This can be added as an optional fallback when the first Google call returns only a walking-only route.

---

## 2. Which GeoJSON are we using?

| GeoJSON | Where it lives | Used by | Purpose in current flow |
|--------|----------------|---------|--------------------------|
| **Jeep1–9** | `routing_data/routes-geojson/Jeep1.geojson` … `jeep9.geojson` | **Google Hybrid** – `bus_jeep_overlap.py` | Bus–jeepney overlap detection and substituting a bus leg with a jeepney leg when the bus route overlaps a jeepney corridor. |
| **fullcityofmanila.geojson** | `routing_data/fullcityofmanila.geojson` | Old engine only – `core_route_service._load_geojson_linestrings()` | Street LineStrings. **Not used for route computation** (only loaded at startup with the old engine). |
| **lrtroutes.geojson** | `routing_data/lrtroutes.geojson` (and under `routes-geojson/`) | Old engine only – same loader | LRT LineStrings. **Not used for route computation** in the Google Hybrid path. |
| **tricycle_terminals.geojson** | `routing_data/tricycle_terminals.geojson` | Old engine – `core_route_service` / `trike_utils` | TODA terminal points. Loaded at startup but **not used** when computing routes in the Google Hybrid flow (no tricycle injection). |
| **bus1–3** | `routing_data/routes-geojson/bus1.geojson` etc. | Old engine (loaded with other route GeoJSON) | **Not used** by the Google Hybrid adapter. |

**Summary:** For **actual routing** in the current app we only use the **jeepney GeoJSON** (Jeep1–Jeep9) in **`bus_jeep_overlap.py`**. All other GeoJSON files are either loaded by the old engine at startup or live in `routes-geojson/` but are not used by the Google Hybrid logic.

---

## 3. How does the fare matrix work? (CSV usage: bus, jeep, LRT)

**Yes, we use the CSVs.** Fares in the **Google Hybrid** flow are computed from the **CSV fare tables** (loaded at startup in `routing.py` via `load_fares()`):

| Mode | CSV file(s) | How it's used |
|------|-------------|----------------|
| **Bus** | `routing_data/fares/bus.csv` | Distance-based: columns `distance`, `regular`, `discounted`. We find the row where `distance` ≥ segment distance (km) and use `regular` or `discounted` by passenger type. |
| **Jeep** | `routing_data/fares/jeep.csv` | Same as bus: distance-based `regular` / `discounted`. |
| **LRT** | `lrt1_single_journey_fare.csv`, `lrt1_stored_valuecard_fare.csv`, `lrt1_studentdiscount_fare.csv` | **Station-to-station matrix.** We match Google stop names to the CSV’s Station / To columns (case-insensitive substring match). Passenger type selects which file: regular → single journey, stored value → stored value card, student/discount → student discount. So **LRT is used** and is the most “complicated” because it’s origin–destination station pairs, not distance. |

The logic lives in **`maiwayrouting/fares/calculator.py`** (`calculate_real_fare`). If a CSV is missing or a match fails, we fall back to simple distance buckets in **`utils/fare_utils.py`**.

**Fallback:** If a CSV is missing or a station/distance match fails, **`utils/fare_utils.py`** (`calculate_fare`) is used with simple distance bands (e.g. LRT ≤4 km → ₱20, Bus ≤5 km → ₱15, etc.).

---

## 4. Unused folders and files in routing

**Unused backend “routing” folders (not used by the running app):**

- **`routing2/`**, **`routing3/`**, **`routing4/`** – Old or experimental copies. The Flask app in `routing/` does not use them. Safe to archive or remove.

**Used only for startup and /search-stops (not for computing routes):**

- **`maiwayrouting/core_route_service.py`** – Initialized at startup; provides `route_service.stops` for `/search-stops`. Route computation uses **Google Hybrid**, not this engine.
- **`maiwayrouting/graph/graph_builder.py`** – Used by `core_route_service` to build the graph at startup. Not used when handling `/route` or `/routes-multicriteria`.
- **`maiwayrouting/routing/algorithms.py`** – A* and pathfinding; only used by the old engine. Not used by Google Hybrid.
- **`maiwayrouting/mile/`** – First/last-mile walking and tricycle helpers. Used only by `core_route_service`. Not used when computing routes via Google.
- **`maiwayrouting/shapes/polyline_factory.py`** – Used by the old engine for polyline enhancement. Not used by the Google adapter.
- **`maiwayrouting/loaders/`** – GTFS and fare loaders used at startup. Not used during Google-based route requests.
- **`maiwayrouting/networkx_cost_functions.py`** – Used by the old graph/algorithms. Not used by Google Hybrid.

**Loaded at startup but not used for route logic:**

- **`routing_data/fullcityofmanila.geojson`**, **`routing_data/lrtroutes.geojson`** – Loaded in `core_route_service`; not used by Google Hybrid for route computation. **`tricycle_terminals.geojson`** is loaded at startup and **is used** by Google Hybrid to inject first-mile or last-mile tricycle on the **convenient** route when origin/destination are near a TODA terminal.
- **`maiwayrouting/fares/calculator.py`** – CSV-based fare calculator. Google Hybrid uses **`utils/fare_utils.py`** instead.

**Scripts (not part of the request path):**

- **`scripts/build_lrt_edges.py`**, **`download_manila_graph.py`**, **`filter_stops.py`**, **`fix_lrt_distances.py`**, **`networkx_adapter.py`**, **`routingresult.py`** – Build/test helpers. Not invoked by the Flask app.

**Used by Google Hybrid (actual route flow):**

- **`routing.py`** – Flask app; calls `find_routes_google_hybrid` for `/route` and `/routes-multicriteria`.
- **`maiwayrouting/google_adapter.py`** – Google API calls, segment mapping, three-route synthesis, walking polylines (Mapbox + Google fallback).
- **`maiwayrouting/bus_jeep_overlap.py`** – Jeepney GeoJSON loading and bus→jeep substitution.
- **`maiwayrouting/canonical_routes.json`** – Route name normalization.
- **`maiwayrouting/utils/fare_utils.py`** – Fare calculation for segments.
- **`maiwayrouting/config.py`** – Config (e.g. data dir); **`maiwayrouting/logger.py`**, **`maiwayrouting/exceptions.py`** – Shared utilities.

So: **only one route and only walking** comes from Google’s response for that OD pair. **GeoJSON** used for routing is just the **jeepney set** in `bus_jeep_overlap`. **Fares** come from **`fare_utils.py`**. Everything else under routing is either for startup/search-stops, old engine, or scripts.
