import SwiftUI
import StripePaymentsUI

// Extension for View to apply dynamic detents based on the specified type
extension View {
    @ViewBuilder
    func applyDynamicDetents(_ type: DetentType) -> some View {
        if #available(iOS 16.0, *) {
            switch type {
            case .mediumLargeFull:
                self.presentationDetents([.medium, .large])
            case .mediumLarge:
                self.presentationDetents([.medium])
            case .customHeight(let height):
                self.presentationDetents([.height(height)])
            }
        } else {
            self
        }
    }
}

// Extension for String to calculate its width using a specified font
extension String {
    func width(usingFont font: UIFont) -> CGFloat {
        let attributes = [NSAttributedString.Key.font: font]
        return self.size(withAttributes: attributes).width
    }
}

// Extension for UINavigationBar to configure its appearance
extension UINavigationBar {
    static func configureAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.shadowColor = .clear // Remove the bottom border line
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
}

extension View {
    func toast(isPresented: Binding<Bool>, message: String) -> some View {
        ZStack {
            self
            if isPresented.wrappedValue {
                VStack {
                    Spacer()
                    Text(message)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.bottom, 50)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation {
                                    isPresented.wrappedValue = false
                                }
                            }
                        }
                }
                .transition(.move(edge: .bottom))
                .animation(.spring())
            }
        }
    }
}

extension UIColor {
    convenience init(hex: String) {
        let hexString = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt64()
        Scanner(string: hexString).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hexString.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
}

extension Color {
    init(hex: String) {
        let uiColor = UIColor(hex: hex)
        self.init(uiColor)
    }
    
    init(_ uiColor: UIColor) {
        self.init(uiColor.cgColor)
    }
}


extension String {
    var isValidImageURL: Bool {
        let lowercased = self.lowercased()
        return URL(string: self) != nil && (lowercased.hasSuffix(".jpg") || lowercased.hasSuffix(".png") || lowercased.hasSuffix(".jpeg"))
    }
}

extension Color {
    //static let brandColor = Color(hex: "#FE2C55")
    static let brandColor =  Color.blue
    static let textEditDark = Color(hex: "#1D1E20")
    static let messageDark = Color(hex: "#25282D")
    static let customBlue = Color(red: 78 / 255, green: 159 / 255, blue: 247 / 255)
    static let strongRed = Color(red: 0.8, green: 0.2, blue: 0.2)
    static let strongBlue = Color(red: 0.2, green: 0.2, blue: 0.8)
    static let strongGreen = Color(red: 0.2, green: 0.8, blue: 0.2)
}

extension Array where Element: Equatable {
    static func == (lhs: [Element], rhs: [Element]) -> Bool {
        return lhs.elementsEqual(rhs)
    }
}

extension Binding {
    func defaultValue<T>(_ defaultValue: T) -> Binding<T> where Value == T? {
        Binding<T>(
            get: { self.wrappedValue ?? defaultValue },
            set: { self.wrappedValue = $0 }
        )
    }
}


extension STPPaymentMethodCardParams {
    func toSTPCardParams() -> STPCardParams {
        let cardParams = STPCardParams()
        cardParams.number = self.number
        cardParams.expMonth = self.expMonth?.uintValue ?? 0
        cardParams.expYear = self.expYear?.uintValue ?? 0
        cardParams.cvc = self.cvc
        return cardParams
    }
}

extension Calendar {
    func isDateInWeek(_ date: Date) -> Bool {
        return isDate(date, equalTo: Date(), toGranularity: .weekOfYear)
    }
}

extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, content: (Self) -> Content) -> some View {
        if condition {
            content(self)
        } else {
            self
        }
    }
}
