import Foundation
import Combine
import SwiftUI

class MessageViewModel: ObservableObject {
    @Published var messages: [Message] = []
       @Published var maxId: Int = 0
       @Published var image: UIImage?
       @Published var fullScreenImage: IdentifiableImage?
       @Published var sourceType: UIImagePickerController.SourceType = .photoLibrary
       @Published var shouldAnimateScroll = false

       let messageName: String
       let phoneNumber: String
       let isShop: Bool
       let isAdmin: Bool
       let del: String
       let customerId: String

    init(customerId: String, messageName: String, phoneNumber: String, isShop: Bool, isAdmin: Bool) {
            self.customerId = customerId
           self.messageName = messageName
           self.phoneNumber = phoneNumber
           self.isShop = isShop
           self.isAdmin = isAdmin
           self.del = isShop ? "0" : (isAdmin ? "2" : "1")
           startTimer()
       }

    func startTimer() {
        Timer.publish(every: 10, on: .main, in: .common).autoconnect().sink { _ in
            self.loadMessages()
        }.store(in: &cancellables)
    }

    func handleImagePicked(_ selectedImage: UIImage?) {
        guard let selectedImage = selectedImage else { return }
        if let imageData = selectedImage.jpegData(compressionQuality: 0.8) {
            let base64String = imageData.base64EncodedString()
            let imageMessageText = "photo:\(base64String)"
            let newMessageId = String(maxId + 1)
            let newMessage = Message(id: newMessageId, text: imageMessageText, timestamp: Date(), isUser: true)
            messages.append(newMessage)
            maxId += 1
            shouldAnimateScroll = true
        }
        let name = generateUniqueImageName()
        saveImageToServer(image: selectedImage, imageName: name, orderId: "", orderStatus: 0) { result in }
        self.sendMessageToServer(message: "photo:https://hoodapp.co.uk/images/uploads/\(name).png", shopId: "1", del: del, customerId: userId, shopName: "Shop")
    }

    func sendMessage(text: String) {
        let newMessageId = String(maxId + 1)
        let newMessage = Message(id: newMessageId, text: text, timestamp: Date(), isUser: true)
        messages.append(newMessage)
        maxId += 1
        shouldAnimateScroll = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.shouldAnimateScroll = false
        }
        self.sendMessageToServer(message: text, shopId: shopId, del: self.del, customerId: userId, shopName: "Shop")
    }

    private func sendMessageToServer(message: String, shopId: String, del: String, customerId: String, shopName: String) {
        let chatId = "1"
        let height = ""
        let date = Date()

        var components = URLComponents(string: "https://minitel.co.uk/app/models/chatGateway")
        components?.queryItems = [
            URLQueryItem(name: "command", value: "insertMessage"),
            URLQueryItem(name: "cid", value: customerId),
            URLQueryItem(name: "message", value: message),
            URLQueryItem(name: "chatId", value: chatId),
            URLQueryItem(name: "del", value: "0"),
            URLQueryItem(name: "height", value: height),
            URLQueryItem(name: "date", value: "\(date)"),
            URLQueryItem(name: "shop", value: shopId),
            URLQueryItem(name: "shopName", value: shopName)
        ]

        guard let url = components?.url else {
            print("Invalid URL")
            return
        }

        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            if let error = error {
                print("Error sending message: \(error)")
            }
        }

        task.resume()
    }

    func loadMessages() {
        var newMaxId = maxId
        let url = URL(string: "https://hoodapp.co.uk/app/models/chatGateway?command=getChat&del=\(del)&cid=\(customerId)&shop=1&maxId=\(maxId)")!
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let data = data, let string = String(data: data, encoding: .utf8) {
                let messagesString = string.split(separator: "$")
                var newMessages = [Message]()
                for stringMessage in messagesString {
                    let messageProperties = stringMessage.split(separator: "|")
                    guard messageProperties.count >= 4, let id = Int(messageProperties[0]) else { continue }
                    newMaxId = max(newMaxId, id)
                    let originalText = String(messageProperties[1])
                    let isUser = messageProperties[2] == "1"
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "M/d/yyyy h:mm:ss a"
                    guard let date = dateFormatter.date(from: String(messageProperties[3])) else { continue }
                    let loadedMessage = Message(id: String(id), text: originalText, timestamp: date, isUser: !isUser)
                    newMessages.append(loadedMessage)
                }
                DispatchQueue.main.async {
                    self.messages.append(contentsOf: newMessages)
                    self.messages.sort(by: { $0.timestamp < $1.timestamp })
                    self.maxId = newMaxId
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self.shouldAnimateScroll = false
                    }
                }
            } else if let error = error {
                print("Error loading messages: \(error)")
            }
        }.resume()
    }

    func callPhoneNumber() {
        let formattedNumber = formatToUKPhoneNumber(phoneNumber.replacingOccurrences(of: "-", with: ""))
        if let url = URL(string: "tel://\(formattedNumber)"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }

    private func formatToUKPhoneNumber(_ number: String) -> String {
        let digitsOnly = number.filter("0123456789".contains)
        if digitsOnly.hasPrefix("0") {
            return "+44" + digitsOnly.dropFirst()
        } else if !digitsOnly.hasPrefix("+44") {
            return "+44" + digitsOnly
        }
        return digitsOnly
    }

    func timeString(from timestamp: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let calendar = Calendar.current
        if calendar.isDateInToday(timestamp) {
            return formatter.string(from: timestamp)
        } else if calendar.isDateInYesterday(timestamp) {
            return "YESTERDAY \(formatter.string(from: timestamp))"
        } else if calendar.isDateInWeek(timestamp) {
            formatter.dateFormat = "EEE HH:mm"
            return formatter.string(from: timestamp).uppercased()
        } else {
            formatter.dateFormat = "dd MMM 'AT' HH:mm"
            return formatter.string(from: timestamp).uppercased()
        }
    }

    func isTimeDifferenceMoreThanTenMinutes(between date1: Date, and date2: Date) -> Bool {
        return abs(date1.timeIntervalSince(date2)) > 600
    }

    func showFullScreenImage(image: UIImage) {
        self.fullScreenImage = IdentifiableImage(image: image)
    }

    private var cancellables = Set<AnyCancellable>()
}
