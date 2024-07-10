import SwiftUI
import CoreLocation
import GoogleMaps
import StripeApplePay
import GoogleSignIn

@main
struct Hood_ShopApp: App {
    var ordersViewModel = OrdersViewModel()
    let viewRouter = ViewRouter()
    @StateObject var appViewModel = AppViewModel()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var deepLinkHandler = DeepLinkHandler()
    
    init() {
        GMSServices.provideAPIKey("AIzaSyCoYB06N8R3kGTBP5y33x4zi1YsWzpc8Dw")
        UINavigationBar.configureAppearance()
        StripeAPI.defaultPublishableKey = "pk_live_51H5URzFZIwZSNufssK4R7BjLhpqxHVcfmEZVH8Tg74MAHMA20RfkYhIfbwFjDWJ55KzHWkOhEcqVWhIO2VShjOcU00Tslmi1XT"
        fetchAndStoreCouriersIfNeeded()
    }
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
               ShopView()
                //OrdersView(viewModel: ordersViewModel)
                  //  .preferredColorScheme(.dark)
            }
            .modifier(NavigationBarModifier(backgroundColor: UIColor.white))
            .environmentObject(viewRouter)
            .environmentObject(appViewModel)
            .onAppear {
                GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
                    if let error = error {
                        print("Google SignIn Error: \(error)")
                    }
                }
            }
            .accentColor(.primary)
            .onOpenURL { url in
                handleURL(url, viewModel: appViewModel)
            }
        }
    }

    func fetchAndStoreCouriersIfNeeded() {
        CourierManager.fetchCouriers { couriers in
            if let couriers = couriers {
                let encoder = JSONEncoder()
                if let encoded = try? encoder.encode(couriers) {
                    UserDefaults.standard.set(encoded, forKey: "couriers")
                }
            }
        }
    }
    
    func handleURL(_ url: URL, viewModel: AppViewModel) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let queryItems = components.queryItems else {
            return
        }

        if components.path.contains("chat"),
           let cid = queryItems.first(where: { $0.name == "cid" })?.value,
           let shop = queryItems.first(where: { $0.name == "shop" })?.value {
            viewModel.selectedCustomerId = cid
            viewModel.selectedShopId = shop
            viewModel.showChatView = true
        } else if components.path.contains("tracker"),
                  let trackerId = queryItems.first(where: { $0.name == "id" })?.value {
            viewModel.selectedTrackerId = trackerId
            viewModel.showTrackerView = true
        } else if components.path.contains("admin"),
                  let orderId = queryItems.first(where: { $0.name == "orderid" })?.value {
            viewModel.selectedOrderId = orderId
            viewModel.showOrderView = true
        }
    }
}

func sendLocationToServer(latitude: Double, longitude: Double, orderId: String) {
    var urlComponents = URLComponents(string: "https://hoodapp.co.uk/app/models/ordersGate")
    urlComponents?.queryItems = [
        URLQueryItem(name: "command", value: "updateLocation"),
        URLQueryItem(name: "id", value: orderId),
        URLQueryItem(name: "lat", value: "\(latitude)"),
        URLQueryItem(name: "lng", value: "\(longitude)")
    ]

    guard let url = urlComponents?.url else { return }

    var request = URLRequest(url: url)
    request.httpMethod = "GET"

    URLSession.shared.dataTask(with: request) { _, _, error in
        if let error = error {
            print("Error: \(error)")
        }
    }.resume()
}

class CourierManager {
    static func fetchCouriers(completion: @escaping ([Courier]?) -> Void) {
        guard let url = URL(string: "https://minitel.co.uk/app/models/shopgateway?command=getCouriers") else {
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else {
                print("Failed to fetch couriers: \(String(describing: error))")
                completion(nil)
                return
            }

            if let responseString = String(data: data, encoding: .utf8) {
                let results = responseString.split(separator: "$").map { String($0) }
                let couriers = results.compactMap { result -> Courier? in
                    let details = result.split(separator: "|").map { String($0) }
                    guard details.count == 5 else { return nil }
                    return Courier(id: details[4], name: details[0], email: details[1], phone: details[2], password: details[3])
                }
                completion(couriers)
            } else {
                completion(nil)
            }
        }.resume()
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    @Published var navigationState = NavigationState()

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        if let notification = launchOptions?[.remoteNotification] as? [String: AnyObject] {
            // Handle the notification data
        }
        let appearance = UINavigationBarAppearance()
                          appearance.configureWithOpaqueBackground() // Ensures the background is not transparent
                          appearance.backgroundColor = .white
                          appearance.titleTextAttributes = [.foregroundColor: UIColor.black]
                          appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.black]

                          UINavigationBar.appearance().standardAppearance = appearance
                          UINavigationBar.appearance().scrollEdgeAppearance = appearance
                          UINavigationBar.appearance().compactAppearance = appearance
                          UINavigationBar.appearance().tintColor = .black

        
        StripeAPI.defaultPublishableKey = "pk_live_51H5URzFZIwZSNufssK4R7BjLhpqxHVcfmEZVH8Tg74MAHMA20RfkYhIfbwFjDWJ55KzHWkOhEcqVWhIO2VShjOcU00Tslmi1XT"
        GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
            if let error = error {
                print("Google SignIn Error: \(error)")
            }
        }

        configureNavigationBarAppearance()
        GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")

        return true
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb, let url = userActivity.webpageURL {
            print("Deep link \(url)")
            navigationState.messageViewActive = true
        }
        return true
    }

    private func configureNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .white
        appearance.titleTextAttributes = [.foregroundColor: UIColor.black]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.black]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().tintColor = .black
    }
}

class NavigationState: ObservableObject {
    @Published var messageViewActive = false
}

class DeepLinkHandler: ObservableObject {
    @Published var navigationState = NavigationState()

    func handleDeepLink(_ url: URL) {
        print(url)
        if url.scheme == "myapp" && url.host == "message" {
            navigationState.messageViewActive = true
        }
    }
}

class AppViewModel: ObservableObject {
    @Published var showChatView = false
    @Published var selectedCustomerId = ""
    @Published var selectedShopId = ""
    @Published var showTrackerView = false
    @Published var showOrderView = false
    @Published var selectedTrackerId: String?
    @Published var selectedOrderId = ""
    @Published var isNameNeeded = false
    @Published var isLoginPresented = false
    @Published var isEmailSheetPresented = false
    @Published var isLoginSheetPresented = false
    @Published var isEmailLoginSheetPresented = false
    @Published var isProfileDetailViewPresented = false
    @Published var user: GIDGoogleUser?
    @Published var isSignedIn = false

    init() {
        GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, error in
            if let user = user {
                self?.user = user
                self?.isSignedIn = true
            }
        }
    }

    func checkUserName() {
        if let name = UserDefaults.standard.string(forKey: "UserName"), !name.isEmpty {
            isLoginSheetPresented = false
            isEmailLoginSheetPresented = false
        } else {
            isProfileDetailViewPresented = true
        }
    }
}

struct StatusBarStyleManager: UIViewControllerRepresentable {
    var backgroundColor: UIColor

    class Coordinator: NSObject {
        var parent: StatusBarStyleManager

        init(parent: StatusBarStyleManager) {
            self.parent = parent
            super.init()
            setupAppearance()
        }

        func setupAppearance() {
            guard let window = UIApplication.shared.windows.first else { return }
            let statusBarHeight = window.windowScene?.statusBarManager?.statusBarFrame.height ?? 0
            let statusBarView = UIView(frame: CGRect(x: 0, y: 0, width: window.frame.width, height: statusBarHeight))
            statusBarView.backgroundColor = parent.backgroundColor
            window.addSubview(statusBarView)
            statusBarView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                statusBarView.heightAnchor.constraint(equalToConstant: statusBarHeight),
                statusBarView.widthAnchor.constraint(equalTo: window.widthAnchor),
                statusBarView.topAnchor.constraint(equalTo: window.topAnchor)
            ])
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

extension View {
    func statusBarStyle(backgroundColor: UIColor) -> some View {
        self.background(StatusBarStyleManager(backgroundColor: backgroundColor))
    }
}

struct NavigationBarModifier: ViewModifier {
    var backgroundColor: UIColor?

    init(backgroundColor: UIColor?) {
        self.backgroundColor = backgroundColor
        configureNavigationBarAppearance()
    }

    func body(content: Content) -> some View {
        content.onAppear {
            configureNavigationBarAppearance()
        }
    }

    private func configureNavigationBarAppearance() {
        let coloredAppearance = UINavigationBarAppearance()
        coloredAppearance.configureWithOpaqueBackground()
        coloredAppearance.backgroundColor = backgroundColor
        coloredAppearance.shadowColor = .clear
        UINavigationBar.appearance().standardAppearance = coloredAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = coloredAppearance
    }
}

struct RootViewControllerAccessor: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    static func getRootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return nil
        }
        return rootViewController
    }
}

extension UINavigationController {
    open override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        navigationBar.topItem?.backButtonDisplayMode = .minimal
    }
}
