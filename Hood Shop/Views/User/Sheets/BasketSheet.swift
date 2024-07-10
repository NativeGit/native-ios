import SwiftUI
import Kingfisher

struct BasketSheetView: View {
    @Binding var basket: [Product]
    @Binding var isImageLargeItemViewClicked: Bool
    var onCheckout: () -> Void
    @Environment(\.presentationMode) var presentationMode
    let userId = UserDefaults.standard.string(forKey: "cid") ?? ""
    @ObservedObject var shopModel: ShopModel
    var isPresentedFromCheckoutView: Bool
    @State private var debounceWorkItem: DispatchWorkItem?
    @State private var previousId: Int?

    var total: String {
        let totalAmount = basket.reduce(0.0) { $0 + ($1.price * Double($1.amount)) }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "GBP"
        return formatter.string(from: NSNumber(value: totalAmount)) ?? "£0.00"
    }

    var filteredBasketCount: Int {
        basket.filter { $0.amount > 0 }.count
    }

    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: 5)
                .frame(width: 45, height: 4.5)
                .foregroundColor(.gray)
                .padding()

            ScrollView {
                ForEach(Array(zip(basket.indices, basket.filter { $0.amount > 0 })), id: \.0) { index, item in
                    HStack {
                        KFImage(URL(string: item.imageURL))
                            .resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 50)
                            .cornerRadius(8)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                        
                        VStack(alignment: .leading) {
                            Text(item.name)
                                .font(.system(size: 14, weight: .medium))
                                .padding(.bottom, 1)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(item.price, format: .currency(code: "GBP").precision(.fractionLength(2)))
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(Color(hex: "#6B6B6B"))
                        }
                        .padding(.trailing, 10)
                        
                        Spacer()
                        
                        Button(action: {
                            updateItemAmount(index: index, delta: -1)
                        }) {
                            Circle()
                                .fill(Color(UIColor.secondarySystemBackground))
                                .frame(width: 38, height: 38)
                                .overlay(
                                    Text("-")
                                        .font(.system(size: 18, weight: .regular))
                                        .foregroundColor(.primary)
                                )
                        }

                        Text("\(item.amount)")
                            .font(.callout)
                            .foregroundColor(.primary)
                            .frame(width: 20)
                        
                        Button(action: {
                            updateItemAmount(index: index, delta: 1)
                        }) {
                            Circle()
                                .fill(Color(UIColor.secondarySystemBackground))
                                .frame(width: 38, height: 38)
                                .overlay(
                                    Text("+")
                                        .font(.system(size: 18, weight: .regular))
                                        .foregroundColor(.primary)
                                )
                        }
                        .padding(.trailing, 10)
                    }
                    .background((index == 0 && isImageLargeItemViewClicked) ? Color.gray.opacity(0.1) : Color.clear)
                    .frame(height: 50)
                    .padding(.vertical, 8)
                }
            }
            if !isPresentedFromCheckoutView {
                checkoutButton
                    .padding(.horizontal, 10)
            }
        }
        .edgesIgnoringSafeArea(.all)
    }

    private var checkoutButton: some View {
        Button(action: {
            self.presentationMode.wrappedValue.dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.onCheckout()
            }
        }) {
            HStack {
                Text("Go to checkout")
                    .foregroundColor(.white)
                    .padding(.leading, 5)
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Text(total)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding()
            .frame(height: 50)
            .background(assets.brandColor)
            .cornerRadius(10)
            .padding(.bottom, 30)
        }
    }

    private func updateItemAmount(index: Int, delta: Int) {
        basket[index].amount += delta
        if let productIndex = shopModel.products.firstIndex(where: { $0.id == basket[index].id }) {
            shopModel.products[productIndex].amount = basket[index].amount
        }
        debounceAddToBasket(item: basket[index], index: index, newAmount: basket[index].amount, edit: 1)
        if basket[index].amount == 0 {
            withAnimation {
                basket.remove(at: index)
            }
        }
        if filteredBasketCount == 0 {
            presentationMode.wrappedValue.dismiss()
        }
    }

    private func debounceAddToBasket(item: Product, index: Int, newAmount: Int, edit: Int) {
        if item.id != previousId {
            previousId = item.id
            shopModel.addToBasket(userId: userId, product: item, amount: newAmount, edit: edit) { result in
                if !result {
                    basket[index].amount = newAmount - 1
                    if let productIndex = shopModel.products.firstIndex(where: { $0.id == item.id }) {
                        shopModel.products[productIndex].amount = newAmount - 1
                    }
                }
            }
            return
        }

        debounceWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            shopModel.addToBasket(userId: userId, product: item, amount: newAmount, edit: edit) { result in
                if !result {
                    basket[index].amount = newAmount - 1
                    if let productIndex = shopModel.products.firstIndex(where: { $0.id == item.id }) {
                        shopModel.products[productIndex].amount = newAmount - 1
                    }
                }
            }
        }
        debounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: workItem)
    }

}
