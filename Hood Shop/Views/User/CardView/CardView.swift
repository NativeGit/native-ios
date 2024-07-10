import SwiftUI
import StripePaymentsUI

struct CardView: View {
    @StateObject private var viewModel: CardViewModel
    @Environment(\.presentationMode) var presentationMode
    
    init(onSave: @escaping (Payment) -> Void) {
        _viewModel = StateObject(wrappedValue: CardViewModel(onSave: onSave))
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack {
                    CardTextFieldWrapper(cardDetails: $viewModel.cardDetails)
                        .frame(height: 50)
                        .padding()
                    HStack {
                        Button(action: {
                            viewModel.createPaymentMethod {
                                presentationMode.wrappedValue.dismiss()
                            }
                        }) {
                            HStack {
                                Spacer()
                                Text("Save card")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(assets.brandColor)
                            .cornerRadius(8)
                            .padding(.horizontal)
                            .disabled(viewModel.isLoading)
                        }
                    }
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("")
            .navigationViewStyle(StackNavigationViewStyle())
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .foregroundColor(.primary)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Add card").bold()
                }
            }
            .tint(.black)
        }
    }
}

struct CardTextFieldWrapper: UIViewRepresentable {
    @Binding var cardDetails: STPCardParams?

    func makeUIView(context: Context) -> STPPaymentCardTextField {
        let cardTextField = STPPaymentCardTextField()
        cardTextField.delegate = context.coordinator
        return cardTextField
    }

    func updateUIView(_ uiView: STPPaymentCardTextField, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, STPPaymentCardTextFieldDelegate {
        var parent: CardTextFieldWrapper

        init(_ parent: CardTextFieldWrapper) {
            self.parent = parent
        }

        func paymentCardTextFieldDidChange(_ textField: STPPaymentCardTextField) {
            parent.cardDetails = textField.cardParams.toSTPCardParams()
        }
    }
}
