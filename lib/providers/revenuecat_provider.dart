import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

// Provider to fetch CustomerInfo
final customerInfoProvider = FutureProvider<CustomerInfo>((ref) async {
  try {
    return await Purchases.getCustomerInfo();
  } catch (e) {
    // Handle exceptions, e.g., log them or return a specific error state
    print('Error fetching CustomerInfo: $e');
    rethrow; // Rethrow to let the UI handle the error state
  }
});

// Provider to fetch Offerings
final offeringsProvider = FutureProvider<Offerings>((ref) async {
  try {
    return await Purchases.getOfferings();
  } catch (e) {
    print('Error fetching offerings: $e');
    rethrow;
  }
});

// You can also add a provider for checking a specific entitlement if you have one
// For example, if your premium entitlement is called "premium":
// final isSubscribedProvider = Provider<bool>((ref) {
//   final customerInfoAsyncValue = ref.watch(customerInfoProvider);
//   return customerInfoAsyncValue.when(
//     data: (customerInfo) {
//       return customerInfo.entitlements.all['your_premium_entitlement_id']?.isActive ?? false;
//       // Replace 'your_premium_entitlement_id' with your actual entitlement ID from RevenueCat
//     },
//     loading: () => false, // Or some other default while loading
//     error: (_, __) => false, // Or some other default on error
//   );
// }); 