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

Promotional offers require a JWS (JSON Web Signature) from your server to validate the offer. This ensures security and prevents unauthorized use of promotional offers.

**Simple example (just need offer ID):**
```dart
// You only need the offer ID - no need for the full SubscriptionOffer object
final offerId = 'your_promo_offer_id'; // e.g., "summer_2024_promo"

// Get JWS from your server
final jwsSignature = await yourBackend.getPromotionalOfferJWS(
  productId: 'your.subscription.id',
  offerId: offerId,
  userId: currentUserId,
);

// Create the promotional offer purchase with both fields
final promoOffer = PromotionalOfferPurchase(
  offerID: offerId,
  compactJWS: jwsSignature,
);

final options = PurchaseOptions(
  promotionalOffer: promoOffer,
);

await Storekit2Helper.buyProduct(
  'your.subscription.id',
  (success, transaction, errorMessage) {
    if (success) {
      print('Purchase with promotional offer successful!');
    } else {
      print('Purchase failed: $errorMessage');
    }
  },
  options: options,
);
```

**Or fetch available offers first:**
```dart
// Optionally, fetch the product to see available promotional offers
final products = await Storekit2Helper.fetchProducts(['your.subscription.id']);
final product = products.first;

// Select a promotional offer
if (product.hasPromotionalOffers) {
  final promoOffer = product.promotionalOffers.first;
  
  // IMPORTANT: Get the JWS signature from your backend server
  // Your server must generate this using Apple's signing requirements
  // See: https://developer.apple.com/documentation/storekit/in-app_purchase/original_api_for_in-app_purchase/subscriptions_and_offers/generating_a_signature_for_promotional_offers
  final jwsSignature = await yourBackend.getPromotionalOfferJWS(
    productId: product.productId,
    offerId: promoOffer.id!,
    userId: currentUserId,
  );
  
  // Create the promotional offer purchase
  final promoOfferPurchase = PromotionalOfferPurchase(
    offerID: promoOffer.id!,
    compactJWS: jwsSignature, // Required for validation
  );
  
  // Create purchase options
  final options = PurchaseOptions(
    promotionalOffer: promoOfferPurchase,
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

#### Generating JWS Signatures (Server-Side)

Your backend server must generate the JWS signature using:
- **App Bundle ID**: Your app's bundle identifier
- **Product Identifier**: The subscription product ID
- **Offer Identifier**: The promotional offer ID
- **Application Username**: Optional user identifier
- **Nonce**: A UUID for this transaction
- **Timestamp**: Current timestamp in milliseconds

The signature must be created using your **Subscription Key** from App Store Connect and signed with ES256 algorithm.

**Example server-side implementation (Node.js):**
```javascript
const jwt = require('jsonwebtoken');
const fs = require('fs');

function generatePromotionalOfferJWS(params) {
  const privateKey = fs.readFileSync('SubscriptionKey.p8');
  
  const payload = {
    iss: 'YOUR_ISSUER_ID',
    iat: Math.floor(Date.now() / 1000),
    bid: params.bundleId,
    pid: params.productId,
    oid: params.offerId,
    aud: 'appstoreconnect-v1',
    nonce: params.nonce,
    uid: params.userId, // optional
  };
  
  const token = jwt.sign(payload, privateKey, {
    algorithm: 'ES256',
    keyid: 'YOUR_KEY_ID',
  });
  
  return token;
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
  
  // Get JWS from your server
  final jwsSignature = await yourBackend.getPromotionalOfferJWS(
    productId: product.productId,
    offerId: promoOffer.id!,
    userId: userUuid,
  );
  
  // Create the promotional offer purchase
  final promoOfferPurchase = PromotionalOfferPurchase(
    offerID: promoOffer.id!,
    compactJWS: jwsSignature,
  );
  
  final options = PurchaseOptions(
    promotionalOffer: promoOfferPurchase,
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
- **Require JWS signature from your server** for security
- Must pass both offer and JWS as purchase options
- Access via `product.promotionalOffers` list
- See [Generating a Signature for Promotional Offers](https://developer.apple.com/documentation/storekit/in-app_purchase/original_api_for_in-app_purchase/subscriptions_and_offers/generating_a_signature_for_promotional_offers)

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

## Security for Promotional Offers

### Why JWS Signatures Are Required

Promotional offers require server-side JWS (JSON Web Signature) validation to:
- **Prevent fraud**: Ensures only authorized users can apply promotional offers
- **Validate authenticity**: Proves the offer request comes from your backend
- **Link to users**: Associates the offer with a specific user account
- **Audit trail**: Provides server-side tracking of who received which offers

### Important Security Notes

⚠️ **Never generate JWS signatures on the client side**
- Your subscription key must remain on your server
- Client-side generation would expose your private key
- This would allow anyone to apply any promotional offer

✅ **Server-side generation requirements:**
1. Store your Subscription Key (`.p8` file) securely on your server
2. Generate JWS using the ES256 algorithm
3. Include all required claims (iss, iat, bid, pid, oid, aud, nonce)
4. Use a unique nonce (UUID) for each signature
5. Optionally include application username (uid) to link to user

✅ **Testing in Sandbox:**
- Use your sandbox Subscription Key from App Store Connect
- Test with sandbox Apple IDs
- Verify signatures are validated correctly
- Check that invalid signatures are rejected

### JWS Signature Claims

Required claims for promotional offer signatures:

| Claim | Description | Example |
|-------|-------------|---------|
| `iss` | Issuer ID from App Store Connect | `"69a6de7d-..."` |
| `iat` | Issued at timestamp (seconds) | `1704985200` |
| `bid` | App bundle identifier | `"com.example.app"` |
| `pid` | Product identifier | `"com.example.monthly"` |
| `oid` | Offer identifier | `"promo_summer_2024"` |
| `aud` | Audience (always this value) | `"appstoreconnect-v1"` |
| `nonce` | Unique UUID for this signature | `"a1b2c3d4-..."` |
| `uid` | Application username (optional) | `"user123"` |

### Example Server Implementation (Python with PyJWT)

```python
import jwt
import time
import uuid
from pathlib import Path

def generate_promotional_offer_jws(
    product_id: str,
    offer_id: str,
    bundle_id: str,
    user_id: str = None
):
    # Load your subscription key from App Store Connect
    key_path = Path("SubscriptionKey_ABC123DEF.p8")
    with open(key_path, 'r') as f:
        private_key = f.read()
    
    # Your credentials from App Store Connect
    KEY_ID = "ABC123DEF"  # Key ID
    ISSUER_ID = "69a6de7d-..."  # Issuer ID
    
    # Build the payload
    payload = {
        "iss": ISSUER_ID,
        "iat": int(time.time()),
        "bid": bundle_id,
        "pid": product_id,
        "oid": offer_id,
        "aud": "appstoreconnect-v1",
        "nonce": str(uuid.uuid4()),
    }
    
    # Optionally include user ID
    if user_id:
        payload["uid"] = user_id
    
    # Generate the JWS
    token = jwt.encode(
        payload,
        private_key,
        algorithm="ES256",
        headers={"kid": KEY_ID}
    )
    
    return token
```

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

