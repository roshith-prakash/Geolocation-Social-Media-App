import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';
import '../services/location_service.dart';
import '../services/supabase_service.dart';
import '../utils/constants.dart';
import '../widgets/post_marker_info.dart';
import '../widgets/user_avatar.dart';
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

  UserModel? currentUser;
  Set<String>? followingIds;

  @override
  void initState() {
    super.initState();
    initLocation();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final user = await supabaseService.getUserByFirebaseUid(uid);
      if (user != null) {
        final following = await supabaseService.getFollowing(user.id);
        if (mounted) {
          setState(() {
            currentUser = user;
            followingIds = following.map((u) => u.id).toSet();
          });
          // Reload to apply the filter if location was fetched first
          loadNearbyPosts();
        }
      }
    } catch (_) {}
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
        if (followingIds != null && currentUser != null) {
          nearbyPosts = posts.where((p) {
            return followingIds!.contains(p.userId) || p.userId == currentUser!.id;
          }).toList();
        } else {
          nearbyPosts = []; // Wait until following info is loaded
        }
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
                              width: 46,
                              height: 46,
                              child: GestureDetector(
                                onTap: () => showPostDetail(post),
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Theme.of(context).primaryColor, width: 2),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: UserAvatar(
                                    imageUrl: post.authorImage,
                                    username: post.authorUsername ?? 'User',
                                    radius: 20,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
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
