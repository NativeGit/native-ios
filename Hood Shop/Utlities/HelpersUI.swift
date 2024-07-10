import SwiftUI
import Kingfisher
import StripePaymentsUI
import SwiftUI

struct InputView: View {
    var label: String
    @Binding var text: String
    var focused: FocusState<Field?>.Binding
    var equals: Field
    var showError: Binding<Bool>? // Make showError optional

    var body: some View {
        inputField(label: label, text: $text, focused: focused, equals: equals)
            .frame(minWidth: 0, idealWidth: .infinity, maxWidth: .infinity)
            .padding(.top, 10)
    }

    func inputField(label: String, text: Binding<String>, focused: FocusState<Field?>.Binding, equals field: Field) -> some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 10)
                .foregroundColor(focused.wrappedValue == field ? Color.gray.opacity(0.15) : Color.gray.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(showError?.wrappedValue ?? false ? Color.red : Color.clear, lineWidth: 2)
                )
                .frame(minHeight: 50, maxHeight: 50) // Adjust height if necessary

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if !text.wrappedValue.isEmpty {
                        Text(label)
                            .foregroundColor(Color(.gray))
                            .font(.caption) // Smaller font for floating label
                            .padding(.top, 3) // Adjust padding to stay within boundaries
                    }

                    if label.lowercased() == "password" {
                        SecureField(label, text: text)
                            .focused(focused, equals: field)
                            .foregroundColor(.primary)
                            .padding(.vertical, 8) // Padding to make the text vertically centered
                            .padding(.top, text.wrappedValue.isEmpty ? 0 : -10)
                            .font(.system(size: 15))
                    } else {
                        TextField(label, text: text)
                            .focused(focused, equals: field)
                            .disableAutocorrection(label.lowercased() == "email")
                            .autocapitalization(label.lowercased() == "email" ? .none : .allCharacters)
                            .foregroundColor(.primary)
                            .padding(.vertical, 8) // Padding to make the text vertically centered
                            .padding(.top, text.wrappedValue.isEmpty ? 0 : -10)
                            .font(.system(size: 15))
                    }
                }
                .padding(.horizontal, 15)

                Spacer()

                if !text.wrappedValue.isEmpty && focused.wrappedValue == field {
                    ClearButton { text.wrappedValue = "" }
                        .padding(.trailing, 10)
                }
            }
        }
        .frame(minHeight: 60, maxHeight: 60) // Adjust height if necessary
        .contentShape(Rectangle()) // Ensure the entire area is tappable
        .onTapGesture {
            // Force focus when the ZStack is tapped
            if focused.wrappedValue != field {
                focused.wrappedValue = field
            }
        }
    }
}

struct ClearButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.gray)
                .frame(width: 20, height: 20)
        }
    }
}





func calculateDynamicHeight(for product: Product, in shopModel: ShopModel) -> CGFloat {
    let optionsCount = product.options.filter { $0.type == .option }.count
    let additionsCount = product.options.filter { $0.type == .addition }.count
    let optionsHeight = optionsCount > 0 ? CGFloat(optionsCount) * 30 + 60 : 0
    let additionsHeight = additionsCount > 0 ? CGFloat(additionsCount) * 30 + 60 : 0
    let descriptionFont = UIFont.systemFont(ofSize: 14, weight: .regular)
    let descriptionPadding: CGFloat = 20
    let descriptionHeight = product.description.boundingRect(
        with: CGSize(width: UIScreen.main.bounds.width - 30, height: .greatestFiniteMagnitude),
        options: .usesLineFragmentOrigin,
        attributes: [.font: descriptionFont],
        context: nil
    ).height + descriptionPadding

    return optionsHeight + additionsHeight + descriptionHeight + 480
}


struct OrderStatusView: View {
    var orderStatus: String
    var orderDate: String
    var productImages: [String]
    var orderAgainAction: () -> Void
    var detailsAction: () -> Void
    @Binding var selectedOrder: Order?
    @Binding var showOrderView: Bool
    let pastOrder: Order

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                VStack(alignment: .leading) {
                    Text(orderStatus)
                        .font(.headline)
                    Text(orderDate)
                        .font(.system(size: 14, weight: .regular))
                        .padding(.top, 0.5)
                        .foregroundColor(.gray)
                }
                Spacer()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(productImages, id: \.self) { imageUrl in
                            KFImage(URL(string: imageUrl))
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .frame(height: 40)
                .padding(.leading, 20)
            }
            .padding(.horizontal)
            HStack {
                Spacer()
                Button(action: { detailsAction() }) {
                    Text("Details")
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.black)
                        .cornerRadius(8)
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(BorderlessButtonStyle()) // Ensure the button style doesn't affect the whole row
                Button(action: { orderAgainAction() }) {
                    Text("Order Again")
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(assets.brandColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(BorderlessButtonStyle()) // Ensure the button style doesn't affect the whole row
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .padding(.vertical)
    }
}


struct NavigationStackManager: UIViewControllerRepresentable {
    var action: (UINavigationController) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        DispatchQueue.main.async {
            if let navController = viewController.navigationController {
                self.action(navController)
            }
        }
        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // No need to update anything here
    }
}

struct DynamicHeightTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var height: CGFloat

    func makeCoordinator() -> Coordinator {
        return Coordinator(text: $text, height: $height)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isScrollEnabled = false
        textView.delegate = context.coordinator
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 0, bottom: 8, right: 5) // Adjusted to push text down by 10px
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.text = text
        uiView.backgroundColor = .clear
        DispatchQueue.main.async {
            self.height = uiView.contentSize.height
        }
    }

    class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        @Binding var height: CGFloat

        init(text: Binding<String>, height: Binding<CGFloat>) {
            _text = text
            _height = height
        }

        func textViewDidChange(_ textView: UITextView) {
            text = textView.text
            height = textView.contentSize.height
        }
    }
}

// Helper view to simulate TextEditor's background
struct TextEditorBackground: View {
    var body: some View {
        Color.clear
            .frame(maxHeight: .infinity)
    }
}


struct LogoTitleView: View {
    var body: some View {
        HStack {
            Text(assets.brandTitle)
                .font(.custom(assets.brandFont, size: assets.brandFontSize))
                .bold()
                .padding(.top, assets.logoPaddinTop)
                .foregroundColor(.black)
        }
    }
}
