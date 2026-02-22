# Maiwayrouting Audit: Loaders, route_service.stops, and What Should Be Removed

## 1. Do we still need the loaders?

**Yes, but only two parts of them.**

### What the loaders are

- **`loaders/gtfs.py`** – Loads GTFS CSVs: `load_stops`, `load_routes`, `load_trips`, `load_stop_times`, `load_transfers`.
- **`loaders/fares.py`** – Loads fare CSVs: `load_fares` (Bus, Jeep, LRT tables).

### Why we need them (new Google Hybrid path only)

| Loader | Used? | Why |
|--------|--------|-----|
| **load_fares** (loaders/fares.py) | **Yes** | Called in `routing.py` at startup: `fare_tables = load_fares(config.data_dir)`. `fare_tables` is passed into `find_routes_google_hybrid()`. The adapter (and bus_jeep_overlap) use it for LRT/bus/jeep fare calculation. So we **must keep** the fares loader. |
| **load_stops** (loaders/gtfs.py) | **Yes** | Used inside `UnifiedRouteService.__init__`: `self.stops = gtfs_loader.load_stops(self.data_dir)`. `route_service.stops` is then used for (1) `/search-stops` and (2) the adapter’s “walk to nearest stop then transit” fallback. So we need **stops**; that implies we need **load_stops** (or an equivalent way to get the same data). |
| load_routes, load_trips, load_stop_times, load_transfers (loaders/gtfs.py) | **No** (for new path) | Only used to build the **old** graph (transit_graph, walking_graph, complete_graph) and run A*. The Google Hybrid path never uses those graphs. So for the **new approach only**, these four could be removed from the **code path** if we introduced a “stops-only” init (see below). |

### Summary

- **Keep:** `loaders/fares.py` (all of it) and `loaders/gtfs.py`’s **`load_stops`**.
- **Can be dropped from the “new path”** (if you add a minimal init): the rest of GTFS loading (routes, trips, stop_times, transfers) is only for the old engine.

If you want to **thin** the app and remove the old engine entirely, you could:

1. Add a small “Google-only” service that only calls `load_stops()`, loads trike terminals, and exposes `stops` and `trike_terminals`.
2. Load fares in `routing.py` with `load_fares()` as today.
3. Stop using `UnifiedRouteService` for the request path and use this minimal service instead. Then you could delete or stop calling the rest of the GTFS loader (routes, trips, stop_times, transfers) from that path.

---

## 2. What is route_service.stops for?

`route_service.stops` is a **dict**: `{ stop_id: { "name", "lat", "lon", "zone_id" } }`, built from GTFS `stops.txt` via `load_stops()`.

It is used in **two** places:

1. **`/search-stops`**  
   The app searches stops by name and returns suggestions (id, name, lat, lon). So `route_service.stops` **is** the source of truth for “all transit stops we can search and show.”  
   (The bug where we iterated the dict’s keys instead of values is fixed: we now iterate `.items()` and use `stop_id` and `stop_info`.)

2. **`find_routes_google_hybrid(..., stops=...)`**  
   When Google returns **only walking** routes, the adapter tries a fallback: “walk to nearest transit stop, then call Google again from that stop.” For that it needs a list of stop locations; that list is derived from `route_service.stops`. So `stops` is passed in as a **list of dicts** (each with `lat`, `lon`, `name`) so the adapter’s `_nearest_stop()` can find the nearest stop to the user.  
   (We now pass `list(route_service.stops.values())` when calling the adapter so the type matches what the adapter expects.)

So: **route_service.stops** = “all known transit stops,” used for **search** and for the **walk-to-nearest-stop** fallback in the Google adapter. We do need it for the new approach.

---

## 3. Which files in maiwayrouting should be GONE (old engine only)

Below, “**KEEP**” = used on the **Google Hybrid request path** (route, route-google, routes-multicriteria, search-stops). “**GONE**” = only used by the old engine (A*, graph, shapes, mile logic, etc.) or by tests/scripts for that engine.

### Top-level modules

| File | Verdict | Reason |
|------|--------|--------|
| **google_adapter.py** | **KEEP** | Entry point for all route requests: `find_routes_google_hybrid()`. |
| **bus_jeep_overlap.py** | **KEEP** | Bus→jeep substitution; used by google_adapter. |
| **geojson_route_matcher.py** | **KEEP** | `match_route`, `match_lrt_route` used by google_adapter for naming/LRT. |
| **config.py** | **KEEP** | Data dir and config; used by routing.py and init. |
| **logger.py** | **KEEP** | Logging. |
| **exceptions.py** | **KEEP** | Used by routing.py (and optionally elsewhere). |
| **canonical_routes.json** | **KEEP** | Used by google_adapter (and bus_jeep) for naming. |
| **core_route_service.py** | **KEEP (partial)** | Only for **`.stops`** and **`.trike_terminals`** and their loading. All A*/graph/find_all_routes/shape logic = **GONE** for the new path. |
| **core_shape_generator.py** | **GONE** | Only used by old engine and by `routing.py` to set `set_stops_cache(route_service.stops)`; no route response uses it. Can be removed from the request path and eventually deleted. |
| **networkx_cost_functions.py** | **GONE** | Only used by old A* cost; not used by Google adapter. |
| **models/route_segments.py** | **KEEP (only if you keep core_route_service)** | Used by core_route_service and graph_builder. If you delete the old engine and thin core_route_service to “stops + trike only,” you might be able to remove or slim this. For now, **needed by core_route_service** (old path still runs at startup). |

### loaders/

| File | Verdict | Reason |
|------|--------|--------|
| **loaders/fares.py** | **KEEP** | `load_fares` used in routing.py; fare_tables passed to adapter. |
| **loaders/gtfs.py** | **KEEP (only load_stops)** | `load_stops` needed for route_service.stops. `load_routes`, `load_trips`, `load_stop_times`, `load_transfers` only for old engine. |

### utils/

| File | Verdict | Reason |
|------|--------|--------|
| **utils/geo_utils.py** | **KEEP** | Haversine etc.; used by adapter, trike_utils, bus_jeep, others. |
| **utils/trike_utils.py** | **KEEP** | Trike terminals, segments, Mapbox polyline; used by google_adapter. |
| **utils/fare_utils.py** | **KEEP** | Used by fares/calculator (fallback fare). |
| **utils/logging.py** | **KEEP** | Logger used in multiple places. |
| **utils/polyline_simplify.py** | **GONE** | Only used by core_shape_generator; not on Google path. |

### fares/

| File | Verdict | Reason |
|------|--------|--------|
| **fares/calculator.py** | **KEEP** | `calculate_real_fare` used by google_adapter and bus_jeep_overlap. |

### mile/

| File | Verdict | Reason |
|------|--------|--------|
| **mile/first_last.py** | **GONE** | Used only by core_route_service (old first/last-mile and graph logic). Not used by google_adapter. |
| **mile/walk.py** | **GONE** | Same; only old engine. |
| **mile/trike.py** | **GONE** | Re-exports from trike_utils; adapter uses trike_utils directly. Can remove. |
| **mile/__init__.py** | **GONE** (if you remove first_last, walk, trike) | Only re-exports. |

### graph/

| File | Verdict | Reason |
|------|--------|--------|
| **graph/graph_builder.py** | **GONE** | Builds transit/walking/complete graph for A*. Only used by core_route_service for old engine. |

### routing/

| File | Verdict | Reason |
|------|--------|--------|
| **routing/algorithms.py** | **GONE** | A* and k_diverse_paths; only used by old engine. |

### shapes/

| File | Verdict | Reason |
|------|--------|--------|
| **shapes/polyline_factory.py** | **GONE** | `enhance_segments` only used by core_route_service (old path). Not used by Google adapter. |
| **shapes/__init__.py** | **GONE** (if you remove polyline_factory) | Re-exports. |

---

## 4. One-line summary

- **Loaders:** We still need **load_fares** and **load_stops**. The rest of GTFS (routes, trips, stop_times, transfers) is only for the old engine.
- **route_service.stops:** Used for **/search-stops** and for the adapter’s **“walk to nearest stop then transit”** fallback; must stay for the new approach.
- **In maiwayrouting, can be removed (or skipped on the new path):**  
  **core_shape_generator**, **networkx_cost_functions**, **mile/** (first_last, walk, trike re-export), **graph/graph_builder**, **routing/algorithms**, **shapes/polyline_factory**, **utils/polyline_simplify**.  
  **core_route_service** should be reduced to “load stops + trike terminals and expose .stops and .trike_terminals” if you drop the old engine entirely.

---

## 5. Bugs fixed in this pass

1. **`/search-stops`** was iterating `for stop in stops` over a dict, so `stop` was a key (string). Fixed by iterating `stops.items()` and using `stop_id` and `stop_info`.
2. **Adapter `stops` argument** expects a list of dicts (lat, lon, name). We were passing `route_service.stops` (a dict). Fixed by passing `list(stops_raw.values())` when the value is a dict at all three call sites in `routing.py`.

---

## 6. Folder cleanup (done)

Removed from the routing folder:

- **cache/** – `walking_edges_sparse_v3.pkl` (old engine walking edges). The `cache/` directory may remain empty; safe to delete the folder if desired.
- **scripts/** – All scripts (build_lrt_edges, download_manila_graph, filter_stops, fix_lrt_distances, networkx_adapter, routingresult). Used only for old engine / one-off builds; not used by the app.
- **Docs removed:** CODE_ALIGNMENT_SUMMARY.md, MAIWAY_GOOGLE_HYBRID_PROMPT.md, ROUTING_USED_VS_REMOVABLE.md, WHAT_WE_USE_NOW.md (obsolete or redundant with this audit).
- **Debug removed:** debug_dashboard.html, start_debug_server.py (optional debug tools; not required for the API).

**Kept:** README.md, RUN_AND_SETUP.md, ROUTING_FAQ.md, MAIWAYROUTING_AUDIT.md (this file).
