import SwiftUI

struct HistoryView: View {
    @StateObject private var viewModel = HistoryViewModel()
    @State private var selectedOrder: Order?
    @State private var showOrderView = false
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack {
            if viewModel.loading {
                ProgressView("Loading...")
                    .foregroundColor(.gray)
            } else if viewModel.orders.isEmpty {
                Text("Your orders will appear here")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                List(viewModel.orders) { order in
                    OrderStatusView(
                        orderStatus: getStatusText(for: String(order.status)),
                        orderDate: order.deliveryTime,
                        productImages: order.images?.split(separator: "*").map(String.init) ?? [],
                        orderAgainAction: {
                            orderAgain(lastOrderId: order.orderId) {
                                self.presentationMode.wrappedValue.dismiss()
                            }
                        },
                        detailsAction: {
                            self.selectedOrder = order
                            self.showOrderView = true
                        },
                        selectedOrder: Binding(get: { self.selectedOrder }, set: { self.selectedOrder = $0 }),
                        showOrderView: $showOrderView,
                        pastOrder: order
                    )
                    .listRowInsets(EdgeInsets()) // Remove the default padding
                }
                .listStyle(PlainListStyle())
            }
        }
        .background(
            NavigationLink(
                destination: OrderView(
                    order: selectedOrder ?? Order()
                ),
                isActive: $showOrderView
            ) { EmptyView() }
        )
        .onAppear {
            viewModel.fetchOrders()
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("My orders")
                    .font(.headline)
            }
        }
    }
}
