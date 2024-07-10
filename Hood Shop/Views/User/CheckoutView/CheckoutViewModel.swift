import SwiftUI
import PassKit
import CoreLocation
import GoogleSignIn
import GoogleSignInSwift

class CheckoutViewModel: ObservableObject {
    @Published var isScheduleLaterSelected = false
    @Published var selectedDate = initializeSelectedDate()
    @Published var selectedTime = initializeSelectedTime()
    @Published var freeDelivery = true
    @Published var shopModel = ShopModel()
    @Published var selectedLanguage = UserDefaults.standard.string(forKey: "SelectedLanguage") ?? "EN"
    @Published var selectedOption: DeliveryOption = UserDefaults.standard.string(forKey: "selectedOption").flatMap { DeliveryOption(rawValue: $0) } ?? .delivery
    @Published var freeAbove = 0.0
    @Published var total = 0.0
    @Published var distance = 0.0
    @Published var zone = 0
    @Published var defaultAddress: Address?
    @Published var showingAddressesSheet = false
    @Published var navigateToTracker = false
    @Published var showingCard = false
    @Published var showingVoucher = false
    @Published var showingCardsSheet = false
    @Published var showingDeliveryAddressFullScreen = false
    @Published var showTimeSheet = false
    @Published var showingLoginSheet = false
    @Published var isImageLargeItemViewClicked = false
    @Published var isLoggedIn = false
    @Published var showingBasketSheet = false
    @Published var showOrderView = false
    @Published var stripe: UIViewController?
    @Published var sheetHeight: CGFloat = 200
    @Published var cards: [Payment] = []
    @Published var selectedPaymentMethod: Payment? = nil
    @Published var discount = 0.0
    @Published var profileImageURL: URL? = nil
    @Published var orderId = UserDefaults.standard.string(forKey: "orderId")
    @Published var selectedCourierId = ""
    @Published var currentOrder = Order()
    @Published var addresses: [Address] = []
    var loginManager: LoginManager

    init(shopModel: ShopModel) {
        self.shopModel = shopModel
        self.loginManager = LoginManager(shopModel: shopModel)
    }

    func handleSignInButton() {
        loginManager.handleSignInButton()
    }

    var dynamicHeight: CGFloat {
        CGFloat(shopModel.basket.count) * 66 + 100
    }

    var filteredBasketCount: Int {
        shopModel.basket.filter { $0.amount > 0 }.count
    }

    func onAppear() {
        self.stripe = Stripe()
        checkCookies()
        updateScheduleSelected()
        loadAddresses()
        loadCards()
        if !self.isLoggedIn && shouldShowLoginSheet() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.showingLoginSheet = true
            }
        }
    }

    func checkCookies() {
        if let emailCookie = loadCookie(name: "userEmail"),
           let profileImageCookie = loadCookie(name: "profileImageURL"),
           let url = URL(string: profileImageCookie) {
            self.profileImageURL = url
            self.isLoggedIn = true
        }
    }

    func updateScheduleSelected() {
        let expirationTimestamp = UserDefaults.standard.double(forKey: "scheduleExpirationTimestamp")
        if Date().timeIntervalSince1970 < expirationTimestamp {
            self.isScheduleLaterSelected = true
        }
    }

    func loadAddresses() {
        if let savedAddressesData = UserDefaults.standard.data(forKey: "SavedAddresses"),
           let loadedAddresses = try? JSONDecoder().decode([Address].self, from: savedAddressesData) {
            self.addresses = loadedAddresses
            if !self.addresses.isEmpty {
                self.addresses[0].isDefault = true
                self.defaultAddress = self.addresses[0]
                checkDeliveryRangeForDefaultAddress()
            }
        }
    }

    func checkDeliveryRangeForDefaultAddress() {
        if let defaultAddress = self.addresses.first(where: { $0.isDefault }) {
            self.distance = defaultAddress.distanceToShop()
            self.zone = Int(self.distance.rounded(.down))
            let fee = mopedPriceForZone(fromDistance: self.distance)
            self.freeAbove = fee / 0.2
        }
    }

    func shouldShowLoginSheet() -> Bool {
        let hasShownLoginSheet = UserDefaults.standard.bool(forKey: "hasShownLoginSheet")
        if !hasShownLoginSheet {
            UserDefaults.standard.set(true, forKey: "hasShownLoginSheet")
        }
        return !hasShownLoginSheet
    }

    var displayText: String {
        let expirationTimestamp = UserDefaults.standard.double(forKey: "scheduleExpirationTimestamp")
        let currentTimestamp = Date().timeIntervalSince1970

        if currentTimestamp < expirationTimestamp,
           let scheduledDateTime = UserDefaults.standard.string(forKey: "scheduledDateTime") {
            self.isScheduleLaterSelected = true
            return scheduledDateTime
        } else if self.isScheduleLaterSelected {
            return formattedDate(self.selectedDate, time: self.selectedTime)
        } else if !self.addresses.isEmpty {
            let deliveryTimeMin = 30 + (self.zone * 10)
            let deliveryTimeMax = deliveryTimeMin + 10
            return self.selectedOption == .delivery ? "Within \(deliveryTimeMin)-\(deliveryTimeMax) min" : "Pickup in 15-20 min"
        } else {
            return self.selectedOption == .delivery ? "As Soon As Possible" : "Pickup in 15-20 min"
        }
    }

    var deliveryFee: Double {
        guard self.defaultAddress != nil else {
            return 0
        }
        
        var fee = mopedPriceForZone(fromDistance: self.distance)
        if self.freeDelivery {
            fee -= self.shopModel.subtotal * 0.2
        }
        if self.selectedOption == .pickup {
            fee = 0
        }
        return max(fee, 0)
    }


    func mopedPriceForZone(fromDistance distance: Double) -> Double {
        let prices = self.priceDataArray[self.zone].split(separator: "-").compactMap { Double($0) }
        return prices.count > 1 ? prices[1] : 0.0
    }

    var priceDataArray: [String] {
        self.priceDataString.split(separator: "|").map { String($0) }
    }

    var priceDataString = "0-6.0-12.6-18.0|1-6.0-12.6-18.0|2-8.7-16.04-21.7|3-12.5-16.04-21.7|4-14.06-17.67-23.5|5-17.12-22.01-28.3|6-21.28-26.08-32.8|7-22.39-26.08-32.8|8-24.36-29.6-36.7|9-26.3-34.76-42.4|10-28.3-34.76-42.4|11-30.26-37.47-45.4|12-31.8-40.18-48.4|13-33.34-43.46-51.88|14-34.88-44.73-53.22|15-36.41-47.46-56.1|16-37.95-48.38-57.06|17-39.48-50.39-59.18|18-41.02-52.4-61.29|19-42.56-53.85-62.82|20-42.56-53.85-62.82"

    func loadCards() {
        if let savedCardsData = UserDefaults.standard.data(forKey: "SavedCards"),
           let loadedCards = try? JSONDecoder().decode([Payment].self, from: savedCardsData) {
            self.cards = loadedCards
            self.selectedPaymentMethod = self.cards.first(where: { $0.isDefault }) ?? nil
        }
    }

    func loadCookie(name: String) -> String? {
        HTTPCookieStorage.shared.cookies?.first(where: { $0.name == name })?.value
    }

    static func initializeSelectedTime() -> Date {
        let currentDate = Date()
        let currentHour = Calendar.current.component(.hour, from: currentDate)
        let currentMinute = Calendar.current.component(.minute, from: currentDate)
        let additionalHour = currentMinute > 0 ? 1 : 0
        return Calendar.current.date(bySettingHour: (currentHour + additionalHour + 1) % 24, minute: 0, second: 0, of: currentDate)!
    }

    static func initializeSelectedDate() -> Date {
        let currentDate = Date()
        let currentHour = Calendar.current.component(.hour, from: currentDate)
        return currentHour > 18 ? Calendar.current.date(byAdding: .day, value: 1, to: currentDate)! : currentDate
    }

    func calculateTotal(basket: [Product]) -> String {
        let totalAmount = basket.reduce(0.0) { $0 + ($1.price * Double($1.amount)) }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "GBP"
        return formatter.string(from: NSNumber(value: totalAmount)) ?? "£0.00"
    }

    func saveCookies(name: String?, email: String?, profileImageURL: URL?) {
        if let name = name { setCookie(name: "userName", value: name) }
        if let email = email { setCookie(name: "userEmail", value: email) }
        if let profileImageURL = profileImageURL { setCookie(name: "profileImageURL", value: profileImageURL.absoluteString) }
    }

    func setCookie(name: String, value: String) {
        let cookie = HTTPCookie(properties: [
            .domain: "your.domain.com",
            .path: "/",
            .name: name,
            .value: value,
            .secure: "TRUE",
            .expires: NSDate(timeIntervalSinceNow: 31556926)
        ])!
        HTTPCookieStorage.shared.setCookie(cookie)
    }

    func performRegularSignIn(with rootViewController: UIViewController) {
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { signInResult, error in
            if let user = signInResult?.user {
                self.profileImageURL = user.profile?.imageURL(withDimension: 100)
                self.saveCookies(name: user.profile?.name, email: user.profile?.email, profileImageURL: self.profileImageURL)
                self.isLoggedIn = true
                self.loginManager.sendLoginRequest(email: user.profile?.email ?? "", orderId: self.orderId ?? "")
            }
        }
    }

    func saveAddresses() {
        let sortedAddresses = self.addresses.sorted { $0.isDefault && !$1.isDefault }
        if let encoded = try? JSONEncoder().encode(sortedAddresses) {
            UserDefaults.standard.set(encoded, forKey: "SavedAddresses")
        }
    }

    func setDefaultAddress(_ selectedAddress: Address) {
        self.addresses.indices.forEach { self.addresses[$0].isDefault = false }
        if let index = self.addresses.firstIndex(of: selectedAddress) {
            self.addresses[index].isDefault = true
            self.defaultAddress = self.addresses[index]
        }
    }

    var dynamicSheetHeight: CGFloat {
        CGFloat(self.addresses.count * 50 + 160)
    }

    func setDefaultCard(_ selectedCard: Payment) {
        self.cards.indices.forEach { self.cards[$0].isDefault = false }
        if let index = self.cards.firstIndex(where: { $0.id == selectedCard.id }) {
            self.cards[index].isDefault = true
            self.selectedPaymentMethod = self.cards[index]
        } else {
            self.selectedPaymentMethod = selectedCard
        }
    }

    func saveCards() {
        if let encoded = try? JSONEncoder().encode(self.cards) {
            UserDefaults.standard.set(encoded, forKey: "SavedCards")
        }
    }

    var dynamicCardsSheetHeight: CGFloat {
        CGFloat(self.cards.count * 50 + 210)
    }

    private func formattedDate(_ date: Date, time: Date) -> String {
        let calendar = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let timePart = timeFormatter.string(from: time)

        if calendar.isDateInToday(date) {
            return "Today \(timePart)"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow \(timePart)"
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "E dd/MM"
            let datePart = dateFormatter.string(from: date)
            return "\(datePart) \(timePart)"
        }
    }

    func sendCompleteOrderRequest() {
        let deliveryTime = formattedDate(self.selectedDate, time: self.selectedTime)
        let schedule = !(self.displayText.contains("Within") || self.displayText.contains("Pickup"))
        let pickup = self.selectedOption == .pickup
        let urlString = "https://minitel.co.uk/app/models/checkoutGateway?command=completeOrder&orderId=\(self.orderId ?? "")&pickupTime=&deliveryTime=\(deliveryTime)&addressId=&delivery=&shop=\(shopId)&total=&pickup=\(pickup)&schedule=\(schedule)&timeTitle=&nd=0"

        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                DispatchQueue.main.async {
                    // Handle error
                }
                return
            }

            guard let data = data, let responseString = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async {
                    // Handle error
                }
                return
            }

            DispatchQueue.main.async {
                if responseString.contains("|Ok|") {
                    let currentOrder = Order(orderId: self.orderId ?? "", customerName: "", postcode: self.defaultAddress?.postcode ?? "", address: "\(self.defaultAddress?.street ?? "") \(self.defaultAddress?.building ?? "")", pickupTime: "", deliveryTime: deliveryTime, status: 1, packed: 0, phone: "", total: 0.0, icon: "", pickupImageUrl: nil, deliveryImageUrl: nil, allocatedTime: "", pickupETA: "", courierId: "", courierName: "", courierPhone: nil, lifecycle: "")
                    self.navigateToOrderView(order: currentOrder)
                } else {
                    // Handle error response
                }
            }
        }.resume()
    }

    func navigateToOrderView(order: Order) {
        self.currentOrder = order
        self.showOrderView = true
    }
}
