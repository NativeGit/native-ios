import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    @FocusState private var focusedField: Field?
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var viewRouter: ViewRouter
    @State private var showErrorToast: Bool = false
    @State private var toastMessage: String = ""

    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                // Dismiss Button
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.left")
                            .resizable()
                            .frame(width: 15, height: 15)
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                    }.padding(.leading).padding(.top, 50)
                    Spacer()
                }

                // Title
                Text("Sign In")
                    .fontWeight(.bold)
                    .font(.largeTitle)
                    .padding(.horizontal)

                // Email and Password Input Fields
                InputView(label: "Email", text: $viewModel.email, focused: $focusedField, equals: .email)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .padding([.leading, .trailing])

                InputView(label: "Password", text: $viewModel.password, focused: $focusedField, equals: .password)
                    .autocapitalization(.none)
                    .keyboardType(.default)
                    .padding([.leading, .trailing])

                // Log In Button
                Button(action: {
                    viewModel.login(viewRouter: viewRouter) { result in
                        switch result {
                        case .success:
                            break // Handle success if needed
                        case .failure(let error):
                            toastMessage = error.localizedDescription
                            showErrorToast = true
                        }
                    }
                }) {
                    Text("Log in")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }.disabled(viewModel.isButtonDisabled)
                .padding()

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .background(colorScheme == .dark ? Color.black : Color.white)
            .edgesIgnoringSafeArea(.all)
            .toast(isPresented: $showErrorToast, message: toastMessage)
        }
    }
}
