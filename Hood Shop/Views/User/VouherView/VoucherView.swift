import SwiftUI

struct VoucherView: View {
    @State private var voucher = ""
    @State private var voucherValid = true
    @FocusState private var focusedField: Field?
    @Environment(\.presentationMode) var presentationMode
    @State private var isRedeeming = false
    @State private var alertMessage = ""
    @State private var activeAlert: ActiveAlert?
    @Binding var discount: Double
    @Environment(\.colorScheme) var colorScheme

    enum ActiveAlert: Identifiable {
        case success, failure
        var id: Self { self }
    }

    func redeemVoucher(code: String) {
        var redeemedVouchers = UserDefaults.standard.stringArray(forKey: "RedeemedVouchers") ?? []
        if redeemedVouchers.contains(code) {
            onRedeemFailure()
        } else {
            onRedeemSuccess(code: code)
        }
    }

    var body: some View {
        NavigationView {
            VStack {
                InputView(label: "Voucher", text: $voucher, focused: $focusedField, equals: .voucher)
                    .autocapitalization(.allCharacters)
                    .padding()
                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Voucher")
                        .bold()
                }
            }
            .navigationBarTitle("", displayMode: .inline)
            .navigationBarItems(leading: backButton, trailing: redeemButton)
            .alert(item: $activeAlert) { activeAlert in
                switch activeAlert {
                case .success:
                    return Alert(
                        title: Text("Hooray!"),
                        message: Text(alertMessage),
                        dismissButton: .default(Text("OK")) {
                            presentationMode.wrappedValue.dismiss()
                        }
                    )
                case .failure:
                    return Alert(
                        title: Text("Couldn't Redeem Code"),
                        message: Text(alertMessage),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
        }
    }

    private var backButton: some View {
        Button(action: {
            presentationMode.wrappedValue.dismiss()
        }) {
            HStack {
                Image(systemName: "arrow.left")
                    .foregroundColor(.primary)
            }
        }
    }

    @ViewBuilder
    private var redeemButton: some View {
        if isRedeeming {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                .frame(width: 35, height: 35)
        } else {
            Button(action: startRedeeming) {
                Text("Redeem")
                    .foregroundColor(voucher.isEmpty ? .gray : assets.brandColor)
            }
            .disabled(voucher.isEmpty)
        }
    }

    private func startRedeeming() {
        guard !voucher.isEmpty else { return }
        isRedeeming = true
        let redeemedVouchers = UserDefaults.standard.stringArray(forKey: "RedeemedVouchers") ?? []
        if redeemedVouchers.contains(voucher) {
            alertMessage = "This voucher has already been redeemed."
            isRedeeming = false
            activeAlert = .failure
            return
        }

        let urlString = "https://hoodapp.co.uk/get.aspx?type=162&voucher=\(voucher)"
        guard let url = URL(string: urlString) else {
            isRedeeming = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isRedeeming = false
                if let error = error {
                    print("HTTP Request Failed: \(error)")
                    return
                }
                guard let data = data, let responseString = String(data: data, encoding: .utf8) else {
                    return
                }
                let splitResponse = responseString.split(separator: "|").map(String.init)
                /*
                if let responseCode = splitResponse[1], responseCode == "discount05" {
                    self.onRedeemSuccess(code: self.voucher)
                    self.alertMessage = "You've successfully unlocked £5 off. Treat yourself to something nice!"
                    discount = 5
                    UserDefaults.standard.set(true, forKey: "VoucherRedeemed")
                    activeAlert = .success
                } else {
                    self.alertMessage = "Sorry, that code doesn't seem to be valid. Make sure it's been typed correctly."
                    self.onRedeemFailure()
                    activeAlert = .failure
                }
                 */
            }
        }.resume()
    }

    private func onRedeemSuccess(code: String) {
        var redeemedVouchers = UserDefaults.standard.stringArray(forKey: "RedeemedVouchers") ?? []
        redeemedVouchers.append(code)
        UserDefaults.standard.set(redeemedVouchers, forKey: "RedeemedVouchers")
        alertMessage = "Voucher redeemed successfully. You've got £5 off!"
        discount = 5
        activeAlert = .success
    }

    private func onRedeemFailure() {
        alertMessage = "Looks like this voucher's already been used or isn't valid. Let's try another one!"
        activeAlert = .failure
    }
}
