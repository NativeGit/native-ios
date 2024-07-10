import SwiftUI

struct LoginSheetView: View {
    @Binding var showingLoginSheet: Bool
    var handleSignInButton: () -> Void
    
    var body: some View {
        VStack {
            Text("Checkout with your account")
                .font(.system(size: 20, weight: .bold))
                .padding()
            
            Text("Log in now to earn loyalty points, save your addresses and payment methods, or you can proceed as a guest.")
                .font(.system(size: 14))
            
            Spacer()
            
            Button(action: {
                showingLoginSheet = false
                handleSignInButton()
            }) {
                Text("Login")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding()
                    .frame(height: 50)
                    .background(assets.brandColor)
                    .cornerRadius(10)
                    .padding(.horizontal, 10)
            }
        }
        .padding(.horizontal)
        .padding(.top, 10)
    }
}
