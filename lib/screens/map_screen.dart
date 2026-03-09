import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
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
  GoogleMapController? _mapController;
  final _locationService = LocationService();
  final _supabaseService = SupabaseService();

  Position? _currentPosition;
  Set<Marker> _markers = {};
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
        _currentPosition = position;
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
    if (_currentPosition == null) return;

    try {
      final posts = await _supabaseService.getNearbyPosts(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        radiusMeters: _searchRadius,
      );

      setState(() {
        _nearbyPosts = posts;
        _markers = _buildMarkers(posts);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load posts: ${e.toString()}')),
        );
      }
    }
  }

  Set<Marker> _buildMarkers(List<PostModel> posts) {
    return posts.map((post) {
      return Marker(
        markerId: MarkerId(post.id),
        position: LatLng(post.latitude, post.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
        onTap: () => _showPostDetail(post),
      );
    }).toSet();
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
          : _currentPosition == null
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
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(
                          _currentPosition!.latitude,
                          _currentPosition!.longitude,
                        ),
                        zoom: 15,
                      ),
                      onMapCreated: (controller) {
                        _mapController = controller;
                      },
                      style: _darkMapStyle,
                      markers: _markers,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                      circles: {
                        Circle(
                          circleId: const CircleId('search_radius'),
                          center: LatLng(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                          ),
                          radius: _searchRadius,
                          fillColor: AppTheme.accentCyan.withValues(alpha: 0.08),
                          strokeColor: AppTheme.accentCyan.withValues(alpha: 0.3),
                          strokeWidth: 1,
                        ),
                      },
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
                          if (_currentPosition != null) {
                            _mapController?.animateCamera(
                              CameraUpdate.newLatLng(LatLng(
                                _currentPosition!.latitude,
                                _currentPosition!.longitude,
                              )),
                            );
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

  // Dark-themed map JSON style
  static const String _darkMapStyle = '''[
    {"elementType":"geometry","stylers":[{"color":"#212121"}]},
    {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
    {"elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
    {"elementType":"labels.text.stroke","stylers":[{"color":"#212121"}]},
    {"featureType":"administrative","elementType":"geometry","stylers":[{"color":"#757575"}]},
    {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#181818"}]},
    {"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#2c2c2c"}]},
    {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#8a8a8a"}]},
    {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#373737"}]},
    {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#3c3c3c"}]},
    {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#2f3948"}]},
    {"featureType":"water","elementType":"geometry","stylers":[{"color":"#000000"}]},
    {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#3d3d3d"}]}
  ]''';
}
