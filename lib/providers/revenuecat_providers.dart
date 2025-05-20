import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter/services.dart'; // Import for PlatformException

// Provider to fetch RevenueCat offerings
final offeringsProvider = FutureProvider<Offerings>((ref) async {
  try {
    final offerings = await Purchases.getOfferings();
    return offerings;
  } on PlatformException catch (e) {
    // Log the detailed error from RevenueCat
    print("RevenueCat PlatformException fetching offerings: ${e.code} - ${e.message} - ${e.details}");
    // Provide a more user-friendly error message
    throw Exception("Could not load subscription options. Please check your connection and try again.");
  } catch (e) {
    print("Unexpected error fetching offerings: $e");
    throw Exception("An unexpected error occurred while loading options.");
  }
}); 