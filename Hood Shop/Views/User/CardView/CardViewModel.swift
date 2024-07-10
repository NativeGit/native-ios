import Foundation
import StripePaymentsUI
import SwiftUI

class CardViewModel: ObservableObject {
    @Published var cardDetails: STPCardParams?
    @Published var isLoading: Bool = false
    @Published var customerId = ""
    var onSave: (Payment) -> Void
    
    init(onSave: @escaping (Payment) -> Void) {
        self.onSave = onSave
    }
    
    func createPaymentMethod(onDismiss: @escaping () -> Void) {
        guard let card = cardDetails else {
            print("No card details entered.")
            return
        }

        let cardParams = STPPaymentMethodCardParams()
        cardParams.number = card.number
        cardParams.expMonth = NSNumber(value: card.expMonth)
        cardParams.expYear = NSNumber(value: card.expYear)
        cardParams.cvc = card.cvc

        let paymentMethodParams = STPPaymentMethodParams(card: cardParams, billingDetails: nil, metadata: nil)
        self.isLoading = true

        STPAPIClient.shared.createPaymentMethod(with: paymentMethodParams) { (paymentMethod, error) in
            self.isLoading = false
            if let error = error {
                print("Error creating PaymentMethod: \(error.localizedDescription)")
                return
            }

            guard let paymentMethod = paymentMethod else {
                print("No paymentMethod available.")
                return
            }

            let newPayment = Payment(
                id: paymentMethod.stripeId,
                brand: STPCard.string(from: paymentMethod.card?.brand ?? .unknown),
                last4: paymentMethod.card?.last4 ?? ""
            )

            self.onSave(newPayment)
            self.sendTokenToBackend(id: "1111", token: paymentMethod.stripeId, last4: newPayment.last4, brand: newPayment.brand)
            onDismiss()
        }
    }
    
    func sendTokenToBackend(id: String, token: String, last4: String, brand: String) {
        let urlString = "https://hoodapp.co.uk/app/services/stripeGateway?action=insertToken&id=\(id)&token=\(token)&last4=\(last4)&brand=\(brand)"
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error: \(error)")
                return
            }

            if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                print("Response: \(responseBody)")
            }
        }.resume()
    }
}
