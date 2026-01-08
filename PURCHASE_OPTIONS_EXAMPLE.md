# Purchase Options Example

This document shows how to use purchase options with StoreKit2Helper, including win-back offers, promotional offers, and app account tokens.

## Overview

Purchase options allow you to:
- Apply **promotional offers** to a subscription purchase
- Apply **win-back offers** to re-engage lapsed subscribers (iOS 18.0+)
- Associate an **app account token** (UUID) with a purchase for linking to your backend

## Basic Usage

### 1. Fetch Products and Their Offers

```dart
// Fetch products with all available offers
final products = await Storekit2Helper.fetchProducts(['your.subscription.id']);

for (var product in products) {
  print('Product: ${product.title}');
  print('Price: ${product.localizedPrice}');
  
  // Check available offers
  if (product.introductoryOffer != null) {
    print('Has introductory offer: ${product.introductoryOffer!.displayPrice}');
  }
  
  if (product.hasPromotionalOffers) {
    print('Promotional offers: ${product.promotionalOffers.length}');
    for (var offer in product.promotionalOffers) {
      print('  - ${offer.displayPrice} (${offer.paymentMode})');
    }
  }
  
  if (product.hasWinBackOffers) {
    print('Win-back offers: ${product.winBackOffers.length}');
    for (var offer in product.winBackOffers) {
      print('  - ${offer.displayPrice} (${offer.paymentMode})');
    }
  }
}
```

### 2. Purchase Without Options (Standard Purchase)

```dart
await Storekit2Helper.buyProduct(
  'your.subscription.id',
  (success, transaction, errorMessage) {
    if (success) {
      print('Purchase successful!');
      print('Transaction ID: ${transaction!['transactionId']}');
    } else {
      print('Purchase failed: $errorMessage');
    }
  },
);
```

### 3. Purchase With Promotional Offer

```dart
// First, fetch the product to get available promotional offers
final products = await Storekit2Helper.fetchProducts(['your.subscription.id']);
final product = products.first;

// Select a promotional offer
if (product.hasPromotionalOffers) {
  final promoOffer = product.promotionalOffers.first;
  
  // Create purchase options with the promotional offer
  final options = PurchaseOptions(
    promotionalOffer: promoOffer,
  );
  
  // Execute purchase with options
  await Storekit2Helper.buyProduct(
    product.productId,
    (success, transaction, errorMessage) {
      if (success) {
        print('Purchase with promotional offer successful!');
        print('Applied offer: ${promoOffer.displayPrice}');
      } else {
        print('Purchase failed: $errorMessage');
      }
    },
    options: options,
  );
}
```

### 4. Purchase With Win-Back Offer (iOS 18.0+)

```dart
// Fetch products with win-back offers
final products = await Storekit2Helper.fetchProducts(['your.subscription.id']);
final product = products.first;

// Check if win-back offers are available
if (product.hasWinBackOffers) {
  final winBackOffer = product.winBackOffers.first;
  
  // Create purchase options with the win-back offer
  final options = PurchaseOptions(
    winBackOffer: winBackOffer,
  );
  
  // Execute purchase with win-back offer
  await Storekit2Helper.buyProduct(
    product.productId,
    (success, transaction, errorMessage) {
      if (success) {
        print('Win-back purchase successful!');
        print('Applied offer: ${winBackOffer.displayPrice}');
      } else {
        print('Purchase failed: $errorMessage');
      }
    },
    options: options,
  );
}
```

### 5. Purchase With App Account Token

```dart
import 'package:uuid/uuid.dart';

// Generate or retrieve your user's UUID
final userUuid = Uuid().v4(); // Or get from your backend

// Create purchase options with app account token
final options = PurchaseOptions(
  appAccountToken: userUuid,
);

// Execute purchase with app account token
await Storekit2Helper.buyProduct(
  'your.subscription.id',
  (success, transaction, errorMessage) {
    if (success) {
      print('Purchase successful with account token!');
      // You can now link this transaction to your user via the UUID
    } else {
      print('Purchase failed: $errorMessage');
    }
  },
  options: options,
);
```

### 6. Purchase With Multiple Options

```dart
// Combine multiple purchase options
final products = await Storekit2Helper.fetchProducts(['your.subscription.id']);
final product = products.first;

if (product.hasPromotionalOffers) {
  final promoOffer = product.promotionalOffers.first;
  final userUuid = 'your-user-uuid-from-backend';
  
  final options = PurchaseOptions(
    promotionalOffer: promoOffer,
    appAccountToken: userUuid,
  );
  
  await Storekit2Helper.buyProduct(
    product.productId,
    (success, transaction, errorMessage) {
      if (success) {
        print('Purchase with promo offer and account token successful!');
      } else {
        print('Purchase failed: $errorMessage');
      }
    },
    options: options,
  );
}
```

## Understanding Offer Types

### Introductory Offers
- Automatically available to new subscribers
- Checked via `product.isEligibleForIntroOffer`
- Applied automatically if eligible (no need to pass as option)
- Access via `product.introductoryOffer`

### Promotional Offers
- Configured in App Store Connect
- Can be applied to new or existing subscribers
- Require passing as a purchase option
- Access via `product.promotionalOffers` list

### Win-Back Offers (iOS 18.0+)
- Designed to re-engage lapsed subscribers
- Only available on iOS 18.0 and later
- Require passing as a purchase option
- Access via `product.winBackOffers` list

## Offer Details

Each `SubscriptionOffer` includes:
```dart
class SubscriptionOffer {
  final String? id;                          // Offer identifier
  final OfferType type;                      // introductory, promotional, winBack
  final String displayPrice;                 // Localized price string (e.g., "$0.99")
  final double price;                        // Decimal price value
  final PaymentMode paymentMode;             // freeTrial, payAsYouGo, payUpFront
  final SubscriptionPeriodUnit periodUnit;   // day, week, month, year
  final int periodValue;                     // Number of period units
  final int periodCount;                     // Number of renewal periods
}
```

## Best Practices

1. **Always fetch fresh product data** before showing offers to users
2. **Check offer eligibility** before displaying offer UI
3. **Handle platform differences** - win-back offers are iOS 18.0+ only
4. **Use app account tokens** to link transactions to your backend users
5. **Test thoroughly** in sandbox and TestFlight before production
6. **Handle errors gracefully** - purchases can fail for many reasons

## Error Handling

```dart
await Storekit2Helper.buyProduct(
  productId,
  (success, transaction, errorMessage) {
    if (success) {
      // Success - transaction is guaranteed to be non-null
      handleSuccessfulPurchase(transaction!);
    } else {
      // Failed - errorMessage contains details
      if (errorMessage?.contains('User cancelled') == true) {
        // User explicitly cancelled
        showMessage('Purchase cancelled');
      } else if (errorMessage?.contains('Product not found') == true) {
        // Product ID invalid or not available
        showError('Product unavailable');
      } else {
        // Other error
        showError('Purchase failed: $errorMessage');
      }
    }
  },
  options: options,
);
```

