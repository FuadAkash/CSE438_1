import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: BusTrackingScreen(),
    );
  }
}

class BusTrackingScreen extends StatefulWidget {
  @override
  _BusTrackingScreenState createState() => _BusTrackingScreenState();
}

class _BusTrackingScreenState extends State<BusTrackingScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late GoogleMapController _mapController; // Define the map controller
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  LatLng driverLocation = LatLng(23.8041, 90.4152); // Initialize with a default value


  late Timer _locationTimer;
  final Duration _locationUpdateInterval = const Duration(seconds: 3); // Update interval
  String username = ''; // Initialize username

  @override
  void initState() {
    super.initState();
    _fetchUsernameFromFirestore();
    _startLocationUpdates();

  }

  void _startLocationUpdates() {
    _locationTimer = Timer.periodic(_locationUpdateInterval, (timer) {
      _sendDriverLocationToDatabase();
    });
  }

  late double latitude = 23.8041; // Default value
  late double longitude = 90.4152; // Default value


  Future<void> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) {
        return Future.error(
            'Location permissions are permanently denied, we cannot request permissions.');
      }
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );
    latitude = position.latitude;
    longitude = position.longitude;
    setState(() {
      driverLocation = LatLng(latitude, longitude);
    });
  }

  Future<void> _sendDriverLocationToDatabase() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        getCurrentLocation();

        await _firestore
            .collection('DriverLocations')
            .doc(user.uid)
            .set({
          'location': GeoPoint(latitude, longitude),
          'email': user.email, // Add the user email
        });
        print('Driver location sent to Realtime Database: $latitude, $longitude');
      }
    } catch (e) {
      print('Error sending driver location: $e');
    }
  }


  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }



  Future<void> _fetchUsernameFromFirestore() async {
    final user = _auth.currentUser;
    if (user != null) {
      final userId = user.uid;
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (userDoc.exists) {
        setState(() {
          username = user.displayName ?? ''; // Use the display name from Google Sign-In
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Bus Tracking - $username"), // Include the username in the title
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: driverLocation,
          zoom: 14,
        ),
        markers: {
          Marker(
            markerId: MarkerId("driver - $username"),
            position: driverLocation,
            infoWindow: InfoWindow(title: "Driver's Location"),
          ),
        },
        onMapCreated: (controller) {
          _mapController = controller;
        },
      ),
    );
  }

}
