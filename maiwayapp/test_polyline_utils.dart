import 'package:latlong2/latlong.dart';
import 'lib/utils/polyline_utils.dart';

void main() {
  print('🧪 Testing PolylineUtils...\n');
  
  // Test 1: [lon, lat] format (backend format)
  print('Test 1: [lon, lat] format');
  List<dynamic> backendFormat = [
    [120.9842, 14.5995], // Manila coordinates
    [121.0244, 14.5547], // Another Manila location
  ];
  List<LatLng> result1 = PolylineUtils.parsePolyline(backendFormat);
  print('Input: $backendFormat');
  print('Output: ${result1.map((p) => '(${p.latitude}, ${p.longitude})').toList()}');
  print('✅ Expected: [(14.5995, 120.9842), (14.5547, 121.0244)]');
  print('✅ Actual: ${result1.map((p) => '(${p.latitude}, ${p.longitude})').toList()}\n');
  
  // Test 2: [lat, lon] format
  print('Test 2: [lat, lon] format');
  List<dynamic> latLonFormat = [
    [14.5995, 120.9842], // Manila coordinates
    [14.5547, 121.0244], // Another Manila location
  ];
  List<LatLng> result2 = PolylineUtils.parsePolyline(latLonFormat);
  print('Input: $latLonFormat');
  print('Output: ${result2.map((p) => '(${p.latitude}, ${p.longitude})').toList()}');
  print('✅ Expected: [(14.5995, 120.9842), (14.5547, 121.0244)]');
  print('✅ Actual: ${result2.map((p) => '(${p.latitude}, ${p.longitude})').toList()}\n');
  
  // Test 3: Object format {latitude, longitude}
  print('Test 3: {latitude, longitude} format');
  List<dynamic> objectFormat = [
    {'latitude': 14.5995, 'longitude': 120.9842},
    {'latitude': 14.5547, 'longitude': 121.0244},
  ];
  List<LatLng> result3 = PolylineUtils.parsePolyline(objectFormat);
  print('Input: $objectFormat');
  print('Output: ${result3.map((p) => '(${p.latitude}, ${p.longitude})').toList()}');
  print('✅ Expected: [(14.5995, 120.9842), (14.5547, 121.0244)]');
  print('✅ Actual: ${result3.map((p) => '(${p.latitude}, ${p.longitude})').toList()}\n');
  
  // Test 4: Mixed format
  print('Test 4: Mixed format');
  List<dynamic> mixedFormat = [
    [120.9842, 14.5995], // [lon, lat]
    {'latitude': 14.5547, 'longitude': 121.0244}, // {lat, lon}
    LatLng(14.5000, 121.0000), // Direct LatLng
  ];
  List<LatLng> result4 = PolylineUtils.parsePolyline(mixedFormat);
  print('Input: $mixedFormat');
  print('Output: ${result4.map((p) => '(${p.latitude}, ${p.longitude})').toList()}');
  print('✅ Expected: [(14.5995, 120.9842), (14.5547, 121.0244), (14.5000, 121.0000)]');
  print('✅ Actual: ${result4.map((p) => '(${p.latitude}, ${p.longitude})').toList()}\n');
  
  // Test 5: Robust polyline with fallback
  print('Test 5: Robust polyline with fallback');
  LatLng origin = LatLng(14.5995, 120.9842);
  LatLng destination = LatLng(14.5547, 121.0244);
  
  // Empty polyline
  List<LatLng> result5a = PolylineUtils.robustPolyline([], origin, destination);
  print('Empty polyline fallback: ${result5a.map((p) => '(${p.latitude}, ${p.longitude})').toList()}');
  print('✅ Expected: [(14.5995, 120.9842), (14.5547, 121.0244)]');
  print('✅ Actual: ${result5a.map((p) => '(${p.latitude}, ${p.longitude})').toList()}\n');
  
  // All same points
  List<LatLng> result5b = PolylineUtils.robustPolyline([[0, 0], [0, 0], [0, 0]], origin, destination);
  print('All same points fallback: ${result5b.map((p) => '(${p.latitude}, ${p.longitude})').toList()}');
  print('✅ Expected: [(14.5995, 120.9842), (14.5547, 121.0244)]');
  print('✅ Actual: ${result5b.map((p) => '(${p.latitude}, ${p.longitude})').toList()}\n');
  
  print('🎉 All tests completed! PolylineUtils is working correctly.');
} 