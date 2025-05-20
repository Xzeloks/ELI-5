import 'package:eli5/main.dart'; // For AppColors
import 'package:eli5/providers/revenuecat_provider.dart';
import 'package:eli5/screens/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart'; // Ensure intl is imported
import 'package:eli5/utils/snackbar_helper.dart'; // ADDED

final _logger = Logger('PaywallScreen');

// It's good practice to define your entitlement ID as a constant
const String premiumEntitlementId = 'Access'; // As per your screenshot
const String hasSeenPaywallKey = 'hasSeenPaywall';


class PaywallScreen extends ConsumerStatefulWidget {
  final VoidCallback onContinueToApp;

  const PaywallScreen({super.key, required this.onContinueToApp});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  Package? _selectedPackage;
  bool _isPurchasing = false;
  bool _isRestoring = false;

  String _getCurrencySymbol(String currencyCode) {
    switch (currencyCode.toUpperCase()) {
      case 'TRY':
        return '₺';
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      // Add other common currency codes and their symbols here
      default:
        return currencyCode; // Fallback to the code if symbol is not defined
    }
  }

  Future<void> _markPaywallAsSeenAndContinue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(hasSeenPaywallKey, true);
    widget.onContinueToApp(); // This will trigger AuthGate to rebuild and show AppShell
    // No explicit navigation needed from here if AuthGate handles it.
    // if (mounted) {
    //   Navigator.of(context).pushReplacementNamed(AppShell.routeName); // REMOVE THIS
    // }
  }

  Future<void> _purchasePackage(Package packageToPurchase) async {
    if (_isPurchasing) return;
    setState(() {
      _isPurchasing = true;
    });

    try {
      _logger.info(
          'Attempting to purchase package: ${packageToPurchase.identifier}');
      CustomerInfo customerInfo =
          await Purchases.purchasePackage(packageToPurchase);
      ref.invalidate(customerInfoProvider);

      _logger.info(
          'Purchase successful for ${packageToPurchase.identifier}. CustomerInfo entitlements: ${customerInfo.entitlements.active.keys.join(', ')}');

      if (customerInfo.entitlements.active.containsKey(premiumEntitlementId)) {
        _logger.info(
            'Entitlement "$premiumEntitlementId" is active. Navigating to app.');
        if (mounted) {
          showStyledSnackBar(context, message: 'Purchase successful! Welcome to Premium.');
        }
        await _markPaywallAsSeenAndContinue();
      } else {
        _logger.warning(
            'Entitlement "$premiumEntitlementId" is NOT active after purchase. This should not happen.');
        if (mounted) {
          showStyledSnackBar(context, message: 'Purchase completed, but entitlement not active. Please restore purchases or contact support.', duration: const Duration(seconds: 5));
        }
      }
    } on PlatformException catch (e) {
      _logger.severe('Purchase failed for ${packageToPurchase.identifier}. Code: ${e.code}, Message: ${e.message}', e);
      var errorCode = PurchasesErrorHelper.getErrorCode(e);
      String message;

      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        message = 'Purchase cancelled.';
      } else if (errorCode == PurchasesErrorCode.paymentPendingError) { 
        if (mounted) {
          showStyledSnackBar(context, message: "Payment Pending: Your payment is pending. You'll get access once it's confirmed.", duration: const Duration(seconds: 5));
        }
        setState(() => _isPurchasing = false);
        return; 
      } else if (errorCode == PurchasesErrorCode.productAlreadyPurchasedError) {
        message = 'You already own this product. Restoring purchases...';
         // Attempt to restore and check entitlement again
        await _restorePurchases(showMessages: false); // Suppress messages as we'll show one based on outcome
        final currentCustomerInfo = await Purchases.getCustomerInfo();
        if (currentCustomerInfo.entitlements.active.containsKey(premiumEntitlementId)) {
           if (mounted) {
            showStyledSnackBar(context, message: 'Subscription restored! Welcome back.');
           }
          await _markPaywallAsSeenAndContinue();
          setState(() => _isPurchasing = false); // Ensure loading state is cleared
          return; // Exit as we've handled it
        } else {
           message = 'Product already owned, but failed to activate. Please try restoring purchases again.';
        }
      } else {
        message = 'Purchase failed: ${e.message} (Code: ${e.code})';
      }
      
      if (mounted) {
        showStyledSnackBar(context, message: message, isError: true, duration: const Duration(seconds: 5));
      }
    } catch (e) {
      _logger.severe('An unexpected error occurred during purchase for ${packageToPurchase.identifier}', e);
      if (mounted) {
        showStyledSnackBar(context, message: 'An unexpected error occurred: ${e.toString()}', isError: true, duration: const Duration(seconds: 5));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
        });
      }
    }
  }

  Future<void> _restorePurchases({bool showMessages = true}) async {
    if (_isRestoring) return;
    setState(() {
      _isRestoring = true;
    });
    try {
      CustomerInfo customerInfo = await Purchases.restorePurchases();
      ref.invalidate(customerInfoProvider);

      _logger.info('Restore purchases completed. Active entitlements: ${customerInfo.entitlements.active.keys.join(', ')}');
      if (customerInfo.entitlements.active.containsKey(premiumEntitlementId)) {
        if (showMessages && mounted) {
          showStyledSnackBar(context, message: 'Purchases restored successfully!');
        }
        await _markPaywallAsSeenAndContinue();
      } else {
        if (showMessages && mounted) {
          showStyledSnackBar(context, message: 'No active premium subscription found to restore.');
        }
      }
    } on PlatformException catch (e) {
       _logger.severe('Failed to restore purchases. Code: ${e.code}, Message: ${e.message}', e);
      if (showMessages && mounted) {
        showStyledSnackBar(context, message: 'Failed to restore purchases: ${e.message}', isError: true, duration: const Duration(seconds: 5));
      }
    } catch (e) {
       _logger.severe('An unexpected error occurred during restore', e);
       if (showMessages && mounted) {
        showStyledSnackBar(context, message: 'An unexpected error occurred: ${e.toString()}', isError: true, duration: const Duration(seconds: 5));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRestoring = false;
        });
      }
    }
  }
  
  String _formatPeriod(String? periodISO, {bool forSubtitle = false}) {
    if (periodISO == null || periodISO.isEmpty) return '';
    // RevenueCat period format: P1M, P7D, P1Y etc.
    try {
      if (periodISO.startsWith('P')) {
        String valueString = '';
        String unitChar = '';

        int firstDigitIndex = -1;
        for(int i=1; i< periodISO.length; i++){
            if(RegExp(r'[0-9]').hasMatch(periodISO[i])){
                firstDigitIndex = i;
                break;
            }
        }
        if(firstDigitIndex == -1) return periodISO; 

        int unitCharIndex = -1;
         for(int i=firstDigitIndex; i< periodISO.length; i++){
            if(RegExp(r'[A-Z]').hasMatch(periodISO[i])){
                unitCharIndex = i;
                break;
            }
        }
        if(unitCharIndex == -1) return periodISO;

        valueString = periodISO.substring(firstDigitIndex, unitCharIndex);
        unitChar = periodISO.substring(unitCharIndex, unitCharIndex + 1);
        
        int numValue = int.tryParse(valueString) ?? 0;
        if (numValue == 0) return periodISO;

        String unitText = '';
        switch (unitChar) {
          case 'D': unitText = numValue == 1 ? 'day' : 'days'; break;
          case 'W': unitText = numValue == 1 ? 'week' : 'weeks'; break;
          case 'M': unitText = numValue == 1 ? 'month' : 'months'; break;
          case 'Y': unitText = numValue == 1 ? 'year' : 'years'; break;
          default:
             _logger.warning('Unrecognized period unit: $unitChar in $periodISO');
            return periodISO;
        }
        return forSubtitle ? '$numValue $unitText' : unitText;
      }
    } catch (e) {
      _logger.warning('Could not parse period string: $periodISO', e);
    }
    _logger.warning('Unrecognized period format (does not start with P or parsing error): $periodISO');
    return periodISO;
  }


  Widget _buildPackageSelector(BuildContext context, List<Package> packages) {
    final theme = Theme.of(context);

    // Create a modifiable copy of the list before sorting
    final modifiablePackages = List<Package>.from(packages);

    // Sort packages: Monthly, SixMonth, Annual, then others.
    modifiablePackages.sort((a, b) { // Sort the modifiable copy
      int getOrder(PackageType type) {
        switch (type) {
          case PackageType.annual: return 0; // Changed to 0 for top
          case PackageType.sixMonth: return 1; // Stays 1
          case PackageType.monthly: return 2; // Changed to 2 for bottom
          default: return 3;
        }
      }
      return getOrder(a.packageType).compareTo(getOrder(b.packageType));
    });


    return Column(
      children: modifiablePackages.map((package) { // Iterate over the sorted modifiable copy
        final storeProduct = package.storeProduct;
        final isSelected = package == _selectedPackage;

        // START: Enhanced logging for ALL packages
        _logger.info("------------ Package Details for: ${package.identifier} ------------");
        _logger.info("Package Type: ${package.packageType}");
        _logger.info("StoreProduct Title: ${storeProduct.title}");
        _logger.info("StoreProduct Desc: ${storeProduct.description}");
        _logger.info("StoreProduct Price: ${storeProduct.priceString} (${storeProduct.price})");
        _logger.info("StoreProduct Currency: ${storeProduct.currencyCode}");
        _logger.info("StoreProduct Sub Period: ${storeProduct.subscriptionPeriod}");
        
        if (storeProduct.introductoryPrice != null) {
          final intro = storeProduct.introductoryPrice!;
          _logger.info("Introductory Price (${package.identifier} - ${package.packageType}): ${intro.priceString} (${intro.price}) for ${intro.period} (${intro.periodUnit} ${intro.periodNumberOfUnits})");
          _logger.info("Introductory Price Cycles (${package.identifier} - ${package.packageType}): ${intro.cycles}");
        } else {
          _logger.info("--- Introductory Price (${package.identifier} - ${package.packageType}): None found (null) ---");
        }
        _logger.info("------------ End Package Details for: ${package.identifier} ------------");
        // END: Enhanced logging for ALL packages


        String titleText;
        String subtitleText;
        // String priceDisplayForButton = storeProduct.priceString; // Default for button - will be set by _getButtonPriceDisplay

        // Construct title based on package type
        switch (package.packageType) {
          case PackageType.monthly:
            titleText = 'Monthly';
            break;
          case PackageType.annual:
            titleText = 'Annual';
            break;
          case PackageType.sixMonth:
            titleText = '6 Months';
            break;
          case PackageType.threeMonth:
            titleText = '3 Months';
            break;
          case PackageType.twoMonth:
            titleText = '2 Months';
            break;
          case PackageType.weekly:
            titleText = 'Weekly';
            break;
          case PackageType.lifetime:
             titleText = 'Lifetime';
             break;
          default:
            titleText = storeProduct.title.isNotEmpty ? storeProduct.title : package.identifier;
        }

        final trialPeriodString = storeProduct.introductoryPrice?.period; 
        final introPriceDetails = storeProduct.introductoryPrice;
        final isMonthlyWithTrial = package.packageType == PackageType.monthly && introPriceDetails?.price == 0;
        String trialDurationText = "";
        if (isMonthlyWithTrial && trialPeriodString != null) {
          // Example: P7D -> 7 days, P1M -> 1 month
          if (trialPeriodString == "P7D") {
            trialDurationText = "7 Days Free";
          } else {
            // Fallback for other trial durations
            trialDurationText = "${_formatPeriod(trialPeriodString, forSubtitle: true)} Free";
          }
        }
        
        final price = storeProduct.price;
        String displayPriceString;
        
        NumberFormat currencyFormat = NumberFormat.currency(
          name: storeProduct.currencyCode.isNotEmpty ? storeProduct.currencyCode : null,
          symbol: _getCurrencySymbol(storeProduct.currencyCode),
          decimalDigits: storeProduct.currencyCode.toUpperCase() == 'TRY' ? 0 : null
        );

        switch (package.packageType) {
          case PackageType.annual:
            displayPriceString = '${currencyFormat.format(price / 12)}/month';
            break;
          case PackageType.sixMonth:
            displayPriceString = '${currencyFormat.format(price / 6)}/month';
            break;
          case PackageType.threeMonth:
            displayPriceString = '${currencyFormat.format(price / 3)}/month';
            break;
          case PackageType.twoMonth:
            displayPriceString = '${currencyFormat.format(price / 2)}/month';
            break;
          case PackageType.monthly:
            displayPriceString = '${currencyFormat.format(price)}/month';
            break;
          case PackageType.weekly:
            displayPriceString = '${currencyFormat.format(price)}/week'; 
            break;
          case PackageType.lifetime:
            displayPriceString = currencyFormat.format(price); // Lifetime is a one-time payment, already formatted
            break;
          default:
            final formattedPeriodUnit = _formatPeriod(storeProduct.subscriptionPeriod, forSubtitle: false);
            displayPriceString = storeProduct.subscriptionPeriod != null && storeProduct.subscriptionPeriod!.isNotEmpty
                                   ? '${currencyFormat.format(price)}/${formattedPeriodUnit.isNotEmpty ? formattedPeriodUnit : _getPackageTypePeriod(package.packageType)}'
                                   : currencyFormat.format(price); // Fallback to formatted price if period unknown
        }
        // priceDisplayForButton will be handled by _getButtonPriceDisplay

        if (trialPeriodString != null && trialPeriodString.isNotEmpty && introPriceDetails?.price == 0) {
          String formattedTrialPeriod = _formatPeriod(trialPeriodString, forSubtitle: true);
          subtitleText = '$formattedTrialPeriod free trial, then $displayPriceString';
          if (package.packageType == PackageType.monthly) { 
             titleText = 'Monthly + $formattedTrialPeriod Free Trial';
          }
        } else if (introPriceDetails != null) {
           NumberFormat introCurrencyFormat = NumberFormat.currency(
             name: storeProduct.currencyCode.isNotEmpty ? storeProduct.currencyCode : null,
             symbol: _getCurrencySymbol(storeProduct.currencyCode),
             decimalDigits: storeProduct.currencyCode.toUpperCase() == 'TRY' ? 0 : null
           );
           String introPriceFormatted = introCurrencyFormat.format(introPriceDetails.price);
           String introPeriodFormatted = _formatPeriod(introPriceDetails.period, forSubtitle: true); 
           subtitleText = '$introPriceFormatted for $introPeriodFormatted, then $displayPriceString';
        } else {
          subtitleText = displayPriceString;
        }
        
        if (package.packageType == PackageType.annual) {
            Package? monthlyPackage;
            try {
                monthlyPackage = packages.firstWhere((p) => p.packageType == PackageType.monthly);
            } catch (e) { /* Monthly package not found */ }

            if (monthlyPackage != null) {
                final monthlyProductPrice = monthlyPackage.storeProduct.price; 
                final annualProductPrice = storeProduct.price;
                if (monthlyProductPrice > 0 && annualProductPrice > 0) {
                    final twelveMonthEquivalentPrice = monthlyProductPrice * 12;
                    if (twelveMonthEquivalentPrice > annualProductPrice) { 
                        final discount = ((twelveMonthEquivalentPrice - annualProductPrice) / twelveMonthEquivalentPrice * 100).round();
                        if (discount > 0) { 
                           titleText = 'Annual (Save $discount%)';
                        }
                    }
                }
            }
        } else if (package.packageType == PackageType.sixMonth) { // ADDED FOR 6-MONTH PLAN
            Package? monthlyPackage;
            try {
                monthlyPackage = packages.firstWhere((p) => p.packageType == PackageType.monthly);
            } catch (e) { /* Monthly package not found */ }

            if (monthlyPackage != null) {
                final monthlyProductPrice = monthlyPackage.storeProduct.price;
                final sixMonthProductPrice = storeProduct.price;
                if (monthlyProductPrice > 0 && sixMonthProductPrice > 0) {
                    final sixMonthEquivalentPrice = monthlyProductPrice * 6;
                    if (sixMonthEquivalentPrice > sixMonthProductPrice) {
                        final discount = ((sixMonthEquivalentPrice - sixMonthProductPrice) / sixMonthEquivalentPrice * 100).round();
                        if (discount > 0) {
                           titleText = '6 Months (Save $discount%)';
                        }
                    }
                }
            }
        }

        return Card(
          elevation: isSelected ? 8 : 1,
          shadowColor: isSelected ? AppColors.kopyaPurple.withOpacity(0.6) : Colors.grey.withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected ? AppColors.kopyaPurple : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          child: RadioListTile<Package>(
            value: package,
            groupValue: _selectedPackage,
            onChanged: (Package? value) {
              if (mounted) {
                setState(() {
                  _selectedPackage = value;
                });
              }
            },
            title: Text(titleText, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            subtitle: Text(
              subtitleText,
              style: theme.textTheme.bodyMedium?.copyWith(color: isSelected ? AppColors.kopyaPurple : theme.colorScheme.onSurfaceVariant),
            ),
            activeColor: AppColors.kopyaPurple,
            controlAffinity: ListTileControlAffinity.trailing,
            secondary: isSelected ? Icon(Icons.check_circle, color: AppColors.kopyaPurple) : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFeatureItem(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, color: AppColors.kopyaPurple, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }

  // Helper to get a fallback period string from PackageType
  String _getPackageTypePeriod(PackageType packageType) {
    switch (packageType) {
      case PackageType.monthly: return 'month';
      case PackageType.annual: return 'year';
      case PackageType.weekly: return 'week';
      case PackageType.sixMonth: return '6 months'; // Or handle more granularly if needed
      case PackageType.threeMonth: return '3 months';
      case PackageType.twoMonth: return '2 months';
      case PackageType.lifetime: return 'lifetime';
      default: return '';
    }
  }

  // Helper function for button price display
  String _getButtonPriceDisplay(Package package) {
    final storeProduct = package.storeProduct;
    final price = storeProduct.price;
    
    NumberFormat currencyFormat = NumberFormat.currency(
      name: storeProduct.currencyCode.isNotEmpty ? storeProduct.currencyCode : null,
      symbol: _getCurrencySymbol(storeProduct.currencyCode),
      decimalDigits: storeProduct.currencyCode.toUpperCase() == 'TRY' ? 0 : null
    );

    switch (package.packageType) {
      case PackageType.annual:
        return '${currencyFormat.format(price / 12)}/month';
      case PackageType.sixMonth:
        return '${currencyFormat.format(price / 6)}/month';
      case PackageType.threeMonth:
        return '${currencyFormat.format(price / 3)}/month';
      case PackageType.twoMonth:
        return '${currencyFormat.format(price / 2)}/month';
      case PackageType.monthly:
        return '${currencyFormat.format(price)}/month';
      case PackageType.weekly:
        return '${currencyFormat.format(price)}/week';
      case PackageType.lifetime:
        return currencyFormat.format(price);
      default:
        final formattedPeriodUnit = _formatPeriod(storeProduct.subscriptionPeriod, forSubtitle: false);
        return storeProduct.subscriptionPeriod != null && storeProduct.subscriptionPeriod!.isNotEmpty
                ? '${currencyFormat.format(price)}/${formattedPeriodUnit.isNotEmpty ? formattedPeriodUnit : _getPackageTypePeriod(package.packageType)}'
                : currencyFormat.format(price);
    }
  }

  Widget _buildErrorView(BuildContext context, String error) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
            const SizedBox(height: 20),
            Text(
              'Something Went Wrong',
              style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.onSurface),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'We had trouble loading subscription options. Please check your connection and try again.\nError details: $error',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              onPressed: () {
                // Invalidate to refetch offerings
                ref.invalidate(offeringsProvider);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.kopyaPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildNoOfferingsView(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 60, color: Colors.grey),
            const SizedBox(height: 20),
            Text(
              'No Subscription Plans Available',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'We couldn\'t load any subscription plans at the moment. Please check your internet connection and try again. If the problem persists, please contact support.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              onPressed: () {
                ref.invalidate(offeringsProvider);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.kopyaPurple,
                foregroundColor: Colors.white,
              ),
            )
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final offeringsAsyncValue = ref.watch(offeringsProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: offeringsAsyncValue.when(
          data: (offerings) {
            final currentOffering = offerings.current;
            if (currentOffering == null || currentOffering.availablePackages.isEmpty) {
              _logger.warning('No current offering or no available packages found.');
              return _buildNoOfferingsView(context);
            }
            final packages = currentOffering.availablePackages;
            
            if (_selectedPackage == null && packages.isNotEmpty) {
                Package? yearly, monthly;
                for (var p in packages) {
                    if (p.packageType == PackageType.annual) yearly = p;
                    if (p.packageType == PackageType.monthly) monthly = p;
                }
                final defaultSelection = yearly ?? monthly ?? packages.first;

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _selectedPackage == null) { 
                    // Check mounted and if _selectedPackage is still null
                    // to prevent calling setState if it's already been set or widget is disposed
                    setState(() {
                       _selectedPackage = defaultSelection;
                    });
                  }
                });
                // Set for the first build pass to prevent _selectedPackage being null in UI elements
                // if addPostFrameCallback hasn't run yet.
                 _selectedPackage ??= defaultSelection; // Used null-aware assignment
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Image.asset(
                      'assets/icon/icon-bg.png', 
                      height: 160, // Doubled icon size
                      errorBuilder: (context, error, stackTrace) {
                        _logger.warning('Failed to load app icon: assets/icon/icon-bg.png', error, stackTrace);
                        return const Icon(Icons.broken_image_outlined, size: 80, color: Colors.grey);
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Unlock ELI-5',
                    style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Get unlimited access to all features and simplify complex topics effortlessly.',
                    style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  if (packages.isNotEmpty) _buildPackageSelector(context, packages)
                  else const Center(child: Text("Loading plans...")), // Placeholder if packages somehow empty here
                  const SizedBox(height: 32),
                  Text(
                    "WHAT'S INCLUDED",
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 0.8,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureItem(context, FeatherIcons.zap, 'Unlimited Simplifications & Explanations'),
                  _buildFeatureItem(context, FeatherIcons.barChart2, 'Access to Advanced AI Models'),
                  _buildFeatureItem(context, FeatherIcons.award, 'Priority Support & Early Access to New Features'),
                  _buildFeatureItem(context, FeatherIcons.bookOpen, 'Expanded Content Library'), 
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: _selectedPackage == null || _isPurchasing || _isRestoring
                        ? null
                        : () => _purchasePackage(_selectedPackage!),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.kopyaPurple,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isPurchasing
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                          )
                        : Builder( // Added Builder to create a new scope for selected package checks
                            builder: (context) {
                              if (_selectedPackage == null) {
                                return const Text("Select a plan", style: TextStyle(color: Colors.white));
                              }
                              final selectedStoreProduct = _selectedPackage!.storeProduct;
                              final selectedIntroPriceDetails = selectedStoreProduct.introductoryPrice;
                              final selectedIsMonthlyWithTrial = _selectedPackage!.packageType == PackageType.monthly && selectedIntroPriceDetails?.price == 0;
                              String selectedTrialDurationText = "";

                              if (selectedIsMonthlyWithTrial && selectedIntroPriceDetails?.period != null) {
                                if (selectedIntroPriceDetails!.period == "P7D") {
                                  selectedTrialDurationText = "7 Days Free";
                                } else {
                                  selectedTrialDurationText = "${_formatPeriod(selectedIntroPriceDetails.period, forSubtitle: true)} Free";
                                }
                              }

                              return Text(
                                selectedIsMonthlyWithTrial
                                  ? selectedTrialDurationText.isNotEmpty ? 'Try $selectedTrialDurationText' : 'Try For Free'
                                  : 'Continue with ${_getButtonPriceDisplay(_selectedPackage!)}',
                                style: const TextStyle(color: Colors.white)
                              );
                            }
                          ),
                  ),
                  // START: Add Annual Saver Button
                  Builder(
                    builder: (context) {
                      Package? annualPackage;
                      Package? monthlyPackage;
                      int annualDiscountPercent = 0;

                      for (var pkg in packages) {
                        if (pkg.packageType == PackageType.annual) {
                          annualPackage = pkg;
                        }
                        if (pkg.packageType == PackageType.monthly) {
                          monthlyPackage = pkg;
                        }
                      }

                      if (annualPackage != null && monthlyPackage != null) {
                        final monthlyPrice = monthlyPackage.storeProduct.price;
                        final annualPrice = annualPackage.storeProduct.price;
                        if (monthlyPrice > 0 && annualPrice > 0) {
                          final twelveMonthEquivalentPrice = monthlyPrice * 12;
                          if (twelveMonthEquivalentPrice > annualPrice) {
                            annualDiscountPercent = ((twelveMonthEquivalentPrice - annualPrice) / twelveMonthEquivalentPrice * 100).round();
                          }
                        }
                      }

                      if (annualPackage == null) {
                        return const SizedBox.shrink(); // Don't show if no annual package
                      }

                      String buttonText = annualDiscountPercent > 0 
                          ? 'Save $annualDiscountPercent% with Annual' 
                          : 'Choose Annual Plan';

                      return Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: ElevatedButton(
                          onPressed: _isPurchasing || _isRestoring 
                              ? null 
                              : () {
                                  if (mounted) {
                                    setState(() {
                                      _selectedPackage = annualPackage; 
                                    });
                                  }
                                  _purchasePackage(annualPackage!); 
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color.lerp(AppColors.kopyaPurple, Colors.black, 0.25), // Darker purple
                            padding: const EdgeInsets.symmetric(vertical: 16), // Matched main button's vertical padding
                            textStyle: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold), // Matched main button's textStyle
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // Matched main button's shape
                          ),
                          child: Text(buttonText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), // Explicitly set fontWeight to bold like typical button text
                        ),
                      );
                    }
                  ),
                  // END: Add Annual Saver Button
                  const SizedBox(height: 20),
                  Center(
                    child: _isRestoring
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.kopyaPurple),
                          )
                        : TextButton(
                            onPressed: _isPurchasing ? null : _restorePurchases,
                            child: Text(
                              'Restore Purchases',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                decoration: TextDecoration.underline, 
                                decorationColor: theme.colorScheme.primary,
                                decorationThickness: 1.5
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.kopyaPurple)),
          error: (error, stackTrace) {
            _logger.severe('Error loading offerings in PaywallScreen build', error, stackTrace);
            return _buildErrorView(context, error.toString());
          },
        ),
      ),
    );
  }
}