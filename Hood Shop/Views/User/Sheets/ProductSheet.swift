import SwiftUI
import Kingfisher

struct ProductSheetView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var product: Product
    @State private var amount = 1
    @State private var total = 0.00
    @State private var selectedOption: Option?
    @State private var selectedAdditions: Set<UUID> = []
    @State private var hasInteracted = false
    
    let imageFormat: Int
    var shopModel = ShopModel()
    let userId = UserDefaults.standard.string(forKey: "cid") ?? ""

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                ScrollView {
                    VStack(spacing: 0) {
                        KFImage(URL(string: product.imageURL))
                            .resizable()
                            .aspectRatio(contentMode: imageFormat == 1 ? .fit : .fill)
                            .frame(maxWidth: .infinity, maxHeight: 350)
                            .background(Color.white)
                            .clipped()
                            .padding(.top, 15)
                        
                        VStack(alignment: .leading, spacing: 0) {
                            Text(product.name)
                                .font(.system(size: 14, weight: .bold))
                                .padding(.bottom, 1)
                                .padding([.leading, .trailing], 15)
                                .foregroundColor(.primary)
                            Text(product.price, format: .currency(code: "GBP").precision(.fractionLength(2)))
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(Color(hex: "#6B6B6B"))
                                .padding([.leading, .trailing], 15)
                            Text(product.description)
                                .font(.system(size: 14, weight: .regular))
                                .padding(.vertical, 10)
                                .padding([.leading, .trailing], 15)
                                .foregroundColor(.primary)

                            if !product.options.isEmpty {
                                let options = product.options.filter { $0.type == .option }
                                if !options.isEmpty {
                                    Text("Options (choose one)")
                                        .font(.system(size: 16, weight: .bold))
                                        .padding(.vertical, 10)
                                        .padding([.leading, .trailing], 15)
                                    ForEach(product.options.filter { $0.type == .option }) { option in
                                        Button(action: {
                                            selectedOption = option
                                            product.options.forEach { $0.isSelected = false }
                                            option.isSelected = true
                                            updateTotal()
                                        }) {
                                            HStack {
                                                RadioButton(isSelected: option.isSelected) {
                                                    selectedOption = option
                                                    product.options.forEach { $0.isSelected = false }
                                                    option.isSelected = true
                                                    updateTotal()
                                                }
                                                Text(option.name)
                                                    .padding(.leading, 10)
                                                    .font(.system(size: 14, weight: .bold))
                                                Spacer()
                                                if option.price > 0 {
                                                    Text("+ \(option.price, format: .currency(code: "GBP"))")
                                                        .foregroundColor(Color(hex: "#6B6B6B"))
                                                        .font(.system(size: 14, weight: .regular))
                                                }
                                            }
                                            .padding(.vertical, 5)
                                            .padding([.leading, .trailing], 15)
                                        }
                                        .contentShape(Rectangle())
                                    }
                                }
                            }

                            if !product.options.isEmpty {
                                let additions = product.options.filter { $0.type == .addition }
                                if !additions.isEmpty {
                                    Text("Additions: (choose up to \(additions.compactMap { $0.valueMax }.max() ?? 3))")
                                        .font(.headline)
                                        .padding(.vertical, 10)
                                        .padding([.leading, .trailing], 15)
                                    ForEach(additions) { addition in
                                        Button(action: {
                                            if selectedAdditions.contains(addition.id) {
                                                selectedAdditions.remove(addition.id)
                                            } else if selectedAdditions.count < additions.compactMap({ Int($0.valueMax ?? 0) }).max() ?? 3 {
                                                selectedAdditions.insert(addition.id)
                                            }
                                            addition.isSelected.toggle()
                                            updateTotal()
                                        }) {
                                            HStack {
                                                CheckBox(isSelected: selectedAdditions.contains(addition.id)) {
                                                    if selectedAdditions.contains(addition.id) {
                                                        selectedAdditions.remove(addition.id)
                                                    } else if selectedAdditions.count < additions.compactMap({ Int($0.valueMax ?? 0) }).max() ?? 3 {
                                                        selectedAdditions.insert(addition.id)
                                                    }
                                                    addition.isSelected.toggle()
                                                    updateTotal()
                                                }
                                                Text(addition.name)
                                                    .padding(.leading, 10)
                                                    .font(.system(size: 14, weight: .bold))
                                                Spacer()
                                                if addition.price > 0 {
                                                    Text("+ \(addition.price, format: .currency(code: "GBP"))")
                                                        .foregroundColor(Color.gray)
                                                        .font(.system(size: 14, weight: .regular))
                                                }
                                            }
                                            .padding(.vertical, 5)
                                            .padding([.leading, .trailing], 15)
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical)
                        .padding(.bottom, 25)
                    }
                }
                .foregroundColor(.primary)
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color(UIColor(hex: "#EBEBEB")))
                            .frame(width: 40, height: 40)
                        Image(systemName: "xmark")
                            .resizable()
                            .frame(width: 15, height: 15)
                            .foregroundColor(.black)
                    }
                }
                .padding([.top, .trailing], 10)
            }
            
            HStack {
                HStack {
                    Button(action: {
                        if amount > 1 {
                            amount -= 1
                            hasInteracted = true
                            updateTotal()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 30, height: 30)
                            Image(systemName: "minus")
                                .frame(width: 15)
                                .foregroundColor(.black)
                        }
                    }
                    Text("\(amount)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.black)
                        .frame(width: 50, alignment: .center)
                    Button(action: {
                        amount += 1
                        hasInteracted = true
                        updateTotal()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 30, height: 30)
                            Image(systemName: "plus")
                                .resizable()
                                .frame(width: 15, height: 15)
                                .foregroundColor(.black)
                        }
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 8)
                .background(Color(UIColor.lightGray).opacity(0.2))
                .cornerRadius(8)
                
                Spacer()
                
                Button(action: {
                    if amount == 0 {
                        removeFromOrder()
                    } else {
                        addToOrder()
                    }
                }) {
                    HStack {
                        Text(buttonLabel)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                        Spacer()
                        Text("£\(amount == 0 ? product.price : total, specifier: "%.2f")")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding()
                    .frame(height: 49)
                    .background(buttonColor)
                    .cornerRadius(8)
                }
                .frame(maxWidth: 200)
            }
            .padding(.horizontal)
            .background(Color.white)
        }
        .background(Color.white)
        .onAppear {
            if let firstOption = product.options.first(where: { $0.type == .option }) {
                selectedOption = firstOption
                product.options.forEach { $0.isSelected = false }
                firstOption.isSelected = true
            }
            amount = product.options.isEmpty && product.amount > 0 ? product.amount : 1
            updateTotal()
        }
    }
    
    private var buttonLabel: String {
        if amount == 0 {
            return "Remove"
        } else {
            return shopModel.basket.contains(where: { $0.id == product.id }) && product.options.isEmpty ? "Update order" : "Add to order"
        }
    }

    private var buttonColor: Color {
        return amount == 0 ? .red : assets.brandColor
    }

    private func updateTotal() {
        var newTotal = product.price
        if let selectedOption = selectedOption {
            newTotal += selectedOption.price
        }
        newTotal += product.options.filter { $0.type == .addition && $0.isSelected }.reduce(0) { $0 + $1.price }
        total = newTotal * Double(amount)
    }

    private func addToOrder() {
        shopModel.addToBasket(userId: userId, product: product, amount: amount, edit: 0) { success in
            if success { presentationMode.wrappedValue.dismiss() }
        }
    }

    private func removeFromOrder() {
        shopModel.addToBasket(userId: userId, product: product, amount: 0, edit: 0) { _ in
            presentationMode.wrappedValue.dismiss()
        }
    }
}


