import SwiftUI
import Combine
import Kingfisher

struct ChatsView: View {
    @ObservedObject var viewModel = ChatViewModel()
    @State private var selectedChat: Chat?

    var body: some View {
        VStack {
            if viewModel.chats.isEmpty {
                Text("No chats available.")
                    .foregroundColor(.gray)
            } else {
                List(viewModel.chats) { chat in
                    HStack {
                        KFImage(URL(string: assets.icon))
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text(chat.customerName)
                                .font(.headline)
                                .lineLimit(1)

                            Text(chat.lastMessage)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .lineLimit(2)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(chat.formattedDate)
                                .font(.subheadline)
                                .foregroundColor(chat.unseenMessages > 0 ? .blue : .secondary)

                            if chat.unseenMessages > 0 {
                                Text("\(chat.unseenMessages)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .frame(width: 20, height: 20)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .clipShape(Circle())
                            } else {
                                Text("0")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .frame(width: 20, height: 20)
                                    .background(Color.clear)
                                    .foregroundColor(.clear)
                                    .clipShape(Circle())
                                    .hidden()
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedChat = chat
                    }
                }
                .listStyle(PlainListStyle())
                .navigationBarTitle("Chats", displayMode: .large)
            }
        }
        .background(
            NavigationLink(
                destination: selectedChat.map { chat in
                    MessageView(customerId: chat.customerId, messageName: chat.customerName, phoneNumber: chat.phone)
                },
                isActive: Binding(
                    get: { selectedChat != nil },
                    set: { if !$0 { selectedChat = nil } }
                )
            ) {
                EmptyView()
            }
            .hidden()
        )
        .onAppear {
            viewModel.startFetchingChats()
        }
        .onDisappear {
            viewModel.stopFetchingChats()
        }
    }
}
