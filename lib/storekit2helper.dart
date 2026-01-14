import 'package:flutter/services.dart';

// Enums matching StoreKit 2 types

enum SubscriptionPeriodUnit {
  day,
  week,
  month,
  year;

  static SubscriptionPeriodUnit fromString(String value) {
    switch (value.toLowerCase()) {
      case 'day':
        return SubscriptionPeriodUnit.day;
      case 'week':
        return SubscriptionPeriodUnit.week;
      case 'month':
        return SubscriptionPeriodUnit.month;
      case 'year':
        return SubscriptionPeriodUnit.year;
      default:
        return SubscriptionPeriodUnit.day;
    }
  }
}

enum PaymentMode {
  freeTrial,
  payAsYouGo,
  payUpFront,
  none;

  static PaymentMode fromString(String value) {
    switch (value.toLowerCase()) {
      case 'freetrial':
        return PaymentMode.freeTrial;
      case 'payasyougo':
        return PaymentMode.payAsYouGo;
      case 'payupfront':
        return PaymentMode.payUpFront;
      default:
        return PaymentMode.none;
    }
  }
}

enum OfferType {
  introductory,
  promotional,
  winBack,
  none;

  static OfferType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'introductory':
        return OfferType.introductory;
      case 'promotional':
        return OfferType.promotional;
      case 'winback':
        return OfferType.winBack;
      default:
        return OfferType.none;
    }
  }
}

enum ProductType {
  consumable,
  nonConsumable,
  nonRenewable,
  autoRenewable;

  static ProductType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'consumable':
        return ProductType.consumable;
      case 'nonconsumable':
        return ProductType.nonConsumable;
      case 'nonrenewable':
        return ProductType.nonRenewable;
      case 'autorenewable':
        return ProductType.autoRenewable;
      default:
        return ProductType.autoRenewable;
    }
  }
}

class SubscriptionOffer {
  final String? id;
  final OfferType type;
  final String displayPrice;
  final double price;
  final PaymentMode paymentMode;
  final SubscriptionPeriodUnit periodUnit;
  final int periodValue;
  final int periodCount;

  SubscriptionOffer({
    this.id,
    required this.type,
    required this.displayPrice,
    required this.price,
    required this.paymentMode,
    required this.periodUnit,
    required this.periodValue,
    required this.periodCount,
  });

  factory SubscriptionOffer.fromMap(Map<String, dynamic> map) {
    return SubscriptionOffer(
      id: map['id'] as String?,
      type: OfferType.fromString(map['type'] as String? ?? ''),
      displayPrice: map['displayPrice'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      paymentMode: PaymentMode.fromString(map['paymentMode'] as String? ?? ''),
      periodUnit: SubscriptionPeriodUnit.fromString(
          map['periodUnit'] as String? ?? 'day'),
      periodValue: map['periodValue'] as int? ?? 0,
      periodCount: map['periodCount'] as int? ?? 0,
    );
  }

  @override
  String toString() {
    final buffer = StringBuffer('SubscriptionOffer(');

    if (id != null && id!.isNotEmpty) {
      buffer.write('id: $id, ');
    }

    buffer.write('type: ${type.name}, ');
    buffer.write('displayPrice: $displayPrice, ');
    buffer.write('price: \$$price, ');
    buffer.write('paymentMode: ${paymentMode.name}, ');
    buffer.write('period: $periodValue ${periodUnit.name}');

    if (periodValue != 1) {
      buffer.write('s');
    }

    buffer.write(', periodCount: $periodCount');
    buffer.write(')');

    return buffer.toString();
  }
}

class PromotionalOfferPurchase {
  final String offerID;
  final String compactJWS;

  PromotionalOfferPurchase({
    required this.offerID,
    required this.compactJWS,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': offerID,
      'compactJWS': compactJWS,
    };
  }
}

class PurchaseOptions {
  final String? appAccountToken; // UUID string
  final PromotionalOfferPurchase? promotionalOffer;
  final SubscriptionOffer? winBackOffer;

  PurchaseOptions({
    this.appAccountToken,
    this.promotionalOffer,
    this.winBackOffer,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};

    if (appAccountToken != null) {
      map['appAccountToken'] = appAccountToken;
    }

    if (promotionalOffer != null) {
      map['promotionalOffer'] = promotionalOffer!.toMap();
    }

    if (winBackOffer != null) {
      map['winBackOffer'] = {
        'id': winBackOffer!.id,
        'type': winBackOffer!.type.name,
      };
    }

    return map;
  }
}

class Storekit2Helper {
  static const MethodChannel _channel = MethodChannel('storekit2helper');

  static Future initialize() async {
    await _channel.invokeMethod('initialize');
  }

  static Future<List<String>> fetchPurchaseHistory() async {
    List<dynamic> history = await _channel.invokeMethod('fetchPurchaseHistory');

    return history.cast<String>();
  }

  static Future<List<ProductDetail>> fetchProducts(
      List<String> productIDs) async {
    final List<dynamic> productList = await _channel
        .invokeMethod('fetchProducts', {"productIDs": productIDs});

    List<ProductDetail> products = [];
    for (var product in productList) {
      // Parse introductory offer if present
      SubscriptionOffer? introOffer;
      if (product['introductoryOffer'] != null) {
        introOffer = SubscriptionOffer.fromMap(
            Map<String, dynamic>.from(product['introductoryOffer']));
      }

      // Parse promotional offers
      List<SubscriptionOffer> promotionalOffers = [];
      if (product['promotionalOffers'] != null) {
        final List<dynamic> promoList = product['promotionalOffers'] as List;
        promotionalOffers = promoList
            .map((offer) =>
                SubscriptionOffer.fromMap(Map<String, dynamic>.from(offer)))
            .toList();
      }

      // Parse win-back offers
      List<SubscriptionOffer> winBackOffers = [];
      if (product['winBackOffers'] != null) {
        final List<dynamic> winBackList = product['winBackOffers'] as List;
        winBackOffers = winBackList
            .map((offer) =>
                SubscriptionOffer.fromMap(Map<String, dynamic>.from(offer)))
            .toList();
      }

      // Parse period unit if present
      SubscriptionPeriodUnit? periodUnit;
      if (product['periodUnit'] != null) {
        periodUnit = SubscriptionPeriodUnit.fromString(product['periodUnit']);
      }

      products.add(ProductDetail(
        description: product['description'],
        productId: product['productId'],
        title: product['title'],
        price: product['price'],
        localizedPrice: product['localizedPrice'],
        currencyCode: product['currencyCode'] ?? 'USD',
        type: ProductType.fromString(product['type']),
        json: product['json'],
        periodUnit: periodUnit,
        periodValue: product['periodValue'],
        periodTitle: product['periodTitle'],
        introductoryOffer: introOffer,
        promotionalOffers: promotionalOffers,
        winBackOffers: winBackOffers,
        isEligibleForIntroOffer: product['isEligibleForIntroOffer'],
      ));
    }
    return products;
  }

  static Future<void> buyProduct(
    String productId,
    void Function(bool success, Map<String, dynamic>? transaction,
            String? errorMessage)
        onResult, {
    PurchaseOptions? options,
  }) async {
    try {
      final arguments = <String, dynamic>{'productId': productId};

      // Add purchase options if provided
      if (options != null) {
        arguments.addAll(options.toMap());
      }

      final dynamic result =
          await _channel.invokeMethod('buyProduct', arguments);
      // Explicitly cast the result to Map<String, dynamic>
      final Map<String, dynamic>? resultMap = Map<String, dynamic>.from(result);
      // If successful, invoke the callback with success=true, the casted result, and no error message.
      onResult(true, resultMap, null);
    } on PlatformException catch (e) {
      // If there's a platform exception, invoke the callback with success=false, no transaction, and the error message.
      onResult(false, null, e.message);
    } catch (e) {
      // For any other type of error, invoke the callback with success=false, no transaction, and a generic error message.
      onResult(false, null, 'An unexpected error occurred. $e');
    }
  }

  static Future<bool> hasActiveSubscription() async {
    final bool hasSubscription =
        await _channel.invokeMethod('hasActiveSubscription');
    return hasSubscription;
  }
}

class ProductDetail {
  final String productId;
  final String title;
  final String description;
  final double price;
  final String localizedPrice;
  final String currencyCode; // ISO currency code (e.g., "USD", "EUR", "GBP")
  final ProductType type;
  final String json;
  final SubscriptionPeriodUnit? periodUnit;
  final int? periodValue;
  final String periodTitle;
  final SubscriptionOffer? introductoryOffer;
  final List<SubscriptionOffer> promotionalOffers;
  final List<SubscriptionOffer> winBackOffers;
  final bool isEligibleForIntroOffer;

  ProductDetail({
    required this.productId,
    required this.title,
    required this.description,
    required this.price,
    required this.localizedPrice,
    required this.currencyCode,
    required this.type,
    required this.json,
    this.periodUnit,
    this.periodValue,
    required this.periodTitle,
    this.introductoryOffer,
    this.promotionalOffers = const [],
    this.winBackOffers = const [],
    required this.isEligibleForIntroOffer,
  });

  bool get isTrial => introductoryOffer?.paymentMode == PaymentMode.freeTrial;

  bool get hasPromotionalOffers => promotionalOffers.isNotEmpty;

  bool get hasWinBackOffers => winBackOffers.isNotEmpty;

  List<SubscriptionOffer> get allOffers => [
        if (introductoryOffer != null) introductoryOffer!,
        ...promotionalOffers,
        ...winBackOffers,
      ];

  /// Returns the currency symbol for the currency code
  /// Falls back to the currency code if symbol is not found
  String get currencySymbol {
    const currencySymbols = {
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
      'JPY': '¥',
      'CNY': '¥',
      'AUD': 'A\$',
      'CAD': 'CA\$',
      'CHF': 'CHF',
      'SEK': 'kr',
      'NOK': 'kr',
      'DKK': 'kr',
      'INR': '₹',
      'RUB': '₽',
      'BRL': 'R\$',
      'ZAR': 'R',
      'MXN': 'MX\$',
      'KRW': '₩',
      'TRY': '₺',
      'PLN': 'zł',
      'THB': '฿',
      'IDR': 'Rp',
      'HUF': 'Ft',
      'CZK': 'Kč',
      'ILS': '₪',
      'CLP': 'CLP\$',
      'PHP': '₱',
      'AED': 'د.إ',
      'SAR': 'ر.س',
      'MYR': 'RM',
      'SGD': 'S\$',
      'NZD': 'NZ\$',
      'HKD': 'HK\$',
      'TWD': 'NT\$',
    };

    return currencySymbols[currencyCode] ?? currencyCode;
  }
}
