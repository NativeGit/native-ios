import SwiftUI
import Combine
import AVFoundation

class OrdersViewModel: ObservableObject {
    @Published var orders = [Order]()
    @Published var filteredOrders = [Order]()
    @Published var searchSubmitted = false
    @Published var isLoading = true
    @Published var lastOrder: Order?
    @Published var showChatView = false
    @Published var isNavigationActive = false
    @Published var selectedOrder: Order?
    private var cancellables = Set<AnyCancellable>()
    @Published var searchText = "" {
        didSet { searchText.isEmpty ? restoreOriginalOrders() : updateFilteredOrders() }
    }
    private var previousOrders = [Order]()
    private var backupOrders = [Order]()

    // Fetch order by ID
    func getOrderById(orderId: String) -> Order? {
        return orders.first { $0.orderId == orderId }
    }

    // Search orders with a given text
    func searchOrders(searchText: String) {
        guard let url = URL(string: "https://hoodapp.co.uk/get.aspx?type=232&store=1&search=\(searchText)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") else {
            print("Invalid URL.")
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else {
                print("Error fetching data: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            if let result = String(data: data, encoding: .utf8) {
                self.parseSearchResults(from: result)
            }
        }.resume()
    }

    // Parse search results into orders
    private func parseSearchResults(from results: String) {
        let orders = results.components(separatedBy: "::")
            .filter { !$0.isEmpty }
            .compactMap { entry -> Order? in
                let data = entry.components(separatedBy: "|")
                guard data.count >= 5 else { return nil }
                return Order(
                    orderId: data[3], customerName: decodeHTMLEntities(in: data[0]), postcode: data[2],
                    address: decodeHTMLEntities(in: data[1]), pickupTime: formatTime(for: data[9]),
                    deliveryTime: data[10], status: Int(data[6]) ?? 0, packed: Int(data[29]) ?? 0,
                    phone: data[28], total: Double(data[4]) ?? 0.0, icon: data[30], pickupImageUrl: data[32],
                    deliveryImageUrl: data[33], allocatedTime: formatTime(for: data[36]),
                    pickupETA: formatTime(for: data[37]), courierId: "", courierName: data[38], courierPhone: data[39],
                    lifecycle: data[40]
                )
            }
        
        DispatchQueue.main.async {
            self.orders = orders
            self.filteredOrders = orders
        }
    }

    // Calculate delivery ETA delay for an order
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

    // Fetch orders from the server
    func getOrders() {
          var urlString = "https://minitel.co.uk/app/models/ordersGate?command=getOrders&shop=1"
          if UserDefaults.standard.string(forKey: "selectedAdminID") == "c", let cid = UserDefaults.standard.string(forKey: "cid") {
              urlString = "https://minitel.co.uk/app/models/ordersGate?command=getOrders&shop=1&courierid=\(cid)&date="
          }

          if UserDefaults.standard.string(forKey: "selectedAdminID") == "ca" {
              urlString = "https://minitel.co.uk/app/models/ordersGate?command=getOrders&shop=100&date="
          }

          guard let url = URL(string: urlString) else {
              print("Invalid URL.")
              return
          }

          var request = URLRequest(url: url)
          request.cachePolicy = .reloadIgnoringLocalCacheData

          URLSession.shared.dataTaskPublisher(for: request)
              .map { $0.data }
              .sink(receiveCompletion: { completion in
                  if case let .failure(error) = completion {
                      print("Error fetching data: \(error.localizedDescription)")
                  }
              }, receiveValue: { [weak self] data in
                  if let result = String(data: data, encoding: .utf8) {
                      self?.updateOrders(with: result.components(separatedBy: "::"))
                  } else {
                      print("Error decoding data into string.")
                  }
              })
              .store(in: &cancellables)
      }
    
    func cancelAllRequests() {
           cancellables.forEach { $0.cancel() }
           cancellables.removeAll()
       }

    // Update orders with parsed results
    private func updateOrders(with ordersArray: [String]) {
        let parsedOrders = parseOrders(from: ordersArray)
        DispatchQueue.main.async {
            if !self.showChatView {
                print("Updating orders with: \(parsedOrders)") // Debug print statement
                self.backupOrders = parsedOrders
                self.orders = parsedOrders
                self.updateFilteredOrders()
                self.checkForNewOrders()
                self.isLoading = false
            }
        }
    }

    // Update filtered orders based on search text
    private func updateFilteredOrders() {
        filteredOrders = searchText.isEmpty ? orders : orders.filter {
            $0.orderId.localizedCaseInsensitiveContains(searchText) ||
            $0.customerName.localizedCaseInsensitiveContains(searchText) ||
            $0.postcode.localizedCaseInsensitiveContains(searchText) ||
            $0.address.localizedCaseInsensitiveContains(searchText)
        }
    }

    // Restore original orders
    private func restoreOriginalOrders() {
        orders = backupOrders
    }

    // Check for new orders and play sound if found
    private func checkForNewOrders() {
        let newOrders = orders.filter { order in !previousOrders.contains { $0.orderId == order.orderId } }
        if !newOrders.isEmpty {
            playSound()
            lastOrder = newOrders.first
        }
        previousOrders = orders
    }

    // Play notification sound
    private func playSound() {
        AudioServicesPlaySystemSound(1009)
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }

    // Parse orders from string array
    private func parseOrders(from array: [String]) -> [Order] {
        return array.compactMap { entry -> Order? in
            let data = entry.components(separatedBy: "|")
            guard data.count >= 10 else { return nil }
            return Order(
                orderId: data[3], customerName: decodeHTMLEntities(in: data[0]), postcode: data[2],
                address: decodeHTMLEntities(in: data[1]), pickupTime: formatTime(for: data[9]),
                deliveryTime: data[10], status: Int(data[6]) ?? 0, packed: Int(data[29]) ?? 0,
                phone: data[28], total: Double(data[4]) ?? 0.0, icon: data[30], pickupImageUrl: data[32],
                deliveryImageUrl: data[33], allocatedTime: formatTime(for: data[36]),
                pickupETA: formatTime(for: data[37]), courierId: "", courierName: data[38], courierPhone: data[39],
                lifecycle: data[40]
            )
        }
    }

    // Format time strings into readable format
    private func formatTime(for dateString: String) -> String {
        let inputFormats = ["MM/dd/yyyy h:mm:ss a", "yyyy-MM-dd-HH:mm"]
        let date = inputFormats.compactMap { format -> Date? in
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            return formatter.date(from: dateString)
        }.first

        guard let date = date else { return "" }

        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else if Calendar.current.isDate(date, inSameDayAs: Calendar.current.date(byAdding: .day, value: 1, to: Date())!) {
            formatter.dateFormat = "'Tomorrow' HH:mm"
        } else {
            formatter.dateFormat = "EEE dd-MM HH:mm"
        }
        return formatter.string(from: date)
    }

    // Decode HTML entities in strings
    private func decodeHTMLEntities(in string: String) -> String {
        guard let data = string.data(using: .utf8) else { return string }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue]
        return (try? NSAttributedString(data: data, options: options, documentAttributes: nil).string) ?? string
    }
}
