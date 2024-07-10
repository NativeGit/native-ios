import SwiftUI
import Kingfisher

struct OrderRow: View {
    var order: Order
    @ObservedObject var viewModel: OrdersViewModel

    // Determines the text for the order status
    private var orderStatusText: String {
        switch order.status {
        case 1:
            return "Received"
        case 2, 3:
            return "Assigned" + (order.courierName.isEmpty ? "" : " - \(order.courierName)")
        case 4:
            return "En route" + (order.courierName.isEmpty ? "" : " - \(order.courierName)")
        case 5:
            return "Delivered"
        case 7:
            return "Cancelled"
        default:
            return "Status Unknown"
        }
    }

    // Determines the delay text if there is a delay
    private var delayText: String? {
        let delay = viewModel.getDeliveryEtaDelay(for: order)
        return delay > 0 ? "Delay \(delay) min" : nil
    }

    // Formats time for display
    private func formatTime(for dateString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "MM/dd/yyyy h:mm:ss a"
        inputFormatter.locale = Locale(identifier: "en_US_POSIX")

        guard let date = inputFormatter.date(from: dateString) else { return "" }

        let calendar = Calendar.current
        let now = Date()
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)

        let outputFormatter = DateFormatter()
        if calendar.isDateInToday(date) {
            outputFormatter.dateFormat = "HH:mm"
        } else if let tomorrow = tomorrow, calendar.isDate(date, inSameDayAs: tomorrow) {
            outputFormatter.dateFormat = "'Tomorrow' HH:mm"
        } else {
            outputFormatter.dateFormat = "EEE dd-MM HH:mm"
        }

        return outputFormatter.string(from: date)
    }

    // Extracts ETA time from a date string
    private func extractEtaTime(from dateString: String?) -> String {
        guard let dateString = dateString else { return "" }
        return formatTime(for: dateString)
    }

    // Checks if the given time is in the past
    private func isPastTime(_ dateString: String?) -> Bool {
        guard let dateString = dateString else { return false }
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "MM/dd/yyyy h:mm:ss a"
        inputFormatter.locale = Locale(identifier: "en_US_POSIX")

        guard let date = inputFormatter.date(from: dateString) else { return false }
        return date < Date()
    }

    var body: some View {
        Button(action: {
            viewModel.selectedOrder = order
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                viewModel.isNavigationActive = true
            }
        }) {
            HStack {
                if let retrievedAdminID = UserDefaults.standard.string(forKey: "selectedAdminID"),
                   let iconURL = URL(string: order.icon),
                   ["0", "ca"].contains(retrievedAdminID) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 30)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 60, height: 60)
                        KFImage(iconURL)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("#\(order.orderId) \(order.customerName)")
                            .font(.headline)
                            .lineLimit(1)
                        Spacer()
                        Text("£\(String(format: "%.2f", order.total))")
                            .foregroundColor(order.packed == 0 && (order.status == 2 || order.status == 3) ? .blue : .gray)
                            .font(.subheadline)
                    }
                    HStack {
                        Text(order.postcode)
                            .font(.system(size: 14.5))
                            .lineLimit(1)
                            .padding(.top, 2)
                            .foregroundColor(.secondary)
                        Spacer()
                        if let delayText = delayText {
                            Text(delayText)
                                .font(.system(size: 14.5))
                                .foregroundColor(.red)
                                .lineLimit(1)
                        }
                    }
                    Text(orderStatusText)
                        .font(.system(size: 14.5))
                        .lineLimit(1)
                        .foregroundColor(.secondary)
                    if order.status < 5 {
                        let deliveryEta = order.getLifecycleEvent(for: "deliveryEta")?.value
                        let received = order.getLifecycleEvent(for: "received")?.value
                        let timeSource = deliveryEta ?? received ?? order.deliveryTime
                        Text("Delivery \(extractEtaTime(from: timeSource))")
                            .font(.system(size: 14.5))
                            .lineLimit(1)
                            .padding(.top, 2)
                            .foregroundColor(isPastTime(timeSource) ? .red : .secondary)
                    }
                }
                Spacer() // Ensures the button takes the full width
            }
            .padding(.vertical, 3)
            .contentShape(Rectangle()) // Ensures the full row is tappable
        }
        .buttonStyle(PlainButtonStyle()) // Ensures the button looks like a regular row
    }
}

struct SectionView: View {
    let sectionHeader: String
    let statusCodes: [Int]
    @ObservedObject var viewModel: OrdersViewModel

    var body: some View {
        let filteredOrders = viewModel.filteredOrders.filter { statusCodes.contains($0.status) }
        if !filteredOrders.isEmpty {
            Section(header: Text(sectionHeader)) {
                ForEach(filteredOrders, id: \.orderId) { order in
                    OrderRow(order: order, viewModel: viewModel)
                }
            }
        }
    }
}


