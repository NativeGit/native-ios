import SwiftUI

class LoginViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var isButtonDisabled = false
    @Published var emailValid = true
    @Published var hasSignedUp: Bool = false
    @Published var name: String = ""

    func login(viewRouter: ViewRouter, completion: @escaping (Result<Void, Error>) -> Void) {
        isButtonDisabled = false
        if isValidEmail(email) {
            signup(email: email, password: password) { result in
                switch result {
                case .success(let response):
                    print("Signup Success: \(response)")
                    viewRouter.isSheetPresented.toggle()
                    completion(.success(()))
                case .failure(let error):
                    print("Signup Error: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        } else {
            emailValid = false
            completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid email address"])))
        }
    }

    func isValidEmail(_ email: String) -> Bool {
        let emailFormat = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailFormat)
        return emailPredicate.evaluate(with: email)
    }

    func signup(email: String, password: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Validating and preparing email
        var validatedEmail = email
        if !validatedEmail.contains("@") {
            validatedEmail += "@apple.com"
            // Clearing the email after modification
            UserDefaults.standard.set("", forKey: "email")
        }

        // Build URL with query parameters
        var components = URLComponents(string: "https://minitel.co.uk/app/models/shopgateway")
        components?.queryItems = [
            URLQueryItem(name: "command", value: "checkMinitelLogin"),
            URLQueryItem(name: "email", value: validatedEmail),
            URLQueryItem(name: "password", value: password)
        ]

        guard let url = components?.url else {
            completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "URL creation failed"])))
            return
        }

        // HTTP request
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data, let responseString = String(data: data, encoding: .utf8) else {
                completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid data received"])))
                return
            }

            // Processing the server response
            let resultsArray = responseString.components(separatedBy: "|")
            if resultsArray.count > 3 {
                UserDefaults.standard.set(resultsArray[1], forKey: "cid") // Assuming 'id' is at position 1
                UserDefaults.standard.set(resultsArray[2], forKey: "name") // Assuming 'name' is at position 2
                UserDefaults.standard.set(resultsArray[3], forKey: "admin") // Assuming 'admin' is at position 3
                UserDefaults.standard.set(resultsArray[3], forKey: "selectedAdminID")
                UserDefaults.standard.set(resultsArray[4], forKey: "icon")
                let resultsText = resultsArray.joined(separator: "\n")
                completion(.success(resultsText))
            } else {
                completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid email or password. Please try again."])))
            }
        }.resume()
    }

    func parseAndFilterResultsString(_ resultsString: String) -> [Admin] {
        let rows = resultsString.components(separatedBy: "$").filter { !$0.isEmpty }
        var adminArray: [Admin] = []

        for row in rows {
            let elements = row.components(separatedBy: "|")
            if elements.count >= 4, elements[2] != "nil" {
                let admin = Admin(id: elements[1], name: elements[3]) // Adjusted indices based on your comment
                if !adminArray.contains(where: { $0.id == admin.id }) {
                    adminArray.append(admin)
                }
            }
        }

        return adminArray
    }
}
