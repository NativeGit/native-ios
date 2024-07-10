import SwiftUI
import Kingfisher
import GoogleSignIn
import GoogleSignInSwift

struct ShopView: View {
    @StateObject var shopModel = ShopModel()
    @StateObject var loginManager = LoginManager(shopModel: ShopModel())
    @State private var images = [ImageData]()
    @State private var categories = [Category(name: "All")]
    @State private var selectedCategory: String? = "All"
    @State private var showMenu = false
    @State private var isHistoryViewActive = false
    @State private var showDetail = false
    @State private var basket = [Product]()
    @State private var showingBasketSheet = false
    @State private var showingProductSheet = false
    @State private var isFollowing = false
    @State private var showingShareSheet = false
    @State private var navigateToMessageView = false
    @State private var selectedCategoryId: UUID?
    @State private var isImageLargeItemViewClicked = false
    @State private var showCheckoutView = false
    @State private var showingSheet = false
    @State private var selectedProduct: Product?
    @State private var imageFormat = 0
    @State private var currentPage = 0
    @State private var showOrderStatus = false
    @State private var showOrderStatusView = true
    @State private var showOrderView = false
    @State private var selectedOrder: Order?
    @State private var animateTopPaddingChange = true
    @State private var isExpanded = false


    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack {
                        let topPadding: CGFloat = shopModel.order != nil && showOrderStatusView ? 40 : 140
                        if(assets.isHeader){
                            ShopHeaderView(navigateToMessageView: $navigateToMessageView, shopModel: shopModel).padding(.top, 100)
                        }
                        if let order = shopModel.order, showOrderStatusView {
                            let tempBinding = Binding<Order?>(
                                get: { self.selectedOrder },
                                set: { newValue in
                                    if let newValue = newValue { self.selectedOrder = newValue }
                                }
                            )
                            let orderStatus = getStatusText(for: String(order.status))
                            let orderDate = convertDateString(order.deliveryTime) ?? "Invalid Date"
                            let productImages = order.images?.split(separator: "*").map { String($0) } ?? []
                            OrderStatusView(
                                orderStatus: orderStatus,
                                orderDate: orderDate,
                                productImages: productImages,
                                orderAgainAction: {
                                    orderAgain(lastOrderId: order.orderId) {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                            showingBasketSheet = true
                                            UserDefaults.standard.removeObject(forKey: "showBasketOnce")
                                        }
                                    }
                                },
                                detailsAction: {
                                    self.selectedOrder = Order(orderId: order.orderId, customerName: order.customerName, postcode: order.postcode, address: order.address, deliveryTime: order.deliveryTime, status: order.status, phone: order.phone, total: order.total, pickupImageUrl: order.pickupImageUrl, deliveryImageUrl: order.deliveryImageUrl, courierName: "Romeo", courierPhone: "07522552608", lifecycle: order.lifecycle, images: order.images)
                                    self.showOrderView = true
                                },
                                selectedOrder: tempBinding,
                                showOrderView: $showOrderView,
                                pastOrder: order
                            )
                            .background(
                                NavigationLink(
                                    destination: selectedOrder.map { OrderView(order: $0) },
                                    isActive: $showOrderView
                                ) {
                                    EmptyView()
                                }
                            )
                            .padding(.top, 100)
                            .opacity(showOrderStatus ? 1 : 0)
                            .animation(.easeInOut(duration: 1.0))
                            .onAppear {
                                showOrderStatus = true
                                showCheckoutView = false
                                shopModel.isBasketInitialized = false
                                showingBasketSheet = false
                                if UserDefaults.standard.bool(forKey: "showBasketOnce") {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                        showingBasketSheet = true
                                        UserDefaults.standard.removeObject(forKey: "showBasketOnce")
                                        showOrderStatusView = false
                                    }
                                }
                            }
                        }
                        StickyHeader(shopModel: shopModel, selectedCategory: $selectedCategory, selectedCategoryId: $selectedCategoryId)
                            .frame(height: 55)
                            .zIndex(1)
                            .padding(.top, -100)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading) {
                            ForEach(shopModel.filteredProducts) { product in
                                Button(action: {
                                    self.selectedProduct = product
                                    self.showingProductSheet = true
                                }) {
                                    ImageItemView(product: product, shopModel: shopModel, imageFormat: imageFormat)
                                        .frame(width: (UIScreen.main.bounds.width / 2) - 5)
                                }
                            }
                        }
                        .onAppear {
                            let userId = UserDefaults.standard.string(forKey: "cid") ?? ""
                            shopModel.isBasketInitialized = false
                            shopModel.fetchProducts(orderId: "", shopId: shopId, userId: userId)
                            animateTopPaddingChange = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 7) {
                                animateTopPaddingChange = false
                            }
                        }
                        .background(
                            NavigationLink(
                                destination: MessageView(customerId: userId, messageName: assets.name, phoneNumber: ""),
                                isActive: $navigateToMessageView
                            ) {
                                EmptyView()
                            }
                        )
                        .padding(.bottom, 100)
                        .padding(.top, topPadding)
                        .animation(animateTopPaddingChange ? .easeInOut : .none)
                    }
                }
                .frame(maxWidth: .infinity)
                Spacer()
            }
            if shopModel.filteredBasketCount > 0 {
                CheckoutButton(basket: shopModel.basket, calculateTotal: {
                    return shopModel.calculateTotal(basket: shopModel.basket)
                }, showBasketSheet: $showingBasketSheet)
                    .padding(.bottom, 0)
                    .transition(.move(edge: .bottom))
                    .animation(animateTopPaddingChange ? .easeInOut : .none)
                    .onTapGesture { showingBasketSheet = true }
            }
        }
        .sheet(item: $selectedProduct, onDismiss: {
            let userId = UserDefaults.standard.string(forKey: "cid") ?? ""
            shopModel.fetchProducts(orderId: "", shopId: shopId, userId: userId)
        }) { product in
            let dynamicHeight = calculateDynamicHeight(for: product, in: shopModel)
            ProductSheetView(product: product, imageFormat: imageFormat, shopModel: shopModel)
                .applyDynamicDetents(.customHeight(dynamicHeight))
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: ["Check out this shop: \(assets.name)"])
                .applyDynamicDetents(.mediumLarge)
        }
        .navigationTitle("Beigel Bake")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack {
                    LogoTitleView()
                    Spacer()
                }
            }
        }
        .navigationBarItems(trailing:
            HStack {
                rewardsButton
                loginButton.padding(.top, -0)
                    .environmentObject(loginManager)
            }
        )
        .background(
            NavigationLink(destination: HistoryView(), isActive: $isHistoryViewActive) {
                EmptyView()
            }
        )
        .onAppear { shopModel.checkCookies() }
        .edgesIgnoringSafeArea(.all)
        .background(NavigationLink(destination: CheckoutView(shopModel: shopModel) , isActive: $showCheckoutView) { EmptyView() })
        .sheet(isPresented: $showingBasketSheet) {
            BasketSheetView(basket: $shopModel.basket, isImageLargeItemViewClicked: $isImageLargeItemViewClicked, onCheckout: {
                self.showCheckoutView = true
            }, shopModel: shopModel, isPresentedFromCheckoutView: false)
            .applyDynamicDetents(.customHeight(shopModel.dynamicHeight))
        }
        .preferredColorScheme(.light)
        .background(Color.white)
        .foregroundColor(Color.black)
    }

    var loggedInMenuButton: some View {
        Menu {
            Button("My orders") { isHistoryViewActive = true }
            Button("Logout") { logout() }
        } label: {
            if let profileImageURL = shopModel.profileImageURL {
                AsyncImage(url: profileImageURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 24, height: 24)
                        .clipShape(Circle())
                } placeholder: {
                    ProgressView().frame(width: 26, height: 26)
                }
            } else {
                Image(systemName: "person.crop.circle")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 26, height: 26)
                    .clipShape(Circle())
                    .foregroundColor(.black)
            }
        }
    }

    var loginButton: some View {
        if shopModel.isLoggedIn {
            AnyView(loggedInMenuButton)
        } else {
            AnyView(
                Button(action: {
                    loginManager.handleSignInButton()
                }) {
                    Text("Login")
                        .foregroundColor(assets.brandColor)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 2)
                        .font(.system(size: 14, weight: .medium))
                        .cornerRadius(8)
                }
            )
        }
    }

    func logout() {
        clearCookies()
        shopModel.isLoggedIn = false
        shopModel.isBasketInitialized = false
        shopModel.fetchProducts(orderId: "", shopId: shopId, userId: "")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.shopModel.isBasketInitialized = false
            self.shopModel.fetchProducts(orderId: "", shopId: shopId, userId: "")
        }
    }
}
