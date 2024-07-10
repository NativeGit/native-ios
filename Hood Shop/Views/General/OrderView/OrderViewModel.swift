import Foundation
import SwiftUI
import WebKit

class OrderViewModel: ObservableObject {
    @ObservedObject var webViewContainer = WebViewContainer()
    @Published var orderDetails: [OrderDetail] = []
    @Published var lifecycleEvents: [LifecycleEvent] = []
    @Published var couriers: [Courier] = []
    @Published var capturedImage: UIImage?
    @Published var isWebViewVisible = false
    @Published var deliveryMinutes = ""
    @Published var order = Order()
    @Published var selectedCourierId = ""
    @Published var selectedOrderId = ""
    @Published var customerMode = 0

    struct OrderDetail {
        var quantity: Int
        var productName: String
        var price: Double
    }

    struct LifecycleEvent {
        let action: String
        let value: String
        let timestamp: String
    }

    private var timer: Timer?

    init() {
        startLifecycleUpdateTimer()
    }

    // Start a timer to periodically update the order lifecycle
    func startLifecycleUpdateTimer() {
        print("Timer started")
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.updateOrderLifecycle()
        }
    }

    // Invalidate the timer
    func invalidateTimer() {
        print("Invalidating timer")
        timer?.invalidate()
        timer = nil
    }

    // Fetch and update the order lifecycle
    func updateOrderLifecycle() {
        guard !selectedOrderId.isEmpty else {
            print("Order ID is empty")
            return
        }

        guard let url = URL(string: "https://minitel.co.uk/app/models/ordersGate?command=getOrderLifecycle&id=\(selectedOrderId)") else {
            print("Invalid URL")
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            if let error = error {
                print("Error fetching lifecycle: \(error.localizedDescription)")
                return
            }

            guard let data = data, let stringResult = String(data: data, encoding: .utf8) else {
                print("Error: HTTP status code or data issue")
                return
            }

            let lifecycle = self?.parseLifecycleFromResponse(stringResult) ?? ""
            DispatchQueue.main.async {
                self?.order.lifecycle = lifecycle
                self?.lifecycleEvents = self?.parseLifecycle(lifecycle) ?? []
            }
        }.resume()
    }

    // Parse lifecycle events from the server response
    private func parseLifecycleFromResponse(_ response: String) -> String {
        guard let range = response.range(of: "\\|(.*?)\\|", options: .regularExpression) else {
            return ""
        }
        return String(response[range].dropFirst().dropLast())
    }

    // Convert lifecycle string to array of LifecycleEvent
    func parseLifecycle(_ lifecycle: String) -> [LifecycleEvent] {
        lifecycle.split(separator: ",").compactMap { event in
            let components = event.split(separator: "*").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            return components.count >= 2 ? LifecycleEvent(action: components[0], value: components.count == 3 ? components[1] : "", timestamp: components.last!) : nil
        }
    }

    // Get a specific lifecycle event by action
    func getLifecycleEvent(for action: String) -> LifecycleEvent? {
        lifecycleEvents.first { $0.action.lowercased() == action.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    // Mark the order as rebooked
    func rebookOrder() {
        order.status = 8
    }

    // Load order details from the server
    func loadOrder(orderId: String, id: String) {
        guard let url = URL(string: "https://hoodapp.co.uk/get.aspx?type=6&orderid=\(orderId)&id=\(id)") else {
            print("Invalid URL")
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            if let error = error {
                print("Error fetching data: \(error.localizedDescription)")
                return
            }

            guard let data = data, let stringResult = String(data: data, encoding: .utf8) else {
                print("Error: HTTP status code or data issue")
                return
            }

            let orderArray = stringResult.components(separatedBy: "$")
            DispatchQueue.main.async {
                self?.orderDetails = self?.parseOrders(from: orderArray) ?? []
            }
        }.resume()
    }

    // Parse order details from the server response
    private func parseOrders(from dataArray: [String]) -> [OrderDetail] {
        dataArray.compactMap { dataEntry in
            let dataComponents = dataEntry.components(separatedBy: "|")
            guard dataComponents.count == 7, let price = Double(dataComponents[1]), let quantity = Int(dataComponents[4]) else {
                print("Error: Could not convert price and/or quantity to respective types.")
                return nil
            }
            return OrderDetail(quantity: quantity, productName: dataComponents[0], price: price)
        }
    }

    // Calculate the total price of the order
    var totalPrice: Double {
        orderDetails.reduce(0) { $0 + ($1.price * Double($1.quantity)) }
    }

    // Capture a snapshot of the web view and print it
    func captureSnapshot() {
        let webView = webViewContainer.webView
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let config = WKSnapshotConfiguration()
            config.rect = CGRect(x: 0, y: 0, width: webView.bounds.width, height: webView.bounds.height)
            webView.takeSnapshot(with: config) { [weak self] image, error in
                if let error = error {
                    print("Error taking snapshot: \(error)")
                    return
                }
                guard let image = image else {
                    print("Snapshot taken, but image is empty or invalid.")
                    return
                }
                DispatchQueue.main.async {
                    self?.capturedImage = image
                    PrinterManager().printImage(image: image)
                    self?.isWebViewVisible = false
                }
            }
        }
    }

    // Handle dismissal of a sheet and update order lifecycle
    func handleSheetDismissal() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if(self.order.status<=2){
                self.order.status = 3
                updateOrderStatus(orderId: self.order.orderId, status: 4)
            }
            else{
                self.order.status = 4
                updateOrderStatus(orderId: self.order.orderId, status: 5)
            }
            self.updateOrderLifecycle()
        }
    }

    // Calculate the delay in delivery ETA
    func getDeliveryEtaDelay(for order: Order) -> Int {
        guard let receivedEvent = order.getLifecycleEvent(for: "received"),
              let deliveryEtaEvent = order.getLifecycleEvent(for: "deliveryEta"),
              let receivedTime = parseDate(receivedEvent.value),
              let deliveryEtaTime = parseDate(deliveryEtaEvent.value) else {
            print("Either receivedEvent or deliveryEtaEvent is nil or could not be parsed")
            return 0
        }

        return max(0, Int(deliveryEtaTime.timeIntervalSince(receivedTime) / 60))
    }

    // Calculate the delay in delivery ETA for the current order
    func getDeliveryEtaDelay() -> Int {
        guard let receivedEvent = getLifecycleEvent(for: "received"),
              let deliveryEtaEvent = getLifecycleEvent(for: "deliveryEta"),
              let receivedTime = parseDate(receivedEvent.value),
              let deliveryEtaTime = parseDate(deliveryEtaEvent.value) else {
            print("Either receivedEvent or deliveryEtaEvent is nil or could not be parsed")
            return 0
        }

        return max(0, Int(deliveryEtaTime.timeIntervalSince(receivedTime) / 60))
    }

    // Allocate a courier to the order
    func allocateCourier() {
        guard !selectedCourierId.isEmpty, let courier = couriers.first(where: { $0.id == selectedCourierId }) else {
            print("No courier selected or ID is empty")
            return
        }

        order.status = 2
        order.courierName = courier.name
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)
        lifecycleEvents.append(LifecycleEvent(action: "allocated", value: courier.name, timestamp: timestamp))
        updateOrderOnServer(orderId: selectedOrderId, courierId: selectedCourierId)
    }

    // Update the order on the server with the selected courier
    func updateOrderOnServer(orderId: String, courierId: String) {
        guard let url = URL(string: "https://minitel.co.uk/app/models/shopgateway?command=updateCourierForOrder&orderId=\(orderId)&courierId=\(courierId)") else {
            print("Invalid URL")
            return
        }
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Network error: \(error)")
                return
            }
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                print("HTTP Error")
                return
            }
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("Server response: \(responseString)")
            }
        }.resume()
    }

    // Process and upload an image for the order
    func processAndUploadImage(_ inputImage: UIImage) {
        guard let resizedImage = resizeImage(inputImage, toMaxDimension: 400), let imageData = resizedImage.jpegData(compressionQuality: 1.0) else { return }
        let imageString = imageData.base64EncodedString()
        let name = generateUniqueImageName()
        saveImageToServer(image: inputImage, imageName: name, orderId: selectedOrderId, orderStatus: order.status) { result in
            
        }
    }

    // Generate button text based on the order status
    func buttonText(for status: Int) -> String {
        if customerMode == 1 {
            return "Need help? Chat with us for support"
        }
        switch status {
        case 0, 1, 2:
            return "Update pickup time"
        case 3:
            return "Mark as Collected"
        case 4:
            return "Mark as Delivered"
        case 5:
            return "Delivered"
        default:
            return "Unknown"
        }
    }
}
