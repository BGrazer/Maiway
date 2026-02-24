#!/usr/bin/env python3
import sys
sys.path.append('.')
from maiwayrouting.core_route_service import UnifiedRouteService

service = UnifiedRouteService('routing_data')

# Test the fixed routing
origin_lat, origin_lon = 14.592865227994464, 120.97662740540302
dest_lat, dest_lon = 14.578295030896403, 120.98943724881555

print('Testing fixed convenient mode routing...')
route_result = service.find_route_with_walking(origin_lat, origin_lon, dest_lat, dest_lon, mode='convenient')

if route_result and hasattr(route_result, 'segments'):
    print(f'SUCCESS! Route found with {len(route_result.segments)} segments:')
    lrt_found = False
    for i, seg in enumerate(route_result.segments):
        print(f'  {i+1}. {seg.mode.upper()}: {seg.instruction[:60]}...')
        print(f'     Distance: {seg.distance:.3f}km, Fare: P{seg.fare:.0f}')
        if seg.mode.lower() in ['lrt', 'rail']:
            lrt_found = True
            print(f'     *** LRT SEGMENT FOUND! ***')
    
    print()
    print(f'LRT in route: {"YES" if lrt_found else "NO"}')
    
    # Show total stats
    total_distance = sum(seg.distance for seg in route_result.segments)
    total_fare = sum(seg.fare for seg in route_result.segments)
    print(f'Total distance: {total_distance:.3f}km')
    print(f'Total fare: P{total_fare:.0f}')
    
else:
    print('FAILED: No route found')

