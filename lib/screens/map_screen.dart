import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/post_model.dart';
import '../services/location_service.dart';
import '../services/supabase_service.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';
import '../widgets/post_marker_info.dart';
import 'user_profile_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final _locationService = LocationService();
  final _supabaseService = SupabaseService();

  LatLng? _currentLatLng;
  List<PostModel> _nearbyPosts = [];
  bool _isLoading = true;
  double _searchRadius = AppConstants.defaultRadiusMeters;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      final position = await _locationService.getCurrentPosition();
      setState(() {
        _currentLatLng = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });
      _loadNearbyPosts();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _loadNearbyPosts() async {
    if (_currentLatLng == null) return;

    try {
      final posts = await _supabaseService.getNearbyPosts(
        latitude: _currentLatLng!.latitude,
        longitude: _currentLatLng!.longitude,
        radiusMeters: _searchRadius,
      );

      setState(() {
        _nearbyPosts = posts;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load posts: ${e.toString()}')),
        );
      }
    }
  }

  void _showPostDetail(PostModel post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => PostMarkerInfo(
        post: post,
        onAuthorTap: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => UserProfileScreen(userId: post.userId),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore Map'),
        actions: [
          // Radius selector
          PopupMenuButton<double>(
            icon: const Icon(Icons.tune, color: AppTheme.accentCyan),
            color: AppTheme.surfaceDark,
            onSelected: (radius) {
              setState(() => _searchRadius = radius);
              _loadNearbyPosts();
            },
            itemBuilder: (context) => [
              _radiusMenuItem(500, '500m'),
              _radiusMenuItem(1000, '1 km'),
              _radiusMenuItem(2000, '2 km'),
              _radiusMenuItem(5000, '5 km'),
              _radiusMenuItem(10000, '10 km'),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.accentCyan),
            onPressed: _loadNearbyPosts,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.accentCyan),
            )
          : _currentLatLng == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_off,
                          size: 64, color: AppTheme.textMuted),
                      const SizedBox(height: 16),
                      const Text(
                        'Location unavailable',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 18),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _initLocation,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _currentLatLng!,
                        initialZoom: 15,
                        maxZoom: 18,
                        minZoom: 3,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                          subdomains: const ['a', 'b', 'c', 'd'],
                          userAgentPackageName: 'com.flashmap.social',
                        ),
                        CircleLayer(
                          circles: [
                            CircleMarker(
                              point: _currentLatLng!,
                              radius: _searchRadius,
                              useRadiusInMeter: true,
                              color: AppTheme.accentCyan.withValues(alpha: 0.08),
                              borderColor: AppTheme.accentCyan.withValues(alpha: 0.3),
                              borderStrokeWidth: 1,
                            ),
                          ],
                        ),
                        MarkerLayer(
                          markers: _nearbyPosts.map((post) {
                            return Marker(
                              point: LatLng(post.latitude, post.longitude),
                              width: 40,
                              height: 40,
                              child: GestureDetector(
                                onTap: () => _showPostDetail(post),
                                child: const Icon(
                                  Icons.location_on,
                                  color: AppTheme.accentCyan,
                                  size: 40,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _currentLatLng!,
                              width: 20,
                              height: 20,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Post count badge
                    Positioned(
                      top: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceDark.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: AppTheme.borderDark, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.pin_drop,
                                size: 16, color: AppTheme.accentCyan),
                            const SizedBox(width: 6),
                            Text(
                              '${_nearbyPosts.length} posts nearby',
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // My location button
                    Positioned(
                      bottom: 24,
                      right: 16,
                      child: FloatingActionButton.small(
                        backgroundColor: AppTheme.surfaceDark,
                        onPressed: () {
                          if (_currentLatLng != null) {
                            _mapController.move(_currentLatLng!, 15);
                          }
                        },
                        child: const Icon(Icons.my_location,
                            color: AppTheme.accentCyan),
                      ),
                    ),
                  ],
                ),
    );
  }

  PopupMenuItem<double> _radiusMenuItem(double value, String label) {
    return PopupMenuItem<double>(
      value: value,
      child: Row(
        children: [
          Icon(
            _searchRadius == value
                ? Icons.radio_button_checked
                : Icons.radio_button_off,
            color: AppTheme.accentCyan,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: AppTheme.textPrimary)),
        ],
      ),
    );
  }
}
