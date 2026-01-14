import Flutter
import StoreKit
import UIKit

public class Storekit2Plugin: NSObject, FlutterPlugin {

    let periodTitles = [
        "Day": "Weekly",
        "Week": "Weekly",
        "Month": "Monthly",
        "Year": "Yearly",
    ]

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "storekit2helper", binaryMessenger: registrar.messenger())
        let instance = Storekit2Plugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {

        case "initialize":
            Task {

                await result(StoreKit2Handler.initialize())
            }

        case "fetchPurchaseHistory":
            Task {
                await result(StoreKit2Handler.fetchPurchaseHistory())
            }

        case "hasActiveSubscription":
            Task {
                let hasSubscription = await StoreKit2Handler.hasActiveSubscription()
                result(hasSubscription)
            }

        case "fetchProducts":
            if let args = call.arguments as? [String: Any],
                let productIDs = args["productIDs"] as? [String]
            {

                StoreKit2Handler.fetchProducts(productIdentifiers: productIDs) { fetchResult in
                    switch fetchResult {
                    case .success(let products):
                        // Convert products to a format that can be sent back to Flutter
                        // Need to use Task to handle async isEligibleForIntroOffer
                        Task {
                            var productDetails: [[String: Any]] = []

                            for product in products {
                                // Helper function to convert period unit to string
                                func periodUnitToString(
                                    _ unit: Product.SubscriptionPeriod.Unit
                                ) -> String {
                                    switch unit {
                                    case .day: return "day"
                                    case .week: return "week"
                                    case .month: return "month"
                                    case .year: return "year"
                                    @unknown default: return "day"
                                    }
                                }

                                // Helper function to convert product type to string
                                func productTypeToString(_ type: Product.ProductType) -> String {
                                    switch type {
                                    case .consumable: return "consumable"
                                    case .nonConsumable: return "nonConsumable"
                                    case .nonRenewable: return "nonRenewable"
                                    case .autoRenewable: return "autoRenewable"
                                    default: return "autoRenewable"
                                    }
                                }

                                // Helper function to convert payment mode to string
                                func paymentModeToString(
                                    _ mode: Product.SubscriptionOffer.PaymentMode
                                ) -> String {
                                    switch mode {
                                    case .freeTrial: return "freeTrial"
                                    case .payAsYouGo: return "payAsYouGo"
                                    case .payUpFront: return "payUpFront"
                                    default: return "payAsYouGo"
                                    }
                                }

                                // Helper function to convert offer type to string
                                func offerTypeToString(
                                    _ type: Product.SubscriptionOffer.OfferType
                                ) -> String {
                                    if #available(iOS 18.0, *) {
                                        switch type {
                                        case .introductory: return "introductory"
                                        case .promotional: return "promotional"
                                        case .winBack: return "winBack"
                                        default: return "introductory"
                                        }
                                    } else {
                                        switch type {
                                        case .introductory: return "introductory"
                                        case .promotional: return "promotional"
                                        default: return "introductory"
                                        }
                                    }
                                }

                                let periodUnit = periodUnitToString(
                                    product.subscription?.subscriptionPeriod.unit
                                        ?? Product.SubscriptionPeriod.Unit.day)

                                var data: [String: Any] = [
                                    "productId": product.id,
                                    "title": product.displayName,
                                    "description": product.description,
                                    "price": product.price,
                                    "periodUnit": periodUnit,
                                    "periodValue": product.subscription?.subscriptionPeriod.value
                                        ?? 0,
                                    "periodTitle": self.periodTitles[periodUnit] ?? "",
                                    "json": String(
                                        data: product.jsonRepresentation, encoding: .utf8) ?? "",
                                    "localizedPrice": product.displayPrice,
                                    "currencyCode": product.priceFormatStyle.currencyCode,
                                    "type": productTypeToString(product.type),
                                    "isEligibleForIntroOffer": await
                                        (product.subscription?
                                        .isEligibleForIntroOffer ?? false),
                                ]

                                // Helper function to serialize an offer
                                func serializeOffer(_ offer: Product.SubscriptionOffer)
                                    -> [String: Any]
                                {
                                    let offerPeriodUnit = periodUnitToString(offer.period.unit)
                                    return [
                                        "id": offer.id ?? "",
                                        "type": offerTypeToString(offer.type),
                                        "displayPrice": offer.displayPrice,
                                        "price": offer.price,
                                        "paymentMode": paymentModeToString(offer.paymentMode),
                                        "periodUnit": offerPeriodUnit,
                                        "periodValue": offer.period.value,
                                        "periodCount": offer.periodCount,
                                    ] as [String: Any]
                                }

                                // Add introductory offer details if available
                                if let introOffer = product.subscription?.introductoryOffer {
                                    data["introductoryOffer"] = serializeOffer(introOffer)
                                }

                                // Add promotional offers if available
                                if let subscription = product.subscription {
                                    let promoOffers = subscription.promotionalOffers.map {
                                        serializeOffer($0)
                                    }
                                    data["promotionalOffers"] = promoOffers
                                }

                                // Add win-back offers if available (iOS 18.0+)
                                if #available(iOS 18.0, *) {
                                    if let subscription = product.subscription {
                                        let winBackOffers = subscription.winBackOffers.map {
                                            serializeOffer($0)
                                        }
                                        data["winBackOffers"] = winBackOffers
                                    }
                                }

                                productDetails.append(data)
                            }

                            result(productDetails)
                        }
                    case .failure(let error):
                        result(
                            FlutterError(
                                code: "PRODUCT_FETCH_ERROR", message: error.localizedDescription,
                                details: nil))
                    }
                }
            } else {
                result(
                    FlutterError(
                        code: "INVALID_ARGUMENTS", message: "Missing productIDs", details: nil))
            }

        case "buyProduct":
            if let args = call.arguments as? [String: Any],
                let productId = args["productId"] as? String
            {
                // Parse purchase options if provided
                Task {
                    var purchaseOptions = Set<Product.PurchaseOption>()

                    // Parse app account token
                    if let uuidString = args["appAccountToken"] as? String,
                        let uuid = UUID(uuidString: uuidString)
                    {
                        purchaseOptions.insert(.appAccountToken(uuid))
                    }

                    // Parse promotional offer with JWS signature
                    if let promoOfferData = args["promotionalOffer"] as? [String: Any],
                        let offerId = promoOfferData["id"] as? String,
                        let compactJWS = promoOfferData["compactJWS"] as? String
                    {
                        // Use the promotional offer with JWS signature for validation
                        let promoOptions = Product.PurchaseOption.promotionalOffer(
                            offerId,  // First parameter has no label (underscore in signature)
                            compactJWS: compactJWS
                        )

                        // Insert all promotional offer options
                        for option in promoOptions {
                            purchaseOptions.insert(option)
                        }
                    }

                    // Parse win-back offer (iOS 18.0+)
                    if #available(iOS 18.0, *) {
                        if let winBackOfferData = args["winBackOffer"] as? [String: Any],
                            let offerId = winBackOfferData["id"] as? String
                        {
                            // Fetch the product to get the actual offer
                            if let products = try? await Product.products(for: [productId]),
                                let product = products.first,
                                let subscription = product.subscription
                            {
                                if let offer = subscription.winBackOffers.first(where: {
                                    $0.id == offerId
                                }) {
                                    purchaseOptions.insert(.winBackOffer(offer))
                                }
                            }
                        }
                    }

                    let options = purchaseOptions.isEmpty ? nil : purchaseOptions

                    StoreKit2Handler.buyProduct(productId: productId, purchaseOptions: options) {
                        success, error, transaction in

                        if success {
                            // Assuming transaction is not nil if success is true
                            let transactionDetails: [String: Any] = [
                                "transactionId": transaction!.id,
                                "productId": transaction!.productID,
                                "appBundleID": transaction!.appBundleID,
                                "purchaseDate": Int(
                                    transaction!.purchaseDate.timeIntervalSince1970),
                                "json": String(
                                    data: transaction!.jsonRepresentation, encoding: .utf8)
                                    ?? "",

                            ]

                            result(transactionDetails)
                        } else {

                            let errorCode = "PURCHASE_ERROR"
                            let errorMessage = error?.localizedDescription ?? "error"

                            result(
                                FlutterError(code: errorCode, message: errorMessage, details: nil))
                        }
                    }
                }
            } else {
                result(
                    FlutterError(
                        code: "INVALID_ARGUMENTS", message: "Missing productId", details: nil))
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }

}
