import SwiftUI
import GoogleSignIn
import Combine

class LoginManager: ObservableObject {
    @Published var isLoggedIn = false
    @Published var profileImageURL: URL?
    @Published var isHistoryViewActive = false

    var shopModel: ShopModel
    private var cancellables = Set<AnyCancellable>()

    init(shopModel: ShopModel) {
        self.shopModel = shopModel
        setupBindings()
        checkCookies()
    }

    private func setupBindings() {
        $isLoggedIn
            .receive(on: RunLoop.main)
            .assign(to: \.isLoggedIn, on: shopModel)
            .store(in: &cancellables)

        $profileImageURL
            .receive(on: RunLoop.main)
            .assign(to: \.profileImageURL, on: shopModel)
            .store(in: &cancellables)
    }

    func sendLoginRequest(email: String, orderId: String) {
        guard let url = URL(string: "https://minitel.co.uk/app/models/shopgateway?command=loginMinitel&email=\(email)&orderid=\(orderId)") else {
            print("Invalid URL")
            return
        }

        let task = URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                print("HTTP request error: \(error.localizedDescription)")
                return
            }

            guard let data = data, let responseString = String(data: data, encoding: .utf8) else {
                print("No data or unable to decode response")
                return
            }

            let components = responseString.split(separator: "|")
            if components.count > 1 {
                let cid = String(components[1])
                UserDefaults.standard.set(cid, forKey: "cid")
                print("cid set to UserDefaults: \(cid)")
            } else {
                print("Unexpected response format: \(responseString)")
            }
        }

        task.resume()
    }

    func handleSignInButton() {
        guard let rootViewController = UIApplication.shared.windows.first?.rootViewController else {
            print("Root view controller is not defined")
            return
        }

        if GIDSignIn.sharedInstance.hasPreviousSignIn() {
            GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
                if let error = error {
                    print("Silent sign-in error: \(error.localizedDescription)")
                    self.performRegularSignIn(with: rootViewController)
                } else if let user = user {
                    self.profileImageURL = user.profile?.imageURL(withDimension: 100)
                    self.saveCookies(name: user.profile?.name, email: user.profile?.email, profileImageURL: self.profileImageURL)
                    self.isLoggedIn = true
                    if let email = user.profile?.email, let orderId = UserDefaults.standard.string(forKey: "orderId") {
                        self.sendLoginRequest(email: email, orderId: orderId)
                    }
                }
            }
        } else {
            self.performRegularSignIn(with: rootViewController)
        }
    }

    func saveCookies(name: String?, email: String?, profileImageURL: URL?) {
        if let name = name {
            setCookie(name: "userName", value: name)
        }
        if let email = email {
            setCookie(name: "userEmail", value: email)
        }
        if let profileImageURL = profileImageURL {
            setCookie(name: "profileImageURL", value: profileImageURL.absoluteString)
        }
    }

    func setCookie(name: String, value: String) {
        if let cookie = HTTPCookie(properties: [
            .domain: "your.domain.com",
            .path: "/",
            .name: name,
            .value: value,
            .secure: true,
            .expires: Date(timeIntervalSinceNow: 31556926)
        ]) {
            HTTPCookieStorage.shared.setCookie(cookie)
        }
    }

    func performRegularSignIn(with rootViewController: UIViewController) {
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { signInResult, error in
            guard let result = signInResult else {
                if let error = error {
                    print("Sign-in error: \(error.localizedDescription)")
                }
                return
            }

            let user = result.user
            self.profileImageURL = user.profile?.imageURL(withDimension: 100)
            self.saveCookies(name: user.profile?.name, email: user.profile?.email, profileImageURL: self.profileImageURL)
            self.isLoggedIn = true

            if let email = user.profile?.email, let orderId = UserDefaults.standard.string(forKey: "orderId") {
                self.sendLoginRequest(email: email, orderId: orderId)
            }

            print("Sign-in successful, user: \(user.profile?.name ?? "Unknown")")
        }
    }

    func checkCookies() {
        if let emailCookie = HTTPCookieStorage.shared.cookies?.first(where: { $0.name == "userEmail" }),
           let profileImageCookie = HTTPCookieStorage.shared.cookies?.first(where: { $0.name == "profileImageURL" }),
           let url = URL(string: profileImageCookie.value) {
            self.isLoggedIn = true
            self.profileImageURL = url
        }
    }
}
