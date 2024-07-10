import SwiftUI

class ShopModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var basket: [Product] = []
    @Published var categories: [Category] = [Category(name: "All")]
    @Published var selectedCategoryId: UUID?
    @Published var isBasketInitialized = false
    @Published var order: Order?
    @Published var selectedCategory = "All"
    @Published var profileImageURL: URL?
    @Published var isLoggedIn = false
    @Published var isHistoryViewActive = false {
        didSet { print("isHistoryViewActive changed to \(isHistoryViewActive)") }
    }

    var subtotal: Double {
        basket.reduce(0.0) { $0 + ($1.price * Double($1.amount)) }
    }

    var filteredProducts: [Product] {
        selectedCategory != "All" ? products.filter { $0.category == selectedCategory } : products
    }

    var filteredBasketCount: Int {
        basket.filter { $0.amount > 0 }.count
    }

    func fetchInitialProducts() {
        fetchProducts(orderId: "", shopId: shopId, userId: UserDefaults.standard.string(forKey: "cid") ?? "")
    }

    func refreshProducts() {
        fetchProducts(orderId: "", shopId: shopId, userId: UserDefaults.standard.string(forKey: "cid") ?? "")
    }

    func fetchProducts(orderId: String, shopId: String, userId: String) {
        let urlString = "https://minitel.co.uk/app/models/shopgateway?command=loadProducts4&orderid=\(orderId)&shop=\(shopId)&userid=\(userId)"
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self, let data = data, error == nil else { return }
            let responseString = String(data: data, encoding: .utf8)
            let productStrings = responseString?.split(separator: "$").map(String.init) ?? []
            var products: [Product] = []

            for productString in productStrings {
                let components = productString.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
                if components.count == 4 {
                    UserDefaults.standard.set(components[0], forKey: "orderId")
                    UserDefaults.standard.set(components[1], forKey: "cid")
                }
                if components.count >= 14 {
                    let amount = Int(components[8]) ?? 0
                    let price = (Double(components[2]) ?? 0.0) * assets.pricePercentage
                    let product = Product(
                        id: Int(components[0]) ?? 0,
                        name: components[1],
                        description: components[3],
                        price: price,
                        imageURL: components[4],
                        status: Int(components[5]) ?? 0,
                        category: components[11],
                        options: self.parseOptions(components[13]),
                        amount: amount
                    )
                    products.append(product)
                }
            }

            DispatchQueue.main.async {
                self.products = products
                if self.categories.count < 2 { self.setupCategories() }
                if !self.isBasketInitialized, let firstProduct = products.first {
                    self.addToBasket(userId: userId, product: Product(id: 0, name: firstProduct.name, description: firstProduct.description, price: firstProduct.price, imageURL: firstProduct.imageURL, status: firstProduct.status, category: firstProduct.category, options: firstProduct.options, amount: 0), amount: 0, edit: 0) { success in
                        if success { self.isBasketInitialized = true }
                    }
                }
                self.fetchLastOrder { result in
                    if case .success(let order) = result { self.order = order }
                }
            }
        }.resume()
    }

    func addToBasket(userId: String, product: Product, amount: Int, edit: Int, completion: @escaping (Bool) -> Void) {
        guard let orderId = UserDefaults.standard.string(forKey: "orderId") else { completion(false); return }

        let unitPrice = product.price
        let selectedOptions = product.options.filter { $0.isSelected }
        let optionsPrice = selectedOptions.reduce(0.0) { $0 + $1.price }
        let finalTotal = unitPrice + optionsPrice
        let choices = selectedOptions.map { $0.name }.joined(separator: ", ")
        let editValue = edit == 1 ? Int(product.basketId ?? "") ?? 1 : 0

        let urlString = "https://minitel.co.uk/app/models/shopgateway?command=updateBasketWeb&customerID=\(userId)&productId=\(product.id)&amount=\(amount)&orderId=\(orderId)&price=\(finalTotal)&storeid=1&unit=&choices=\(choices)&edit=\(editValue)"

        guard let url = URL(string: urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") else { completion(false); return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            if error != nil || data == nil { completion(false); return }

            DispatchQueue.main.async {
                if let productIndex = self?.products.firstIndex(where: { $0.id == product.id }) {
                    self?.products[productIndex].amount = amount
                }
                self?.parseAndAddToBasket(String(data: data!, encoding: .utf8) ?? "", product: product)
                completion(true)
            }
        }.resume()
    }

    private func parseAndAddToBasket(_ response: String, product: Product) {
        var updatedBasket: [Product] = []

        for item in response.components(separatedBy: "$") {
            let itemComponents = item.components(separatedBy: "|")
            if itemComponents.count >= 14 {
                let productName = "\(itemComponents[1]) - \(itemComponents[7])"
                if let price = Double(itemComponents[2]), let amount = Int(itemComponents[4]) {
                    updatedBasket.append(Product(
                        id: Int(itemComponents[5]) ?? 0,
                        name: productName,
                        description: product.description,
                        price: price,
                        imageURL: itemComponents[3],
                        status: Int(itemComponents[9]) ?? 0,
                        category: itemComponents[11],
                        options: product.options,
                        amount: amount,
                        basketId: itemComponents[13]
                    ))
                }
            }
        }
        basket = updatedBasket
    }

    private func parseOptions(_ optionsString: String) -> [Option] {
        optionsString.split(separator: "*").compactMap { optionComponent in
            let parts = optionComponent.split(separator: "@")
            guard parts.count >= 4 else { return nil }
            return Option(
                id: UUID(uuidString: String(parts[3])) ?? UUID(),
                name: String(parts[0]),
                price: Double(parts[1]) ?? 0.0,
                type: String(parts[2]).lowercased() == "options" ? .option : .addition,
                valueMax: parts.count >= 5 ? Int(parts[5]) : nil
            )
        }
    }

    func fetchLastOrder(completion: @escaping (Result<Order, Error>) -> Void) {
        guard let userId = UserDefaults.standard.string(forKey: "cid"), let url = URL(string: "https://minitel.co.uk/app/models/shopgateway?command=getLastOrder&cid=\(userId)") else { return }

        URLSession.shared.dataTask(with: url) { data, _, error in
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                let orderDetails = responseString.split(separator: "$")[1].split(separator: "|", omittingEmptySubsequences: false)
                if orderDetails.count >= 14 {
                    completion(.success(Order(
                        orderId: String(orderDetails[3]),
                        customerName: String(orderDetails[12]),
                        postcode: String(orderDetails[6]),
                        address: String(orderDetails[5]),
                        deliveryTime: String(orderDetails[4]),
                        status: Int(String(orderDetails[1])) ?? 0,
                        phone: String(orderDetails[13]),
                        total: Double(String(orderDetails[0])) ?? 0.0,
                        pickupImageUrl: String(orderDetails[10]),
                        deliveryImageUrl: String(orderDetails[11]),
                        courierName: String(orderDetails[7]),
                        courierPhone: String(orderDetails[8]),
                        lifecycle: String(orderDetails[9])
                    )))
                } else { completion(.failure(NSError(domain: "", code: -1, userInfo: nil))) }
            } else { completion(.failure(error ?? NSError(domain: "", code: -1, userInfo: nil))) }
        }.resume()
    }

    func orderAgain(lastOrderId: String) {
        guard let userId = UserDefaults.standard.string(forKey: "cid"), let url = URL(string: "https://minitel.co.uk/app/models/shopgateway?command=orderAgain&id=\(lastOrderId)&shop=1&cid=\(userId)") else { return }
        URLSession.shared.dataTask(with: url).resume()
    }

    func decodeHTMLEntities(in input: String) -> String {
        guard let encodedData = input.data(using: .utf8) else { return input }
        return (try? NSAttributedString(data: encodedData, options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue], documentAttributes: nil).string) ?? input
    }

    func setupCategories() {
        guard !products.isEmpty else { return }

        var categoryNamesSet = Set(products.map { decodeHTMLEntities(in: $0.category) })
        var categoriesList = categoryNamesSet.map { Category(name: $0) }

        let categoryProducts = products.map { (decodeHTMLEntities(in: $0.category), $0.id) }
        categoriesList.sort { (cat1, cat2) -> Bool in
            let cat1Products = categoryProducts.filter { $0.0 == cat1.name }
            let cat2Products = categoryProducts.filter { $0.0 == cat2.name }
            let cat1MinId = cat1Products.min(by: { $0.1 < $1.1 })?.1 ?? Int.max
            let cat2MinId = cat2Products.min(by: { $0.1 < $1.1 })?.1 ?? Int.max
            return cat1MinId < cat2MinId
        }

        categories = [Category(name: "All")] + categoriesList
        selectedCategoryId = categories.first?.id
    }

    func calculateTotal(basket: [Product]) -> String {
        let totalAmount = basket.reduce(0.0) { $0 + ($1.price * Double($1.amount)) }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "GBP"
        return formatter.string(from: NSNumber(value: totalAmount)) ?? "£0.00"
    }

    var dynamicHeight: CGFloat {
        CGFloat(basket.filter { $0.amount > 0 }.count) * 70 + 110
    }

    func checkCookies() {
        if let emailCookie = HTTPCookieStorage.shared.cookies?.first(where: { $0.name == "userEmail" }),
           let profileImageCookie = HTTPCookieStorage.shared.cookies?.first(where: { $0.name == "profileImageURL" }),
           let url = URL(string: profileImageCookie.value) {
            profileImageURL = url
            isLoggedIn = true
        }
    }
}
