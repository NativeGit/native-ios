import StripeApplePay
import PassKit
import UIKit
import StripeCore


class Stripe: UIViewController, ApplePayContextDelegate {
    var paymentStatusCallback: ((STPApplePayContext.PaymentStatus, Error?) -> Void)?
   
    let applePayButton: PKPaymentButton = PKPaymentButton(paymentButtonType: .plain, paymentButtonStyle: .black)
    

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Only offer Apple Pay if the customer can pay with it
        applePayButton.isHidden = !StripeAPI.deviceSupportsApplePay()
        applePayButton.addTarget(self, action: #selector(handleApplePayButtonTapped), for: .touchUpInside)
        
        // Add the Apple Pay button to your view
        view.addSubview(applePayButton)
        
        // Configure the button's position and size
        applePayButton.translatesAutoresizingMaskIntoConstraints = false
        applePayButton.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        applePayButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20).isActive = true
    }

    func getPi(amount: Double, shopName: String, orderId: String, customerName: String, completion: @escaping () -> Void) {
        
        var components = URLComponents(string: "https://hoodapp.co.uk/app/services/stripegateway")
        components?.queryItems = [
            URLQueryItem(name: "action", value: "getpi"),
            URLQueryItem(name: "amount", value: "\(Int(amount*100))"),
            URLQueryItem(name: "shopname", value: shopName.replacingOccurrences(of: " ", with: "-")),
            URLQueryItem(name: "name", value: customerName.replacingOccurrences(of: " ", with: "-")),
            URLQueryItem(name: "orderId", value: orderId)
        ]
        
        guard let url = components?.url else {
            print("Error creating URL")
            return
        }
        
        print(url)

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                print("Error fetching data:", error?.localizedDescription ?? "Unknown error")
                return
            }
            
            if let stringResult = String(data: data, encoding: .utf8) {
                let resultArray = stringResult.components(separatedBy: "|")
                // Handle the response as per your needs
                
                DispatchQueue.main.async {
                    let stripePi = resultArray[1] // Assuming that the stripePi is at index 1
                    StripePiManager.shared.stripePi = stripePi
                    completion()
                }
            }
        }.resume()
    

    }

    // ...continued in next step
    @objc func handleApplePayButtonTapped(amount: Double, shopName: String, orderId: String, customerName: String) {
        getPi(amount: amount, shopName: shopName, orderId: orderId, customerName: customerName) {
            
           
        }
        
        let merchantIdentifier = "merchant.hood23"
        
        // Round the amount to the nearest penny
        let roundedAmount = Double(round(100 * amount) / 100)
        let amountDecimal = NSDecimalNumber(value: roundedAmount)
        
       
        let paymentRequest = StripeAPI.paymentRequest(withMerchantIdentifier: merchantIdentifier, country: "GB", currency: "GBP")

        paymentRequest.supportedNetworks = [.visa, .masterCard, .amex]

        // Configure the line items on the payment request
        paymentRequest.paymentSummaryItems = [
            PKPaymentSummaryItem(label: "\(shopName)", amount: amountDecimal),
        ]
        
        // Ensure the paymentRequest is valid
        if StripeAPI.canSubmitPaymentRequest(paymentRequest) {
            if let applePayContext = STPApplePayContext(paymentRequest: paymentRequest, delegate: self) {
                applePayContext.presentApplePay(on: self)
            } else {
                print("Unable to present Apple Pay sheet")
            }
        } else {
            print("Invalid payment request")
        }
    }

    
    
}

extension Stripe {
    
    func applePayContext(_ context: STPApplePayContext, didCreatePaymentMethod paymentMethod: StripeAPI.PaymentMethod, paymentInformation: PKPayment, completion: @escaping STPIntentClientSecretCompletionBlock) {
        
        let clientSecret = StripePiManager.shared.stripePi
        
        // Log the client secret for debugging purposes
        print("Client Secret: \(clientSecret ?? "nil")")
        
        completion(clientSecret, nil)
    }

    func applePayContext(_ context: STPApplePayContext, didCompleteWith status: STPApplePayContext.PaymentStatus, error: Error?) {
        paymentStatusCallback?(status, error)
        
        switch status {
        case .success:
            // Payment succeeded, show a receipt view
            print("Payment succeeded")
        case .error:
            print("Payment failed with error: \(String(describing: error))")
        case .userCancellation:
            print("User canceled the payment")
        @unknown default:
            fatalError()
        }
    }
}


class StripePiManager {
    static let shared = StripePiManager()
    var stripePi: String?
}
