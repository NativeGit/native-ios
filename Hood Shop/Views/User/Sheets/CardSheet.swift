import SwiftUI

struct CardSheet: View {
    @Binding var cards: [Payment]
    var onAddNewCard: () -> Void
    var onCardSelected: ((Payment) -> Void)?
    @Environment(\.presentationMode) var presentationMode
    @State private var showingActionSheet = false
    @State private var paymentToDelete: Payment?
    private let applePayPayment = Payment(id: "applePay", brand: "Apple Pay", last4: "", isDefault: false)

    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: 5)
                .frame(width: 45, height: 4.5)
                .foregroundColor(.gray)
                .padding()
            List {
                Button(action: { self.onCardSelected?(applePayPayment); presentationMode.wrappedValue.dismiss() }) {
                    paymentRow(for: applePayPayment, isApplePay: true)
                }
                .buttonStyle(PlainButtonStyle())
                ForEach(cards) { card in
                    HStack {
                        Button(action: { self.onCardSelected?(card); presentationMode.wrappedValue.dismiss() }) {
                            paymentRow(for: card, isApplePay: false)
                        }
                        .buttonStyle(PlainButtonStyle())
                        Image(systemName: "ellipsis")
                            .foregroundColor(.primary)
                            .padding(.trailing)
                            .onTapGesture {
                                self.paymentToDelete = card
                                self.showingActionSheet = true
                            }
                    }
                    .frame(height: 50)
                }
                Button(action: { onAddNewCard(); presentationMode.wrappedValue.dismiss() }) {
                    addNewCardRow
                }
            }
            .listStyle(PlainListStyle())
        }
        .navigationBarTitle("Payment Methods", displayMode: .inline)
        .actionSheet(isPresented: $showingActionSheet) {
            ActionSheet(title: Text("Actions"), message: Text("Choose an option"), buttons: [
                .destructive(Text("Delete")) {
                    if let paymentToDelete = paymentToDelete {
                        deletePayment(paymentToDelete)
                        self.onCardSelected?(applePayPayment)
                    }
                },
                .cancel()
            ])
        }
    }

    func applePayIsDefault() -> Bool {
        !cards.contains { $0.isDefault }
    }

    private func paymentRow(for payment: Payment, isApplePay: Bool) -> some View {
        let isDefault = isApplePay ? applePayIsDefault() : payment.isDefault
        return HStack {
            Image(systemName: isApplePay ? "applelogo" : "creditcard.fill")
                .padding(.trailing, 4)
                .foregroundColor(isDefault ? .primary : .gray)
            Text(isApplePay ? "Apple Pay" : "\(payment.brand) ending in \(payment.last4)")
                .foregroundColor(isDefault ? .primary : .gray)
            Spacer()
        }
    }

    private var addNewCardRow: some View {
        HStack {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .bold))
                .padding(.trailing, 8)
                .foregroundColor(assets.brandColor)
            Text("Add New Card")
                .bold()
                .foregroundColor(assets.brandColor)
            Spacer()
        }
        .frame(height: 50)
    }

    func deletePayment(_ payment: Payment) {
        cards.removeAll { $0.id == payment.id }
        if payment.isDefault, let firstCard = cards.first {
            setDefaultPaymentMethod(card: firstCard)
        }
        saveCards()
    }

    func setDefaultPaymentMethod(card: Payment? = nil, isApplePay: Bool = false) {
        for index in cards.indices { cards[index].isDefault = false }
        if let card = card {
            if let index = cards.firstIndex(where: { $0.id == card.id }) { cards[index].isDefault = true }
        }
        if let card = card {
            onCardSelected?(card)
        } else if isApplePay {
            onCardSelected?(applePayPayment)
        }
        presentationMode.wrappedValue.dismiss()
    }

    func saveCards() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(cards) {
            UserDefaults.standard.set(encoded, forKey: "SavedCards")
        }
    }
}
