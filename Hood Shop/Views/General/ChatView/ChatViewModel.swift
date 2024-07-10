import SwiftUI
import Combine

class ChatViewModel: ObservableObject {
    @Published var chats: [Chat] = []
    private var timer: AnyCancellable?
    private let userDefaultsKey = "savedChats"

    init() {
        loadChats()
    }

    func startFetchingChats() {
        fetchChats()
        timer = Timer.publish(every: 10.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.fetchChats()
            }
    }

    func stopFetchingChats() {
        timer?.cancel()
    }

    func fetchChats() {
        guard let url = URL(string: "https://minitel.co.uk/app/models/chatGateway?command=getChatsAdmin&cid=1&maxid=0") else {
            print("Invalid URL")
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error fetching chats: \(error)")
                return
            }

            guard let data = data else {
                print("No data received")
                return
            }

            if let responseString = String(data: data, encoding: .utf8) {
                print("Response String: \(responseString)")
                self.parseChats(from: responseString)
            } else {
                print("Failed to decode response data")
            }
        }.resume()
    }

    private func parseChats(from response: String) {
        let rows = response.split(separator: "$")
        var fetchedChats: [Chat] = []

        for row in rows {
            let columns = row.split(separator: "|")
            if columns.count >= 10 {
                var lastMessage = String(columns[3])
                if lastMessage.contains("photo") {
                    lastMessage = "Photo"
                }

                let chat = Chat(
                    id: String(columns[0]),
                    customerName: String(columns[1]),
                    lastMessage: lastMessage,
                    date: parseDate(from: String(columns[4])),
                    unseenMessages: Int(columns[5]) ?? 0,
                    icon: String(columns[2]),
                    customerId: String(columns[0]),
                    phone: String(columns[10])
                )
                fetchedChats.append(chat)
            } else {
                print("Invalid row format: \(row)")
            }
        }

        // Sort chats by date in descending order
        fetchedChats.sort { $0.date > $1.date }

        DispatchQueue.main.async {
            self.chats = fetchedChats
            self.saveChats(fetchedChats)
            print("Chats updated: \(fetchedChats.count) chats fetched.")
        }
    }


    private func parseDate(from dateString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yyyy h:mm:ss a"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        if let date = formatter.date(from: dateString) {
            return date
        } else {
            print("Failed to parse date: \(dateString)")
            return Date(timeIntervalSince1970: 0)
        }
    }

    private func saveChats(_ chats: [Chat]) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(chats) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    private func loadChats() {
        if let savedChats = UserDefaults.standard.data(forKey: userDefaultsKey) {
            let decoder = JSONDecoder()
            if let decodedChats = try? decoder.decode([Chat].self, from: savedChats) {
                self.chats = decodedChats
            }
        }
    }
}
