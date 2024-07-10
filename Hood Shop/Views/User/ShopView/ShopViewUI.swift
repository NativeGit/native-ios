import SwiftUI
import Kingfisher

struct RadioButton: View {
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(isSelected ? assets.brandColor : Color.gray.opacity(0.2))
                .frame(width: 20, height: 20)
                .overlay(Circle().stroke(Color.clear, lineWidth: 2))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CheckBox: View {
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Rectangle()
                .fill(isSelected ? assets.brandColor : Color.gray.opacity(0.2))
                .frame(width: 20, height: 20)
                .overlay(
                    Image(systemName: "checkmark")
                        .foregroundColor(.white)
                        .opacity(isSelected ? 1 : 0)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ImageItemView: View {
    @ObservedObject var product: Product
    @ObservedObject var shopModel: ShopModel
    @State private var isDebouncing = false
    @State private var debounceWorkItem: DispatchWorkItem?
    @State private var showingProductSheet = false
    let userId = UserDefaults.standard.string(forKey: "cid") ?? ""
    let imageFormat: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            KFImage(URL(string: product.imageURL))
                .resizable()
                .aspectRatio(contentMode: imageFormat == 1 ? .fill : .fill)
                .frame(width: (UIScreen.main.bounds.width / 2) + 3, height: 180)
                .clipped()
                .padding(.bottom, 5)
                .padding(.leading, 1.5)
            Text(product.name)
                .font(.system(size: 14, weight: .medium))
                .bold()
                .padding([.leading, .trailing], 15)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Text(formatPrice(product.price))
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(Color(hex: "#6B6B6B"))
                .bold()
                .padding([.leading, .trailing], 15)
                .padding(.bottom, 20)
        }
        .background(
            ZStack {
                Color.white
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 34, height: 34)
                                .clipShape(CustomCorner(corners: [.topLeft], radius: 68))
                                .overlay(
                                    Text("+")
                                        .font(.system(size: 20, weight: .light))
                                        .foregroundColor(Color.black)
                                )
                                .onTapGesture {
                                    if let index = shopModel.basket.firstIndex(where: { $0.id == product.id }) {
                                        shopModel.basket[index].amount += 1
                                    } else {
                                        let dummyProduct = Product(
                                            id: product.id,
                                            name: product.name,
                                            description: "",
                                            price: product.price,
                                            imageURL: product.imageURL,
                                            status: 1,
                                            category: "Dummy Category",
                                            amount: product.amount + 1
                                        )
                                        shopModel.basket.append(dummyProduct)
                                    }

                                    if product.options.count > 0 {
                                        showingProductSheet = true
                                    } else {
                                        product.amount += 1
                                        debounceAddToBasket(edit: 0)
                                    }
                                }

                            if product.amount > 0 {
                                Text("\(product.amount)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(6)
                                    .background(assets.brandColor)
                                    .clipShape(Circle())
                                    .offset(x: 12, y: -12)
                            }
                        }
                    }
                    .padding(.trailing, 15)
                    .padding(.bottom, 0)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onReceive(shopModel.$products) { products in
            if let updatedProduct = products.first(where: { $0.id == product.id }) {
                product.amount = updatedProduct.amount
            }
        }
        .sheet(isPresented: $showingProductSheet) {
            let dynamicHeight = calculateDynamicHeight(for: product, in: shopModel)
            ProductSheetView(product: product, imageFormat: imageFormat, shopModel: shopModel)
                .applyDynamicDetents(.customHeight(dynamicHeight))
        }
    }

    func calculateDynamicHeight(for product: Product, in shopModel: ShopModel) -> CGFloat {
        let optionsCount = product.options.filter { $0.type == .option }.count
        let additionsCount = product.options.filter { $0.type == .addition }.count
        let optionsHeight = optionsCount > 0 ? CGFloat(optionsCount) * 30 + 60 : 0
        let additionsHeight = additionsCount > 0 ? CGFloat(additionsCount) * 30 + 60 : 0
        let descriptionFont = UIFont.systemFont(ofSize: 14, weight: .regular)
        let descriptionPadding: CGFloat = 50
        let descriptionHeight = product.description.boundingRect(
            with: CGSize(width: UIScreen.main.bounds.width - 30, height: .greatestFiniteMagnitude),
            options: .usesLineFragmentOrigin,
            attributes: [.font: descriptionFont],
            context: nil
        ).height + descriptionPadding

        return optionsHeight + additionsHeight + descriptionHeight + 520
    }

    private func formatPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "GBP"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: price)) ?? "£0.00"
    }

    private func debounceAddToBasket(edit: Int) {
        debounceWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            shopModel.addToBasket(userId: userId, product: product, amount: product.amount, edit: edit) { success in
                DispatchQueue.main.async {
                    if !success {
                        product.amount -= 1
                    }
                }
            }
        }
        debounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: workItem)
    }
}

struct CustomCorner: Shape {
    var corners: UIRectCorner
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

struct CheckoutButton: View {
    let basket: [Product]
    let calculateTotal: () -> String
    @Binding var showBasketSheet: Bool

    var filteredBasketCount: Int {
        basket.filter { $0.amount > 0 }.count
    }

    var body: some View {
        Button(action: { self.showBasketSheet = true }) {
            HStack {
                Text("\(filteredBasketCount)")
                    .foregroundColor(assets.brandColor)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.white))
                    .font(.system(size: 12, weight: .bold))
                Text("View bag")
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Text(calculateTotal())
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 15)
            .background(assets.brandColor)
            .cornerRadius(10)
            .shadow(radius: 5)
        }
        .frame(height: 70)
        .padding(.horizontal, 10)
        .padding(.bottom, 20)
    }
}

struct StickyHeader: View {
    @ObservedObject var shopModel: ShopModel
    @Binding var selectedCategory: String?
    @Binding var selectedCategoryId: UUID?

    var body: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        ForEach(shopModel.categories) { category in
                            Text(category.name)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .foregroundColor(category.id == shopModel.selectedCategoryId ? .primary : Color(hex: "#777777"))
                                .cornerRadius(20)
                                .font(.system(size: 14, weight: .medium))
                                .overlay(
                                    VStack {
                                        Spacer()
                                        Rectangle()
                                            .frame(height: category.id == shopModel.selectedCategoryId ? 1 : 0)
                                            .foregroundColor(.black)
                                    }
                                )
                                .onTapGesture {
                                    shopModel.selectedCategoryId = category.id
                                    shopModel.selectedCategory = category.name
                                }
                        }
                    }
                    .padding(.horizontal, 10)
                }
                .frame(height: 43)
                .overlay(
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundColor(Color(hex: "#CFCFCF"))
                        .padding(.top, 42),
                    alignment: .top
                )
            }
            .background(Color.white)
            .padding(.top, 85)
            .offset(y: geometry.frame(in: .global).minY < 0 ? -geometry.frame(in: .global).minY : 0)
            .zIndex(1)
        }
    }
}

var rewardsButton: some View {
    Button(action: { print("Rewards button tapped") }) {
        Image(systemName: "heart")
            .frame(width: 30, height: 30)
            .foregroundColor(.black)
    }
}

struct ShopHeaderView: View {
    @State private var isFollowing = false
    @Binding var navigateToMessageView: Bool
    @State private var showingSheet = false
    @State private var selectedCategoryId: String? = nil
    @State private var selectedCategory: String? = nil

    var shopModel: ShopModel

    var body: some View {
        VStack(spacing: 8) {
            KFImage(URL(string: assets.icon))
                .resizable()
                .scaledToFill()
                .frame(width: 90, height: 90)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.gray, lineWidth: 1))
            
            Text("@beigel_bake")
                .foregroundColor(.primary)
                .padding(.horizontal, 15)
                .font(.system(size: 15, weight: .medium))
            
            HStack(spacing: 5) {
                Button(action: { self.navigateToMessageView = true }) {
                    Text("message")
                        .foregroundColor(.primary)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .font(.system(size: 14, weight: .medium))
                }
                
                Button(action: {
                    let urlString = "https://www.instagram.com/\(assets.instagram)/"
                    if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text("Instagram")
                        .foregroundColor(.primary)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .font(.system(size: 14, weight: .medium))
                }
            }
            .padding(.top, 5)
            
            Text(assets.bio)
                .font(.system(size: 14))
                .lineSpacing(3)
                .padding(.top, 5)
        }
        .padding(.horizontal)
        .padding(.bottom, 20)
        .padding(.top, 3)
        .onAppear {
            let userId = UserDefaults.standard.string(forKey: "cid") ?? ""
            shopModel.fetchProducts(orderId: "", shopId: shopId, userId: userId)
        }
    }
}
