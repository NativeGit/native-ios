import SwiftUI
import Kingfisher
import Combine

struct MessageView: View {
    @StateObject private var viewModel: MessageViewModel
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme

    @State private var messageText = ""
    @State private var customerId: String
    @State private var textEditorHeight: CGFloat = 40
    @State private var showingImagePicker = false
    
    @State private var isAdmin: Bool = false
    @State private var isShop: Bool = false

    init(customerId: String, messageName: String, phoneNumber: String) {
        let status = MessageView.updateAdminShopStatus()
        _customerId = State(initialValue: customerId)
        _isAdmin = State(initialValue: status.isAdmin)
        _isShop = State(initialValue: status.isShop)
        _viewModel = StateObject(wrappedValue: MessageViewModel(customerId:customerId, messageName: messageName, phoneNumber: phoneNumber, isShop: status.isShop, isAdmin: status.isAdmin))
    }

    var body: some View {
        VStack {
            ScrollView {
                ScrollViewReader { scrollViewProxy in
                    LazyVStack(alignment: .leading, spacing: 5) {
                        ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                            if index == 0 || viewModel.isTimeDifferenceMoreThanTenMinutes(between: viewModel.messages[index - 1].timestamp, and: message.timestamp) {
                                Text(viewModel.timeString(from: message.timestamp))
                                    .padding(.bottom, 5)
                                    .frame(maxWidth: .infinity)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.gray)
                                    .font(.footnote)
                            }
                            MessageViewRow(message: message, onImageTap: { uiImage in
                                viewModel.showFullScreenImage(image: uiImage)
                            })
                            .padding(.horizontal, 10)
                            .padding(.vertical, 2)
                            .id(message.id)
                        }
                        Color.clear.frame(height: 15).id("BottomPadding")
                    }
                    .onAppear {
                        viewModel.loadMessages()
                        scrollToBottom(scrollViewProxy: scrollViewProxy, animated: false)
                    }
                    .onChange(of: viewModel.messages) { _ in
                        DispatchQueue.main.async {
                            scrollToBottom(scrollViewProxy: scrollViewProxy, animated: viewModel.shouldAnimateScroll)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            scrollToBottom(scrollViewProxy: scrollViewProxy, animated: viewModel.shouldAnimateScroll)
                        }
                    }
                }
            }
            .padding(.horizontal, 0)

            HStack {
                ZStack(alignment: .topLeading) {
                    if messageText.isEmpty {
                        Text("Message...")
                            .foregroundColor(.gray)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                    }
                    DynamicHeightTextEditor(text: $messageText, height: $textEditorHeight)
                        .padding(.horizontal)
                        .frame(height: max(textEditorHeight, 45))
                }
                
                HStack(spacing: 18) {
                    if messageText.isEmpty {
                        Button(action: {
                            viewModel.sourceType = .camera
                            showingImagePicker = true
                        }) {
                            Image(systemName: "camera")
                                .resizable()
                                .frame(width: 21, height: 19)
                                .foregroundColor(.primary)
                        }
                        .padding(.bottom, 0)
                    }

                    Button(action: {
                        if !messageText.isEmpty {
                            viewModel.sendMessage(text: messageText)
                            messageText = ""
                            textEditorHeight = 45
                        } else {
                            viewModel.sourceType = .photoLibrary
                            showingImagePicker = true
                        }
                    }) {
                        Image(systemName: messageText.isEmpty ? "photo" : "paperplane.circle.fill")
                            .resizable()
                            .frame(width: messageText.isEmpty ? 20 : 30, height: messageText.isEmpty ? 18 : 30)
                            .padding(.bottom, 0)
                            .foregroundColor(messageText.isEmpty ? .primary : .blue)
                    }
                }
                .padding(.trailing, 18)
            }
            .background(colorScheme == .dark ? Color.textEditDark : Color.secondary.opacity(0.1))
            .cornerRadius(20)
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .navigationBarItems(
            leading: profileButton,
            trailing: phoneButton
        )
        .sheet(isPresented: $showingImagePicker) {
            CameraView(isShown: $showingImagePicker, image: $viewModel.image, onImagePicked: viewModel.handleImagePicked, sourceType: viewModel.sourceType)
        }
        .fullScreenCover(item: $viewModel.fullScreenImage) { identifiableImage in
            FullScreenImageView(image: identifiableImage.image) {
                viewModel.fullScreenImage = nil
            }
        }
    }

    private func scrollToBottom(scrollViewProxy: ScrollViewProxy, animated: Bool) {
        if animated {
            withAnimation {
                scrollViewProxy.scrollTo("BottomPadding", anchor: .bottom)
            }
        } else {
            scrollViewProxy.scrollTo("BottomPadding", anchor: .bottom)
        }
    }

    static func updateAdminShopStatus() -> (isAdmin: Bool, isShop: Bool) {
        if let adminId = UserDefaults.standard.string(forKey: "selectedAdminID"), !adminId.isEmpty {
            if adminId.count > 0 {
                return (false, true) // isAdmin = false, isShop = true
            } else {
                return (true, false) // isAdmin = true, isShop = false
            }
        } else {
            return (false, false) // isAdmin = false, isShop = false
        }
    }

    private var profileButton: some View {
        Button(action: { /* Dismiss action */ }) {
            HStack {
                KFImage(URL(string: assets.icon))
                    .resizable()
                    .frame(width: 39, height: 39)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                Text(viewModel.messageName)
                    .foregroundColor(.primary)
            }
        }
        .padding(.leading, -8)
        .padding(.top, -4.5)
    }

    private var phoneButton: some View {
        Group {
            if viewModel.phoneNumber.count > 5 {
                Button(action: viewModel.callPhoneNumber) {
                    Image(systemName: "phone")
                        .imageScale(.large)
                        .foregroundColor(.primary)
                }
            } else {
                EmptyView()
            }
        }
    }
}
