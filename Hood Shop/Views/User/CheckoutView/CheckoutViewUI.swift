import SwiftUI

struct CheckoutViewUI {
    struct PickerSection: View {
        @Binding var selectedOption: DeliveryOption

        var body: some View {
            if assets.pickup == true{
                Picker("Delivery or Pickup", selection: $selectedOption) {
                    ForEach(DeliveryOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                .onChange(of: selectedOption) { newValue in
                    UserDefaults.standard.set(newValue.rawValue, forKey: "selectedOption")
                }
            }
        }
    }

    struct DeliverySection: View {
        @ObservedObject var viewModel: CheckoutViewModel

        var body: some View {
            Section {
                VStack(alignment: .leading) {
                    Text(viewModel.selectedOption == .delivery ? "Delivery" : "Pickup")
                        .bold()
                        .font(.system(size: 16))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if viewModel.selectedOption == .delivery {
                        Button(action: {
                            if viewModel.defaultAddress == nil {
                                viewModel.showingDeliveryAddressFullScreen = true
                            } else {
                                viewModel.showingAddressesSheet = true
                            }
                        }) {
                            HStack {
                                Image(systemName: viewModel.defaultAddress == nil ? "plus" : "location")
                                    .padding(.trailing, 5)
                                Text(viewModel.defaultAddress == nil ? "Add delivery Address" : "\(viewModel.defaultAddress!.postcode), \(viewModel.defaultAddress!.street)")
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                        }
                
                        .padding(.vertical)
                        .cornerRadius(5)
                        .shadow(radius: 1)
                    }
                    Button(action: { viewModel.showTimeSheet = true }) {
                        HStack {
                            Image(systemName: "clock").padding(.trailing, 5)
                            Text(viewModel.displayText)
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding(.vertical)
                        .cornerRadius(5)
                        .shadow(radius: 1)
                    }
                }
            }
            .padding()
        }
    }

    struct PaymentSection: View {
        @ObservedObject var viewModel: CheckoutViewModel

        var body: some View {
            Section {
                VStack(alignment: .leading) {
                    Text("Payment")
                        .font(.system(size: 16))
                        .bold()
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button(action: { viewModel.showingCardsSheet = true }) {
                        HStack {
                            if let selectedPaymentMethod = viewModel.selectedPaymentMethod, selectedPaymentMethod.id != "applePay" {
                                HStack {
                                    Image(systemName: "creditcard.fill").font(.system(size: 13)).padding(.trailing, 4)
                                    Text("\(selectedPaymentMethod.brand) ending in \(selectedPaymentMethod.last4)")
                                }
                            } else {
                                HStack {
                                    Image(systemName: "applelogo").padding(.trailing, 8)
                                    Text("Apple Pay")
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding(.vertical)
                        .cornerRadius(5)
                        .shadow(radius: 1)
                    }
                    Button(action: { viewModel.showingVoucher = true }) {
                        HStack {
                            Image(systemName: "plus").padding(.trailing, 5)
                            Text("Voucher Code")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding(.vertical)
                        .cornerRadius(5)
                        .shadow(radius: 1)
                    }
                }
                .padding()
            }
        }
    }

    struct OrderSummarySection: View {
        @ObservedObject var viewModel: CheckoutViewModel

        var body: some View {
            Section {
                VStack(alignment: .leading) {
                    Text("Order Summary")
                        .font(.system(size: 16))
                        .bold()
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack {
                        Text("Items")
                        Spacer()
                        Text("£\(viewModel.shopModel.subtotal, specifier: "%.2f")")
                    }
                    .padding(.vertical)

                    if viewModel.selectedOption == .delivery {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(viewModel.distance == 0 ? "Delivery" : "Delivery (\(String(format: "%.1f", viewModel.distance * 1.3)) mi)")
                                if viewModel.deliveryFee > 0 && viewModel.defaultAddress != nil  {
                                    Text("Free above £\(Int(viewModel.freeAbove))")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                        .padding(.bottom, -15)
                                }
                            }
                            Spacer()
                            Text(viewModel.defaultAddress == nil ? "Add address" : viewModel.deliveryFee == 0 ? "Free" : "£\(viewModel.deliveryFee, specifier: "%.2f")")
                        }
                        .padding(.vertical)
                    }

                    HStack {
                        Text("Total").bold()
                        Spacer()
                        Text("£\(viewModel.shopModel.subtotal + viewModel.deliveryFee, specifier: "%.2f")").bold()
                    }
                    .padding(.vertical)
                }
                .padding()
            }
        }
    }

    struct CheckoutButton: View {
        @ObservedObject var viewModel: CheckoutViewModel

        var body: some View {
            VStack {
                if viewModel.defaultAddress != nil || viewModel.selectedOption != .delivery {
                    if let selectedPaymentMethod = viewModel.selectedPaymentMethod, selectedPaymentMethod.id != "applePay" {
                        CardButton(viewModel: viewModel)
                    } else {
                        ApplePayButton(viewModel: viewModel)
                    }
                } else {
                    AddAddressButton(viewModel: viewModel)
                }
            }
            .background(Color.clear.safeAreaInset(edge: .bottom) { Color.clear.frame(height: 0) })
        }
    }

    struct CardButton: View {
        @ObservedObject var viewModel: CheckoutViewModel

        var body: some View {
            Button(action: { viewModel.sendCompleteOrderRequest() }) {
                HStack {
                    Text("Confirm order")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding()
                .frame(height: 50)
                .background(assets.brandColor)
                .cornerRadius(10)
                .padding(.bottom, 10)
            }
            .padding(.horizontal, 10)
        }
    }

    struct ApplePayButton: View {
        @ObservedObject var viewModel: CheckoutViewModel

        var body: some View {
            Button(action: {
                if let stripeVC = viewModel.stripe as? Stripe {
                    stripeVC.handleApplePayButtonTapped(
                        amount: (viewModel.shopModel.subtotal + viewModel.deliveryFee),
                        shopName: assets.name,
                        orderId: viewModel.orderId ?? "",
                        customerName: viewModel.loadCookie(name: "userName") ?? "Hello"
                    )
                }
            }) {
                HStack {
                    Spacer()
                    Image(systemName: "applelogo")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                    Text("Pay")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding()
                .frame(height: 50)
                .background(Color.black)
                .cornerRadius(10)
                .padding(.bottom, 10)
            }
            .padding(.horizontal, 10)
        }
    }

    struct AddAddressButton: View {
        @ObservedObject var viewModel: CheckoutViewModel

        var body: some View {
            Button(action: { viewModel.showingDeliveryAddressFullScreen = true }) {
                HStack {
                    Text("Add delivery Address")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding()
                .frame(height: 50)
                .background(assets.brandColor)
                .cornerRadius(10)
                .padding(.bottom, 10)
            }
            .padding(.horizontal, 10)
        }
    }

    struct BasketButton: View {
        @ObservedObject var viewModel: CheckoutViewModel

        var body: some View {
            Button(action: { viewModel.showingBasketSheet = true }) {
                ZStack {
                    Image("basket").resizable().aspectRatio(contentMode: .fit).frame(width: 26, height: 26)
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text("\(viewModel.filteredBasketCount)").font(.caption).foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 2).background(RoundedRectangle(cornerRadius: 10).fill(assets.brandColor)).fixedSize().offset(x: 8, y: -12)
                        }
                    }
                }
                .frame(width: 26, height: 26)
            }
        }
    }

    struct LoginButton: View {
        @ObservedObject var viewModel: CheckoutViewModel

        var body: some View {
            Button(action: { viewModel.handleSignInButton() }) {
                Text("Login").foregroundColor(assets.brandColor).padding(.vertical, 8).padding(.horizontal, 2).padding(.leading, 8).font(.system(size: 14, weight: .medium)).cornerRadius(8)
            }
        }
    }
}
