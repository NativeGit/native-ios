import SwiftUI

struct MessageBubble: View {
    var senderName: String
    var messageText: String
    var messageTime: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                Text(senderName)
                    .font(.system(size: 14))
                Text(messageText)
                    .font(.system(size: 16, weight: .medium))
                    .padding(.top, 3)
                HStack {
                    Spacer()
                    Text(messageTime)
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .padding(.top, 3)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(10)
            .frame(maxWidth: messageWidth() + 20)
        }
    }

    private func messageWidth() -> CGFloat {
        let font = UIFont.systemFont(ofSize: 16)
        return messageText.width(usingFont: font) + 20
    }
}

struct RefundSheet: View {
    @Binding var refundAmount: String
    @Environment(\.presentationMode) var presentationMode
    var onRefund: (String) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Refund Amount").font(.headline)
            HStack {
                TextField("Enter amount", text: $refundAmount)
                    .keyboardType(.decimalPad)
                    .frame(height: 40)
                    .padding(.horizontal, 10)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))
                Text("£").font(.subheadline)
            }
            Button(action: {
                onRefund(refundAmount)
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("Refund")
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            Spacer()
        }
        .padding()
    }
}

struct RebookSheet: View {
    @Environment(\.presentationMode) var presentationMode
    var orderId: String
    var shopId: Int
    var vehicleOptions = ["Moped", "Car", "Van"]
    @State private var selectedVehicle = "Moped"
    @State private var showingSuccessAlert = false
    var onRebookConfirmed: () -> Void

    var body: some View {
        VStack {
            Text("Select Vehicle").font(.headline).padding(.bottom, 20)
            Picker("Select Vehicle", selection: $selectedVehicle) {
                ForEach(vehicleOptions, id: \.self) { Text($0) }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.bottom, 20)
            Button(action: {
                sendRebook()
            }) {
                Text("Rebook")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            Spacer()
        }
        .padding()
        .alert(isPresented: $showingSuccessAlert) {
            Alert(
                title: Text("Success"),
                message: Text("Order rebooked successfully for ASAP"),
                dismissButton: .default(Text("OK")) {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }

    // Send rebook request to the server
    func sendRebook() {
        let correctedShop = shopId == 0 ? 1 : shopId
        guard let url = URL(string: "https://hoodapp.co.uk/app/services/gophrGateway?shop=\(correctedShop)&orderid=\(orderId)&pickupTime=&v=\(selectedVehicle)") else { return }

        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error: \(error.localizedDescription)")
                    return
                }

                if let data = data, let responseString = String(data: data, encoding: .utf8), responseString.contains("|Ok|") {
                    showingSuccessAlert = true
                    onRebookConfirmed()
                } else {
                    print("Unexpected response")
                }
            }
        }.resume()
    }
}

struct CollectionSheet: View {
    @Binding var collectionMinutes: String
    @Binding var deliveryMinutes: String
    @Environment(\.presentationMode) var presentationMode
    @Binding var job: Order
    var mode: SheetMode

    var body: some View {
        VStack(spacing: 20) {
            Text(mode == .collection ? "Collection in" : "Delivery in").font(.headline)
            HStack {
                TextField("Enter minutes", text: mode == .collection ? $collectionMinutes : $deliveryMinutes)
                    .keyboardType(.numberPad)
                    .frame(height: 40)
                    .padding(.horizontal, 10)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))
                Text("min").font(.subheadline)
            }
            Button(action: {
                handleAction()
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("Allocate")
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            Spacer()
        }
        .padding()
    }

    // Handle the allocation action
    private func handleAction() {
        job.status = (mode == .collection) ? 3 : 4
        updateOrderStatusWithCourier(mode == .collection ? collectionMinutes : deliveryMinutes, endpoint: mode == .collection ? "updatePickup" : "updateDelivery")
        
        // Clear the text fields
        if mode == .collection {
            collectionMinutes = ""
        } else {
            deliveryMinutes = ""
        }
    }

    // Update order status with courier information
    private func updateOrderStatusWithCourier(_ minutes: String, endpoint: String) {
        guard let minutesToAdd = Int(minutes) else {
            print("Invalid minutes input")
            return
        }

        let futureDate = Calendar.current.date(byAdding: .minute, value: minutesToAdd + 1, to: Date())!
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        let formattedDate = dateFormatter.string(from: futureDate)
        let urlString = "https://minitel.co.uk/app/models/ordersGate?command=\(endpoint)&id=\(job.orderId)&\(endpoint == "updatePickup" ? "pickupTime" : "delivery")=\(formattedDate)"
        sendHTTPRequest(urlString: urlString)
    }

    // Send HTTP request to update order status
    private func sendHTTPRequest(urlString: String) {
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { _, response, error in
            if let error = error {
                print("Error: \(error)")
            } else if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                print("Unexpected response status code: \(httpResponse.statusCode)")
            }
        }.resume()
    }
}

struct CameraView: UIViewControllerRepresentable {
    @Binding var isShown: Bool
    @Binding var image: UIImage?
    var onImagePicked: (UIImage?) -> Void
    var sourceType: UIImagePickerController.SourceType

    func makeCoordinator() -> Coordinator {
        Coordinator(self, onImagePicked: onImagePicked)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraView
        var onImagePicked: (UIImage?) -> Void

        init(_ parent: CameraView, onImagePicked: @escaping (UIImage?) -> Void) {
            self.parent = parent
            self.onImagePicked = onImagePicked
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            parent.image = info[.originalImage] as? UIImage
            onImagePicked(parent.image)
            parent.isShown = false
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onImagePicked(nil)
            parent.isShown = false
        }
    }
}

