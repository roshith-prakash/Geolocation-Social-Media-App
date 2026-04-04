import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../services/location_service.dart';
import '../services/supabase_service.dart';
import '../utils/constants.dart';
import '../widgets/post_marker_info.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'user_profile_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => MapScreenState();
}

class MapScreenState extends State<MapScreen> {
  final MapController mapController = MapController();
  final locationService = LocationService();
  final supabaseService = SupabaseService();

  LatLng? currentLatLng;
  List<PostModel> nearbyPosts = [];
  bool isLoading = true;
  double searchRadius = AppConstants.defaultRadiusMeters;

  // Simple list of radius options
  final List<double> radiusOptions = [500, 1000, 2000, 5000, 10000];

  @override
  void initState() {
    super.initState();
    initLocation();
  }

  Future<void> initLocation() async {
    try {
      final position = await locationService.getCurrentPosition();
      setState(() {
        currentLatLng = LatLng(position.latitude, position.longitude);
        isLoading = false;
      });
      loadNearbyPosts();
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> loadNearbyPosts() async {
    if (currentLatLng == null) return;
    try {
      final posts = await supabaseService.getNearbyPosts(
        latitude: currentLatLng!.latitude,
        longitude: currentLatLng!.longitude,
        radiusMeters: searchRadius,
      );
      setState(() {
        nearbyPosts = posts;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load posts: ${e.toString()}')),
        );
      }
    }
  }

  void showPostDetail(PostModel post) {
    showModalBottomSheet(
      context: context,
      builder: (context) => PostMarkerInfo(
        post: post,
        onAuthorTap: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => UserProfileScreen(userId: post.userId),
            ),
          );
        },
      ),
    );
  }

  String radiusLabel(double r) {
    if (r < 1000) return '${r.toInt()}m';
    return '${(r / 1000).toInt()} km';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Map (${nearbyPosts.length} posts)'),
        actions: [
          // Simple radius dropdown
          DropdownButton<double>(
            value: searchRadius,
            onChanged: (value) {
              if (value == null) return;
              setState(() => searchRadius = value);
              loadNearbyPosts();
            },
            items: radiusOptions.map((r) {
              return DropdownMenuItem(value: r, child: Text(radiusLabel(r)));
            }).toList(),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadNearbyPosts,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : currentLatLng == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_off, size: 64),
                      const SizedBox(height: 16),
                      const Text('Location unavailable', style: TextStyle(fontSize: 18)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: initLocation,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    FlutterMap(
                      mapController: mapController,
                      options: MapOptions(
                        initialCenter: currentLatLng!,
                        initialZoom: 15,
                        maxZoom: 18,
                        minZoom: 3,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.flashmap.social',
                        ),
                        MarkerLayer(
                          markers: nearbyPosts.map((post) {
                            return Marker(
                              point: LatLng(post.latitude, post.longitude),
                              width: 40,
                              height: 40,
                              child: GestureDetector(
                                onTap: () => showPostDetail(post),
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.blue,
                                  size: 40,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: currentLatLng!,
                              width: 20,
                              height: 20,
                              child: const Icon(
                                Icons.my_location,
                                color: Colors.blue,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // My location button
                    Positioned(
                      bottom: 24,
                      right: 16,
                      child: FloatingActionButton(
                        onPressed: () {
                          if (currentLatLng != null) {
                            mapController.move(currentLatLng!, 15);
                          }
                        },
                        child: const Icon(Icons.my_location),
                      ),
                    ),
                  ],
                ),
    );
  }
}
