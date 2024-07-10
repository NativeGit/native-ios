import SwiftUI
import AVFoundation
import WebKit
import CoreLocation
import Kingfisher

struct OrdersView: View {
    @EnvironmentObject var viewRouter: ViewRouter
    @EnvironmentObject var appViewModel: AppViewModel
    @ObservedObject var viewModel: OrdersViewModel
    @State private var searchText = ""
    @State private var capturedImage: UIImage?
    @State private var navigateToOrderView = false
    @State private var showChatView = false
    @State private var adminID = UserDefaults.standard.string(forKey: "selectedAdminID") ?? ""
    @State private var timer: Timer?
    @State private var isViewLoaded = false
    @State private var showShopView = false
    @Environment(\.colorScheme) var colorScheme
    @State private var icon = UserDefaults.standard.string(forKey: "icon") ?? ""

    // Order link navigation
    private var orderLink: some View {
        Group {
            if let lastOrder = viewModel.getOrderById(orderId: appViewModel.selectedOrderId) {
                NavigationLink(destination: OrderView(order: lastOrder), isActive: $appViewModel.showOrderView) {
                    EmptyView()
                }
            } else {
                Text("Order not found")
            }
        }
    }

    // Chat link navigation
    private var chatLink: some View {
        NavigationLink(destination: MessageView( customerId: appViewModel.selectedCustomerId, messageName: appViewModel.selectedCustomerId, phoneNumber: ""), isActive: $appViewModel.showChatView) {
            EmptyView()
        }
    }

    var body: some View {
        
        ZStack(alignment: .bottom) {
            Group {
                if appViewModel.showOrderView { orderLink }
                if appViewModel.showChatView { chatLink }
            }
            if isViewLoaded {
                listSection
                if let selectedOrder = viewModel.selectedOrder {
                    NavigationLink(destination: OrderView(order: selectedOrder), isActive: $viewModel.isNavigationActive) {
                        EmptyView()
                    }
                }
                if let lastOrder = viewModel.lastOrder, UserDefaults.standard.string(forKey: "autoPrint") == "1" {
                    NavigationLink(destination: OrderView(order: lastOrder), isActive: $navigateToOrderView) {
                        EmptyView()
                    }
                }
            } else {
                ProgressView("Loading...")
            }
        }
        .navigationTitle(isViewLoaded && !appViewModel.showChatView ? navigationTitle : "")
        .if(isViewLoaded) { view in
            view.searchable(text: $viewModel.searchText, prompt: "Search order")
        }
        .onSubmit(of: .search) {
            viewModel.searchSubmitted = true
            viewModel.searchOrders(searchText: viewModel.searchText)
        }
        .onAppear(perform: onAppear)
        .onDisappear(perform: onDisappear)
        .fullScreenCover(isPresented: $viewRouter.isSheetPresented) {
            LoginView()
                .environmentObject(viewRouter)
                .onDisappear(perform: reloadData)
        }
        .navigationBarItems(trailing: isViewLoaded ? navigationBarTrailingItems : nil)
        .background(NavigationLink(destination: ShopView(), isActive: $showShopView) { EmptyView() }.hidden())
    }

    // List section for orders
    var listSection: some View {
        List {
            SectionView(sectionHeader: "Now", statusCodes: [2, 3, 4], viewModel: viewModel)
            SectionView(sectionHeader: "New orders", statusCodes: [1], viewModel: viewModel)
            SectionView(sectionHeader: "Sent", statusCodes: [5, 7], viewModel: viewModel)
        }
        .listStyle(PlainListStyle())
    }

    // Dynamic navigation title
    var navigationTitle: String {
        let count = viewModel.orders.count
        if count == 0 {
            return "Today"
        }
        let total = viewModel.orders.reduce(0) { $0 + $1.total }
        return "Today (\(count)) £\(String(format: "%.0f", total))"
    }


    // Navigation bar items
    var navigationBarTrailingItems: some View {
        HStack {
            if let adminIDString = UserDefaults.standard.string(forKey: "selectedAdminID"), let adminID = Int(adminIDString), adminID >= 0 && adminID <= 1000  {
                if 1 == 2{
                    Button(action: { showShopView = true }) {
                        Image(systemName: "circle.grid.3x3.fill")
                    }
                    .padding(.trailing, 2)
                }

                Button(action: { showChatView = true }) {
                    Image(systemName: "message")
                }
                .background(NavigationLink(destination: ChatsView(), isActive: $showChatView) { EmptyView() }.hidden())
                .padding(.trailing, 2)
            } else if adminID != "c" {
                if 1 == 2{
                    Button(action: { showShopView = true }) {
                        Image(systemName: "circle.grid.3x3.fill")
                    }
                    .padding(.trailing, 2)
                }
                Button(action: { showChatView = true }) {
                    Image(systemName: "message")
                }
                .background(NavigationLink(destination: ChatsView(), isActive: $showChatView) { EmptyView() }.hidden())
                .padding(.trailing, 2)
            }
            Menu {
                Button(action: { logout() }) {
                    Text("Logout")
                    Image(systemName: "arrow.right.square")
                }
            } label: {
                if !icon.isEmpty {
                    if let url = URL(string: icon), let data = try? Data(contentsOf: url), let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .frame(width: 25, height: 25)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person")
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundColor(.white)
                    }
                } else {
                    Image(systemName: "person")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(.white)
                }
            }
        }
    }

    // Actions when the view appears
    private func onAppear() {
        if !adminID.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { isViewLoaded = true }
            if !viewRouter.isSheetPresented {
                viewModel.getOrders()
                startTimer()
            }
        } else {
            viewRouter.isSheetPresented = true
        }
    }

    // Actions when the view disappears
    private func onDisappear() {
        timer?.invalidate()
        viewModel.cancelAllRequests()
    }

    // Start the timer to refresh orders
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            if !viewModel.searchSubmitted {
                viewModel.getOrders()
            }
        }
    }

    // Logout function
    private func logout() {
        clearCookies()
        viewModel.orders.removeAll()  // Clear the orders
        viewModel.filteredOrders.removeAll()
        viewRouter.isSheetPresented = true
    }

    // Reload data after login
    private func reloadData() {
        adminID = UserDefaults.standard.string(forKey: "selectedAdminID") ?? ""
        if !adminID.isEmpty {
            viewModel.getOrders()
            startTimer()
        } else {
            viewRouter.isSheetPresented = true
        }
    }
}

