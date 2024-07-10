import UIKit
import SwiftUI
import StripeUICore

var adminID = UserDefaults.standard.string(forKey: "selectedAdminID")
let userId = UserDefaults.standard.string(forKey: "cid") ?? ""
let openingHours = parseOpeningHours(from: "08:00-20:00|10:00-20:00|08:00-20:00|10:00-20:00|08:00-20:00|0-0|08:00-20:00")
let daysOfWeek = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]


// Resize an image to fit within the specified max dimension while maintaining its aspect ratio
func resizeImage(_ image: UIImage, toMaxDimension maxDimension: CGFloat) -> UIImage? {
    let ratio = min(maxDimension / image.size.width, maxDimension / image.size.height)
    let newSize = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
    let renderer = UIGraphicsImageRenderer(size: newSize)
    return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
}

// Generate a unique name for an image using UUID and timestamp
func generateUniqueImageName() -> String {
    "\(UUID().uuidString)\(Int(Date().timeIntervalSince1970))"
}

// Save an image to the server and update the order with the image information
func saveImageToServer(image: UIImage, imageName: String, orderId: String, orderStatus: Int, completion: @escaping (Result<String, Error>) -> Void) {
    guard let imageData = image.jpegData(compressionQuality: 0.5) else { return }
    let imageString = imageData.base64EncodedString()
    
    guard let uploadURL = URL(string: "https://hoodapp.co.uk/utlities/saveimage.aspx") else { return }
    var request = URLRequest(url: uploadURL)
    request.httpMethod = "POST"
    request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    request.httpBody = "\(imageName).pngimage=\(imageString)".data(using: .utf8)
    
   
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            completion(.failure(error))
            return
        }
        if orderId.count > 0{
            let pickupImageValue = orderStatus < 4 ? "1" : "0"
            guard let updateOrderURL = URL(string: "https://minitel.co.uk/app/models/ordersGate?command=updateOrderPod&orderId=\(orderId)&pickupImage=\(pickupImageValue)&generatedName=\(imageName)") else { return }
           
            var updateRequest = URLRequest(url: updateOrderURL)
            updateRequest.httpMethod = "GET"
            print(updateOrderURL)
            URLSession.shared.dataTask(with: updateRequest) { _, _, updateError in
                if let updateError = updateError {
                    completion(.failure(updateError))
                    return
                }
                completion(.success("Image uploaded and order updated successfully"))
            }.resume()
        }
        }.resume()
    
}

// Update the order status on the server
func updateOrderStatus(orderId: String, status: Int) {
    let urlString = "https://minitel.co.uk/app/models/ordersGate?command=updateStatus&orderId=\(orderId)&status=\(status)"
    sendHTTPRequest(urlString: urlString)
}

// Send an HTTP GET request to the specified URL
func sendHTTPRequest(urlString: String) {
    guard let url = URL(string: urlString) else { return }
    
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    
    URLSession.shared.dataTask(with: request) { _, response, error in
        if let error = error {
            print("Error: \(error)")
        } else if let httpResponse = response as? HTTPURLResponse {
            print("Response status code: \(httpResponse.statusCode)")
        }
    }.resume()
}

// Load couriers from UserDefaults
func loadCouriersFromUserDefaults() -> [Courier]? {
    guard let savedCouriers = UserDefaults.standard.data(forKey: "couriers"),
          let loadedCouriers = try? JSONDecoder().decode([Courier].self, from: savedCouriers) else { return nil }
    return loadedCouriers
}

// Extract and format the time from a date-time string
func extractTime(from dateTime: String) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    if let date = formatter.date(from: dateTime) {
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    formatter.dateFormat = "yyyy-MM-dd HH:mm"
    if let date = formatter.date(from: dateTime) {
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    return dateTime
}
func extractHour(from timestamp: String) -> String {
    let inputFormatter = DateFormatter()
    inputFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    inputFormatter.timeZone = TimeZone(secondsFromGMT: 0)  // Adjust if needed based on your server's time zone

    guard let date = inputFormatter.date(from: timestamp) else {
        // Return a default or empty string if the date parsing fails
        return ""
    }

    let calendar = Calendar.current
    let outputFormatter = DateFormatter()

    if calendar.isDateInToday(date) {
        outputFormatter.dateFormat = "HH:mm"
        return outputFormatter.string(from: date)
    } else if calendar.isDateInYesterday(date) {
        return "Yesterday"
    } else if let daysAgo = calendar.dateComponents([.day], from: date, to: Date()).day, daysAgo <= 7 {
        outputFormatter.dateFormat = "EEEE"
        return outputFormatter.string(from: date)
    } else {
        outputFormatter.dateFormat = "dd/MM/yyyy"
        return outputFormatter.string(from: date)
    }
}

// Extract ETA time from a timestamp
func extractEtaTime(from timestamp: String) -> String {
    let formatter1 = DateFormatter()
    formatter1.dateFormat = "M/d/yyyy h:mm:ss a"
    formatter1.locale = Locale(identifier: "en_US_POSIX")
    formatter1.timeZone = TimeZone.current  // Set timezone to the current timezone

    let formatter2 = DateFormatter()
    formatter2.dateFormat = "yyyy-MM-dd HH:mm"
    formatter2.locale = Locale(identifier: "en_US_POSIX")
    formatter2.timeZone = TimeZone.current  // Set timezone to the current timezone

    let date = formatter1.date(from: timestamp) ?? formatter2.date(from: timestamp)

    guard let date = date else { return "" }

    let components = Calendar.current.dateComponents([.hour, .minute], from: Date(), to: date)
    if let hour = components.hour, let minute = components.minute {
        print("Hour: \(hour), Minute: \(minute)")
        let totalMinutes = hour * 60 + minute
        if totalMinutes > 0 && totalMinutes < 60 {
            return "ETA \(totalMinutes)-\(totalMinutes + 5) min"
        } else if totalMinutes < 0 && totalMinutes > -60 {
            return "ETA \(-totalMinutes) min ago"
        }
    } else {
        print("Failed to calculate hour and minute components")
    }

    let outputFormatter = DateFormatter()
    outputFormatter.dateFormat = "EEE dd/MM HH:mm"
    outputFormatter.locale = Locale(identifier: "en_US_POSIX")
    outputFormatter.timeZone = TimeZone.current  // Set timezone to the current timezone

    return outputFormatter.string(from: date)
}

// Format a date string into a more readable format
func formatTime(for dateString: String) -> String {
    let inputFormatter = DateFormatter()
    inputFormatter.dateFormat = "MM/dd/yyyy h:mm:ss a"
    inputFormatter.locale = Locale(identifier: "en_US_POSIX")
    
    guard let date = inputFormatter.date(from: dateString) else { return "" }
    
    let calendar = Calendar.current
    let now = Date()
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)
    
    let outputFormatter = DateFormatter()
    if calendar.isDateInToday(date) {
        outputFormatter.dateFormat = "HH:mm"
    } else if let tomorrow = tomorrow, calendar.isDate(date, inSameDayAs: tomorrow) {
        outputFormatter.dateFormat = "'Tomorrow' HH:mm"
    } else {
        outputFormatter.dateFormat = "EEE dd-MM HH:mm"
    }
    
    return outputFormatter.string(from: date)
}

// Get the current time as a string
var currentTime: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    return formatter.string(from: Date())
}

// Get the status text for a given status code
func getStatusText(for statusCode: String) -> String {
    switch statusCode {
    case "1": return "Received"
    case "2": return "Allocated"
    case "3": return "Picked up"
    case "4": return "En route"
    case "5": return "Delivered"
    default: return "Unknown status"
    }
}

// Parse a date string into a Date object
func parseDate(_ dateString: String) -> Date? {
    let formatter1 = DateFormatter()
    formatter1.dateFormat = "M/d/yyyy h:mm:ss a"
    
    let formatter2 = DateFormatter()
    formatter2.dateFormat = "yyyy-MM-dd HH:mm"

    if let date = formatter1.date(from: dateString) {
        return date
    }
    
    if let date = formatter2.date(from: dateString) {
        return date
    }
    
    print("Failed to parse date: \(dateString)")
    return nil
}

// Clear all cookies and UserDefaults
func clearCookies() {
    if let cookies = HTTPCookieStorage.shared.cookies {
        for cookie in cookies {
            HTTPCookieStorage.shared.deleteCookie(cookie)
        }
    }
    
    let defaults = UserDefaults.standard
    let dictionary = defaults.dictionaryRepresentation()
    dictionary.keys.forEach { key in
        defaults.removeObject(forKey: key)
    }
}

class ViewRouter: ObservableObject {
    @Published var isSheetPresented = false
    @Published var isFullScreenPresented = false
    @Published var isNamePresented = false
}

func decodeHTMLEntitiesAsync(_ htmlString: String, completion: @escaping (String?) -> Void) {
    DispatchQueue.global(qos: .background).async {
        guard let data = htmlString.data(using: .utf8) else {
            completion(nil)
            return
        }
        
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        
        if let attributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
            let decodedString = attributedString.string
            DispatchQueue.main.async {
                completion(decodedString)
            }
        } else {
            DispatchQueue.main.async {
                completion(nil)
            }
        }
    }
}

func convertDateString(_ inputDateString: String) -> String? {
    let inputFormatter = DateFormatter()
    inputFormatter.dateFormat = "M/dd/yyyy h:mm:ss a"
    inputFormatter.locale = Locale(identifier: "en_US_POSIX")

    if let date = inputFormatter.date(from: inputDateString) {
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "E dd/MM HH:mm"
        return outputFormatter.string(from: date)
    }
    return nil
}


func parseOpeningHours(from scheduleString: String) -> [OpeningHours] {
    scheduleString.split(separator: "|").map {
        let hours = $0.split(separator: "-").map(String.init)
        return OpeningHours(open: hours[0], close: hours[1])
    }
}

