import Foundation

class HistoryViewModel: ObservableObject {
    @Published var orders: [Order] = []
    @Published var loading = true
    
    func fetchOrders() {
        guard let url = URL(string: "https://minitel.co.uk/app/models/shopgateway?command=getLastOrders&cid=1393497&shop=798") else {
            print("Invalid URL")
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                self.loading = false
                if let data = data {
                    let responseString = String(data: data, encoding: .utf8)
                    self.orders = self.parseOrders(responseString ?? "")
                } else if let error = error {
                    print("HTTP Request failed: \(error)")
                }
            }
        }.resume()
    }
    
    func parseOrders(_ response: String) -> [Order] {
        let ordersStringArray = response.split(separator: "$")
        return ordersStringArray.compactMap { orderString in
            let orderDetails = orderString.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            if orderDetails.count >= 12 {
                let orderStatus = getStatusText(for: orderDetails[1])
                let orderDate = convertDateString(orderDetails[4]) ?? "Invalid Date"
                
                return Order(
                    orderId: orderDetails[3],
                    customerName: "",
                    postcode: orderDetails[6],
                    address: orderDetails[5],
                    pickupTime: "", // Assign appropriate value if available
                    deliveryTime: orderDate,
                    status: Int(orderDetails[1]) ?? 0,
                    packed: 0, // Assign appropriate value if available
                    phone: "",
                    total: Double(orderDetails[0]) ?? 0.0,
                    icon: "", // Assign appropriate value if available
                    pickupImageUrl: orderDetails[10],
                    deliveryImageUrl: orderDetails[11],
                    allocatedTime: "", // Assign appropriate value if available
                    pickupETA: "", // Assign appropriate value if available
                    courierId: "", // Assign appropriate value if available
                    courierName: orderDetails[7],
                    courierPhone: orderDetails[8],
                    lifecycle: orderDetails[9],
                    images: orderDetails[2]
                )
            }
            return nil
        }
    }

    private func getStatusText(for statusCode: String) -> String {
        switch statusCode {
        case "1": return "Received"
        case "2": return "Allocated"
        case "3": return "Picked up"
        case "4": return "En route"
        case "5": return "Delivered"
        default: return "Unknown status"
        }
    }
    
    private func convertDateString(_ inputDateString: String) -> String? {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "M/dd/yyyy h:mm:ss a"
        inputFormatter.locale = Locale(identifier: "en_US_POSIX")

        if let date = inputFormatter.date(from: inputDateString) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "E dd/MM HH:mm"
            return outputFormatter.string(from: date)
        }
        return nil
    }
}

func orderAgain(lastOrderId: String, completion: @escaping () -> Void) {
    let urlString = "https://minitel.co.uk/app/models/shopgateway?command=orderAgain&id=\(lastOrderId)&shop=\(shopId)&cid=\(userId)"
    
    guard let url = URL(string: urlString) else {
        print("Invalid URL")
        return
    }
    
    URLSession.shared.dataTask(with: url) { _, _, error in
        if let error = error {
            DispatchQueue.main.async {
                print("Error: \(error.localizedDescription)")
            }
            return
        }
        
        DispatchQueue.main.async {
            print("Order again successful")
            UserDefaults.standard.set(true, forKey: "showBasketOnce")
            completion()
        }
    }.resume()
}
