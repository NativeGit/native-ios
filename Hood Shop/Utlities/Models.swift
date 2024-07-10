import Foundation
import SwiftUI
import CoreLocation
import UIKit
import StripePaymentsUI

struct Courier: Identifiable, Codable {
    var id: String
    var name: String
    var email: String
    var phone: String
    var password: String
}

struct OrderDetail {
    var quantity: Int
    var productName: String
    var price: Double
}

enum DetentType {
    case mediumLargeFull, mediumLarge, customHeight(CGFloat)
}

enum SheetMode {
    case collection, delivery
}

struct Order: Equatable, Hashable, Identifiable {
    struct LifecycleEvent: Codable, Equatable, Hashable {
        var action: String
        var value: String
        var timestamp: String
    }

    var id: String { orderId }
    var orderId: String
    var customerName: String
    var postcode: String
    var address: String
    var pickupTime: String
    var deliveryTime: String
    var status: Int
    var packed: Int
    var phone: String
    var total: Double
    var icon: String
    var pickupImageUrl: String?
    var deliveryImageUrl: String?
    var allocatedTime: String
    var pickupETA: String
    var courierId: String
    var courierName: String
    var courierPhone: String?
    var lifecycle: String
    var images: String?

    init(orderId: String = "",
         customerName: String = "",
         postcode: String = "",
         address: String = "",
         pickupTime: String = "",
         deliveryTime: String = "",
         status: Int = 0,
         packed: Int = 0,
         phone: String = "",
         total: Double = 0.0,
         icon: String = "",
         pickupImageUrl: String? = nil,
         deliveryImageUrl: String? = nil,
         allocatedTime: String = "",
         pickupETA: String = "",
         courierId: String = "",
         courierName: String = "",
         courierPhone: String? = nil,
         lifecycle: String = "",
         images: String? = nil) {
        self.orderId = orderId
        self.customerName = customerName
        self.postcode = postcode
        self.address = address
        self.pickupTime = pickupTime
        self.deliveryTime = deliveryTime
        self.status = status
        self.packed = packed
        self.phone = phone
        self.total = total
        self.icon = icon
        self.pickupImageUrl = pickupImageUrl
        self.deliveryImageUrl = deliveryImageUrl
        self.allocatedTime = allocatedTime
        self.pickupETA = pickupETA
        self.courierId = courierId
        self.courierName = courierName
        self.courierPhone = courierPhone
        self.lifecycle = lifecycle
        self.images = images
    }

    func getLifecycleEvent(for action: String) -> LifecycleEvent? {
        let trimmedAction = action.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let lifecycleEvents = lifecycle.split(separator: ",").compactMap { event -> LifecycleEvent? in
            let components = event.split(separator: "*").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard components.count >= 2 else { return nil }
            return LifecycleEvent(action: components[0], value: components.count == 3 ? components[1] : "", timestamp: components.last!)
        }
        return lifecycleEvents.first { $0.action.lowercased() == trimmedAction }
    }
}

struct LifecycleEvent: Decodable {
    let action: String
    let value: String
    let timestamp: String
}

struct Admin: Equatable, Codable {
    let id: String
    let name: String

    static func == (lhs: Admin, rhs: Admin) -> Bool {
        lhs.id == rhs.id
    }
}

enum Field: Hashable {
    case postcode, street, building, floor, apartment, instructions, phone, name, email, password, voucher
}

struct Chat: Identifiable, Codable, Hashable {
    var id: String
    let customerName: String
    var lastMessage: String
    var date: Date
    var unseenMessages: Int
    let icon: String
    let customerId: String
    let phone: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Chat, rhs: Chat) -> Bool {
        lhs.id == rhs.id
    }

    var formattedDate: String {
        let calendar = Calendar.current
        let formatter = DateFormatter()

        if calendar.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if let daysAgo = calendar.dateComponents([.day], from: date, to: Date()).day, daysAgo <= 7 {
            formatter.dateFormat = "EEEE"
        } else {
            formatter.dateFormat = "dd/MM/yyyy"
        }
        return formatter.string(from: date)
    }
}

struct Message: Identifiable, Equatable {
    let id: String
    let text: String
    let timestamp: Date
    let isUser: Bool
}

struct ImageData {
    var name: String
    var imageName: String
    var price: String
    var amount: Int = 1
    var liked: Bool = false
    var description: String
    var lastUpdated: Date = Date()
    var category: String
    var options: [Option] = []
}

struct Category: Identifiable {
    let id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

class Product: ObservableObject, Identifiable, Equatable {
    let id: Int
    @Published var name: String
    @Published var description: String
    @Published var price: Double
    @Published var imageURL: String
    @Published var status: Int
    @Published var category: String
    @Published var updatedImage: UIImage?
    @Published var liked: Bool = false
    @Published var lastUpdated: Date = Date()
    @Published var options: [Option] = []
    @Published var amount: Int = 1
    @Published var basketId: String?

    init(id: Int, name: String, description: String, price: Double, imageURL: String, status: Int, category: String, updatedImage: UIImage? = nil, liked: Bool = false, lastUpdated: Date = Date(), options: [Option] = [], amount: Int = 1, basketId: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.price = price
        self.imageURL = imageURL
        self.status = status
        self.category = category
        self.updatedImage = updatedImage
        self.liked = liked
        self.lastUpdated = lastUpdated
        self.options = options
        self.amount = amount
        self.basketId = basketId
    }

    static func == (lhs: Product, rhs: Product) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.description == rhs.description &&
        lhs.price == rhs.price &&
        lhs.imageURL == rhs.imageURL &&
        lhs.status == rhs.status &&
        lhs.category == rhs.category &&
        lhs.updatedImage == rhs.updatedImage &&
        lhs.liked == rhs.liked &&
        lhs.lastUpdated == rhs.lastUpdated &&
        lhs.amount == rhs.amount &&
        lhs.basketId == rhs.basketId &&
        lhs.options == rhs.options
    }
}

class Option: ObservableObject, Identifiable, Equatable {
    let id: UUID
    let name: String
    let price: Double
    let type: OptionType
    var valueMax: Int?
    @Published var isSelected: Bool
    
    init(id: UUID = UUID(), name: String, price: Double, type: OptionType, valueMax: Int? = nil, isSelected: Bool = false) {
        self.id = id
        self.name = name
        self.price = price
        self.type = type
        self.valueMax = valueMax
        self.isSelected = isSelected
    }
    
    static func == (lhs: Option, rhs: Option) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.price == rhs.price &&
        lhs.type == rhs.type &&
        lhs.valueMax == rhs.valueMax
    }
}

enum OptionType {
    case option, addition
}

struct GooglePlacesResponse: Decodable {
    let predictions: [Prediction]
}

struct Prediction: Decodable {
    let description: String
}

func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

struct Payment: Identifiable, Codable, Equatable {
    let id: String
    var brand: String
    let last4: String
    var isDefault: Bool = false
}

struct Address: Identifiable, Codable, Equatable {
    let id = UUID()
    var street, building, postcode, name, phone: String
    var isDefault = false
    var lat, lng: Double

    func distanceToShop() -> Double {
        let shopLocation = CLLocation(latitude: assets.coordinate.latitude, longitude: assets.coordinate.longitude)
        let addressLocation = CLLocation(latitude: lat, longitude: lng)
        return addressLocation.distance(from: shopLocation) / 1609.34
    }
}

struct OpeningHours {
    var open, close: String
}

enum DeliveryOption: String, CaseIterable {
    case delivery = "Delivery"
    case pickup = "Pickup"
}

struct ProductItem {
    let id: String
    let amount: Int
    let imageName: String
    let name: String
    let price: Double
    let description: String
    let status: String
    let options: [Option]
    let category: String
    let nextDay: String
    let minHour: String
}

struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}
