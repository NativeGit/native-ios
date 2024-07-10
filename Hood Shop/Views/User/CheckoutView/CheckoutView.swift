import SwiftUI
import PassKit
import CoreLocation
import GoogleSignIn
import GoogleSignInSwift

struct CheckoutView: View {
    @StateObject private var viewModel: CheckoutViewModel
   

    init(shopModel: ShopModel) {
        _viewModel = StateObject(wrappedValue: CheckoutViewModel(shopModel: shopModel))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 10) {
                    CheckoutViewUI.PickerSection(selectedOption: $viewModel.selectedOption)
                    CheckoutViewUI.DeliverySection(viewModel: viewModel).font(.system(size: 15))
                    CheckoutViewUI.PaymentSection(viewModel: viewModel).font(.system(size: 15))
                    CheckoutViewUI.OrderSummarySection(viewModel: viewModel).font(.system(size: 15))
                }
                .background(Color.white)
            }
            CheckoutViewUI.CheckoutButton(viewModel: viewModel)
                .navigationTitle("\(assets.name) Checkout")
                .navigationBarItems(trailing: HStack {
                    CheckoutViewUI.BasketButton(viewModel: viewModel)
                    if !viewModel.isLoggedIn {
                        CheckoutViewUI.LoginButton(viewModel: viewModel)
                    }
                })
                .background(Color.white)
        }
        .onAppear { viewModel.onAppear() }
        .sheet(isPresented: $viewModel.showTimeSheet) {
            TimeSheetView(
                isScheduleLaterSelected: $viewModel.isScheduleLaterSelected,
                selectedDate: $viewModel.selectedDate,
                selectedTime: $viewModel.selectedTime,
                selectedHeight: $viewModel.sheetHeight
            ).applyDynamicDetents(.customHeight(400))
        }
        .sheet(isPresented: $viewModel.showingAddressesSheet, onDismiss: {
            viewModel.checkDeliveryRangeForDefaultAddress()
            viewModel.saveAddresses()
        }) {
            AddressSheet(
                addresses: $viewModel.addresses,
                onAddNewAddress: { },
                onAddressSelected: viewModel.setDefaultAddress,
                presentDeliveryAddressSheet: {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        viewModel.showingDeliveryAddressFullScreen = true
                    }
                }
            ).applyDynamicDetents(.customHeight(viewModel.dynamicSheetHeight))
        }
        .sheet(isPresented: $viewModel.showingBasketSheet) {
            BasketSheetView(
                basket: $viewModel.shopModel.basket,
                isImageLargeItemViewClicked: $viewModel.isImageLargeItemViewClicked,
                onCheckout: { },
                shopModel: viewModel.shopModel,
                isPresentedFromCheckoutView: true
            ).applyDynamicDetents(.customHeight(viewModel.dynamicHeight))
        }
        .sheet(isPresented: $viewModel.showingLoginSheet) {
            LoginSheetView(showingLoginSheet: $viewModel.showingLoginSheet, handleSignInButton: viewModel.handleSignInButton)
                .applyDynamicDetents(.customHeight(200))
        }
        .sheet(isPresented: $viewModel.showingCardsSheet) {
            CardSheet(
                cards: $viewModel.cards,
                onAddNewCard: {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        viewModel.showingCard = true
                    }
                },
                onCardSelected: viewModel.setDefaultCard
            ).onDisappear { viewModel.saveCards() }
             .applyDynamicDetents(.customHeight(viewModel.dynamicCardsSheetHeight))
        }
        .fullScreenCover(isPresented: $viewModel.showingVoucher) {
            VoucherView(discount: $viewModel.discount)
        }
        .fullScreenCover(isPresented: $viewModel.showingCard) {
            CardView(onSave: { newCard in
                viewModel.cards.append(newCard)
                viewModel.setDefaultCard(newCard)
                viewModel.showingCard = false
                viewModel.saveCards()
            })
        }
        .fullScreenCover(isPresented: $viewModel.showingDeliveryAddressFullScreen) {
            AddressView(viewModel: AddressViewModel(onSave: { address in
                viewModel.addresses.indices.forEach { viewModel.addresses[$0].isDefault = false }
                var newAddress = address
                newAddress.isDefault = true
                viewModel.defaultAddress = newAddress
                viewModel.addresses.append(newAddress)
                viewModel.checkDeliveryRangeForDefaultAddress()
                viewModel.saveAddresses()
                viewModel.showingDeliveryAddressFullScreen = false
            }))
        }
        NavigationLink(
            destination: OrderView(order: viewModel.currentOrder ?? Order())
                .background(NavigationStackManager { navController in
                    var viewControllers = navController.viewControllers
                    if viewControllers.count > 1 {
                        viewControllers.remove(at: viewControllers.count - 2)
                        navController.setViewControllers(viewControllers, animated: false)
                    }
                }),
            isActive: $viewModel.showOrderView
        ) {
            EmptyView()
        }
    }
}
