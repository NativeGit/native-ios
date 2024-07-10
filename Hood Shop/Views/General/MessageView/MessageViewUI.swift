import SwiftUI
import Kingfisher

struct MessageViewRow: View {
    var message: Message
    var onImageTap: (UIImage) -> Void
    @Environment(\.colorScheme) var colorScheme
    
    
    @State private var uiImage: UIImage? = nil
    @State private var didLoadImage: Bool = false
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
                content
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.8, alignment: .trailing)
            } else {
                content
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.8, alignment: .leading)
                Spacer()
            }
        }
        .padding(.vertical, 2)
        .onAppear {
            if !didLoadImage {
                loadImage()
            }
        }
    }
    
    @ViewBuilder
    var content: some View {
        if message.text.starts(with: "photo:") || message.text.starts(with: "image:") {
            if let uiImage = uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 200, height: 200)
                    .cornerRadius(10)
                    .onTapGesture {
                        onImageTap(uiImage)
                    }
            } else if message.text.starts(with: "photo:") {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 200, height: 200)
                    .cornerRadius(10)
            }
        } else {
            Text(message.text)
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .font(.system(size: 15))
                .background(backgroundForMessage())
                .cornerRadius(10)
                .foregroundColor(foregroundForMessage())
        }
    }
    
    private func loadImage() {
        didLoadImage = true
        
        let imageString = message.text.starts(with: "photo:") ? String(message.text.dropFirst(6)) : String(message.text.dropFirst(6))
        
        // Check if the image string is a valid URL
        if let url = URL(string: imageString), imageString.isValidImageURL {
            DispatchQueue.global().async {
                if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self.uiImage = image
                    }
                }
            }
        } else if let imageData = Data(base64Encoded: imageString),
                  let image = UIImage(data: imageData) {
            DispatchQueue.main.async {
                self.uiImage = image
            }
        }
    }
    
    private func backgroundForMessage() -> Color {
        
        return message.isUser ? Color.blue : (colorScheme == .dark ? Color.messageDark : Color(UIColor(hex: "#F3F4F6")))
    }
    
    private func foregroundForMessage() -> Color {
        return message.isUser ? Color.white : (colorScheme == .dark ? Color.white : Color.black)
    }
}

struct FullScreenImageView: View {
    var image: UIImage
    var onClose: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset = CGSize.zero
    @State private var lastOffset = CGSize.zero

    var body: some View {
        ZStack {
            Color.black.opacity(0.7).edgesIgnoringSafeArea(.all)
            
            GeometryReader { geometry in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
                    .scaleEffect(scale)
                    .offset(x: offset.width, y: offset.height)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let delta = value / self.lastScale
                                self.lastScale = value
                                self.scale *= delta
                            }
                            .onEnded { _ in
                                self.lastScale = 1.0
                            }
                            .simultaneously(
                                with: DragGesture()
                                    .onChanged { value in
                                        self.offset = CGSize(width: self.lastOffset.width + value.translation.width, height: self.lastOffset.height + value.translation.height)
                                    }
                                    .onEnded { _ in
                                        self.lastOffset = self.offset
                                    }
                            )
                    )
            }
        }
        .onTapGesture { onClose() }
    }
}

