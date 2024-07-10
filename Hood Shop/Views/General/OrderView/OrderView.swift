import SwiftUI
import WebKit
import Kingfisher

struct OrderView: View {
  //  echo "This is a test file." > testfile.txt

    @StateObject private var viewModel = OrderViewModel()
    @State private var showActionSheet = false
    @State private var showCamera = false
    @State private var showCollectionSheet = false
    @State private var showRefundView = false
    @State private var showRebookView = false
    @State private var order: Order
    @State private var collectionMinutes = ""
    @State private var refundAmount = ""
    @State private var refundInfo: String?
    @State private var selectedCourier = "Courier Name"
    @State private var pickupImage: UIImage?
    @State private var deliveryImage: UIImage?
    @State private var image: UIImage?
    @State private var deliveryTime: String?
    @State private var collectionTime: String?
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    let id = "1357884"
    private var adminID = UserDefaults.standard.string(forKey: "selectedAdminID")
    @State private var actionSheetType: ActionSheetType = .options

    enum ActionSheetType {
        case options, photoOptions
    }

    init(order: Order) {
        self._order = State(initialValue: order)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    OrderDetailsView(order: order, adminID: adminID, selectedCourier: $selectedCourier, couriers: $viewModel.couriers, allocateCourier: viewModel.allocateCourier, refundInfo: refundInfo, viewModel: viewModel, showCollectionSheet: $showCollectionSheet)
                    SectionHeaderView(title: "Items")
                    ItemsView(orderDetails: viewModel.orderDetails, totalPrice: viewModel.totalPrice)
                    SectionHeaderView(title: "Activities")
                    OrderProgressView(order: order, viewModel: viewModel, collectionMinutes: $collectionMinutes, deliveryMinutes: $viewModel.deliveryMinutes, pickupImage: $pickupImage, deliveryImage: $deliveryImage)
                }
                .padding()
                .padding(.bottom, 90)
                .onAppear(perform: loadData)
                .toolbar {
                    ToolbarItem(placement: .principal) { Text("#\(order.orderId) \(order.customerName)") }
                }
                .onDisappear {
                           print("View disappeared")
                           viewModel.invalidateTimer()
                       }
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(trailing: adminID != "P" && adminID != "c" && !order.phone.isEmpty ? Button(action: { actionSheetType = .options; showActionSheet = true }) { Image(systemName: "ellipsis").imageScale(.large) } : nil)
            }
            if (order.status < 5){
                orderActionButton
            }
        }
        .actionSheet(isPresented: $showActionSheet) {
            switch actionSheetType {
            case .options: return ActionSheet(title: Text("Options"), buttons: actionSheetButtons)
            case .photoOptions: return ActionSheet(title: Text("Photo Options"), buttons: actionSheetButtonsPhoto)
            }
        }
        .sheet(isPresented: $showRebookView) {
            RebookSheet(orderId: order.orderId, shopId: 1) { viewModel.rebookOrder() }
        }
        .sheet(isPresented: $showCollectionSheet) {
            CollectionSheet(collectionMinutes: $collectionMinutes, deliveryMinutes: $viewModel.deliveryMinutes, job: $order, mode: order.status < 3 ? .collection : .delivery)
                .onDisappear(perform: viewModel.handleSheetDismissal)
        }
        .sheet(isPresented: $showCamera) {
            CameraView(isShown: $showCamera, image: $image, onImagePicked: handleImagePicked, sourceType: sourceType)
        }
    }

    private func loadData() {
        viewModel.selectedOrderId = order.orderId
        viewModel.order = order
        UserDefaults.standard.set(order.orderId, forKey: "currentOrderId")
        viewModel.loadOrder(orderId: order.orderId, id: id)
        viewModel.couriers = loadCouriersFromUserDefaults() ?? []
        selectedCourier = viewModel.couriers.first?.id ?? ""
        viewModel.lifecycleEvents = viewModel.parseLifecycle(order.lifecycle)
    }

    private var orderActionButton: some View {
        Button(action: handleButtonAction) {
            Text(viewModel.buttonText(for: order.status))
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
                .foregroundColor(.white)
                .font(.headline)
        }
        .padding(.horizontal)
        .padding(.bottom, 10)
    }

    private func handleButtonAction() {
            if order.status < 5 {
                switch order.status {
                case 1:
                    showCollectionSheet = true
                case 2:
                    showCollectionSheet = true
                case 3:
                    actionSheetType = .photoOptions
                    showActionSheet = true
                default:
                    actionSheetType = .photoOptions
                    showActionSheet = true
                }
            }
        }

    private var actionSheetButtons: [ActionSheet.Button] {
        [.default(Text("Refund")) { showRefundView = true },
         .default(Text("Rebook")) { showRebookView = true },
         .default(Text("Cancel order")),
         .cancel()]
    }

    private var actionSheetButtonsPhoto: [ActionSheet.Button] {
        var buttons: [ActionSheet.Button] = [.cancel()]
        if order.status < 5 {
            buttons.insert(.default(Text("Camera")) {
                sourceType = .camera
                showCamera = true
            }, at: 0)
            buttons.insert(.default(Text("Photo Library")) {
                sourceType = .photoLibrary
                showCamera = true
            }, at: 1)
        }
        return buttons
    }

    private func handleImagePicked(_ selectedImage: UIImage?) {
        guard let selectedImage = selectedImage else { return }
        viewModel.processAndUploadImage(selectedImage)
        if order.status == 4 {
            updateOrderStatus(orderId: order.orderId, status: 5)
            deliveryTime = "Delivered at \(currentTime)"
            order.status = 5
            deliveryImage = selectedImage
        } else if order.status < 4 {
            collectionTime = "Collected at \(currentTime)"
            order.status = 4
            updateOrderStatus(orderId: order.orderId, status: 4)
            pickupImage = selectedImage
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showCollectionSheet = true }
        }
    }

    private var currentTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }
}

struct SectionHeaderView: View {
    var title: String

    var body: some View {
        VStack(spacing: 0) {
            Divider().background(Color.gray.opacity(0.2)).padding(.top, 0)
            Text(title).font(.headline).padding(.vertical, 15).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

import SwiftUI

struct OrderDetailsView: View {
    var order: Order
    var adminID: String?
    @Binding var selectedCourier: String
    @Binding var couriers: [Courier]
    var allocateCourier: () -> Void
    var refundInfo: String?
    @ObservedObject var viewModel: OrderViewModel
    @Binding var showCollectionSheet: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if adminID == "ca" || adminID == "a" {
                HStack {
                    Picker("Select Courier", selection: $selectedCourier) {
                                  ForEach(couriers, id: \.id) { courier in
                                      Text(courier.name).tag(courier.id)
                                  }
                              }
                              .pickerStyle(MenuPickerStyle())
                              
                              Button(action: {
                                 
                                viewModel.selectedCourierId = selectedCourier
                                allocateCourier()
                                  
                              }) {
                                  Text("Allocate")
                                      .padding(.horizontal, 8)
                                      .padding(.vertical, 6)
                                      .background(Color.blue)
                                      .cornerRadius(5)
                                      .foregroundColor(.white)
                              }
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                statusSection
                delaySection
                Text("\(order.postcode), \(order.address)")
                    .font(.system(size: 15, weight: .medium))
            }
            if !order.phone.isEmpty {
                callLink("Call customer (\(order.customerName))", order.phone)
            }
            if let driverPhone = order.courierPhone, !driverPhone.isEmpty  {
                let firstName = order.courierName.split(separator: " ").first ?? ""
                callLink("Call driver (\(firstName))", driverPhone)
            }
            if let refundInfo = refundInfo {
                Text(refundInfo)
                    .font(.headline)
                    .foregroundColor(.red)
            }
        }
    }

    private var statusSection: some View {
        HStack {
            Text(deliveryTimeText)
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(deliveryTimeText.contains("ago") ? .red : .primary)
            Spacer()
            if order.status > 2 && 1==2 {
                Button(action: {
                    showCollectionSheet = true
                    viewModel.updateOrderLifecycle()
                }) {
                    Text("Edit")
                        .font(.system(size: 16, weight: .medium))
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(5)
                }
            }
        }
    }
    

    private var delaySection: some View {
        let delay = viewModel.getDeliveryEtaDelay()
        return Group {
            if delay > 0 {
                Text("Delay \(delay) min")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.red)
            }
        }
    }

    private var deliveryTimeText: String {
        if(order.status==5){
            return "Delivered"
        } else if(order.status==7){
            return "Canceled"
        }
        else{
            let deliveryEta = viewModel.getLifecycleEvent(for: "deliveryEta")?.value
            let received = viewModel.getLifecycleEvent(for: "received")?.value
            let timeSource = deliveryEta ?? received ?? order.deliveryTime
            return extractEtaTime(from: timeSource)
        }
    }

    private func callLink(_ text: String, _ phone: String) -> some View {
        Link(destination: URL(string: "tel:\(phone)")!) {
            Text(text)
                .foregroundColor(Color.blue)
                .font(.system(size: 15, weight: .medium))
        }
        .padding(.top, 2)
    }
}


struct ItemsView: View {
    var orderDetails: [OrderViewModel.OrderDetail]
    var totalPrice: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(orderDetails, id: \.productName) { detail in
                    HStack {
                        Text("\(detail.quantity) x").font(.system(size: 15, weight: .bold))
                        Text(detail.productName).font(.system(size: 15, weight: .regular))
                        Spacer()
                        Text("£\(detail.price * Double(detail.quantity), specifier: "%.2f")").font(.system(size: 15, weight: .regular))
                    }
                    .padding(.vertical, 5)
                }
            }
            HStack {
                Spacer()
                Text("£\(totalPrice, specifier: "%.2f")").font(.system(size: 15, weight: .bold)).padding(.top, 10)
            }
        }
    }
}

struct OrderProgressView: View {
    var order: Order
    @ObservedObject var viewModel: OrderViewModel
    @Binding var collectionMinutes: String
    @Binding var deliveryMinutes: String
    @Binding var pickupImage: UIImage?
    @Binding var deliveryImage: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let lifecycleEvent = viewModel.getLifecycleEvent(for: "received") {
                let formattedTime = extractEtaTime(from: lifecycleEvent.value)
                MessageBubble(senderName: "Order received", messageText: "ETA \(formattedTime)", messageTime: extractTime(from: lifecycleEvent.timestamp))
            }
            if let lifecycleEvent = viewModel.getLifecycleEvent(for: "allocated") {
                let formattedTime = extractEtaTime(from: lifecycleEvent.value)
                MessageBubble(senderName: "Assigned", messageText: "To \(order.courierName)", messageTime: extractTime(from: lifecycleEvent.timestamp))
            }
            if let lifecycleEvent = viewModel.getLifecycleEvent(for: "pickupEta") {
                MessageBubble(senderName: order.courierName, messageText: "Pickup eta \(extractTime(from: lifecycleEvent.value))", messageTime: extractTime(from: lifecycleEvent.timestamp))
            } else if !order.pickupTime.isEmpty {
                let messageText = collectionMinutes.isEmpty ? "Pickup eta \(order.pickupTime)" : "Pickup eta \(collectionMinutes) min"
                let messageTime = order.pickupETA.isEmpty ? currentTime : order.pickupETA
                MessageBubble(senderName: order.courierName, messageText: messageText, messageTime: messageTime)
            } else if !collectionMinutes.isEmpty {
                MessageBubble(senderName: order.courierName, messageText: "Pickup eta \(collectionMinutes) min", messageTime: currentTime)
            }
            if viewModel.getLifecycleEvent(for: "pickedup") != nil || ((order.pickupImageUrl?.isEmpty) == nil) || pickupImage != nil {
                PickupView(order: order, viewModel: viewModel, pickupImage: $pickupImage)
            }
            if let lifecycleEvent = viewModel.getLifecycleEvent(for: "deliveryEta") {
                MessageBubble(senderName: order.courierName, messageText: "Delivery eta \(extractTime(from: lifecycleEvent.value))", messageTime: extractTime(from: lifecycleEvent.timestamp))
            } else if !deliveryMinutes.isEmpty {
                MessageBubble(senderName: order.courierName, messageText: "Delivery eta \(deliveryMinutes) min", messageTime: currentTime)
            }
            if viewModel.getLifecycleEvent(for: "delivered") != nil || ((order.deliveryImageUrl?.isEmpty) == nil)  || deliveryImage != nil {
                DeliveryView(order: order, viewModel: viewModel, deliveryImage: $deliveryImage)
            }
        }
    }

    private var currentTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }
}

struct PickupView: View {
    var order: Order
    @ObservedObject var viewModel: OrderViewModel
    @Binding var pickupImage: UIImage?

    var body: some View {
        VStack {
            loadImage(order.pickupImageUrl, pickupImage)
            Spacer().frame(height: 10)
            HStack {
                Text("Picked up").foregroundColor(.primary).font(.system(size: 16, weight: .medium))
                Spacer()
                Text(viewModel.getLifecycleEvent(for: "pickedup")?.timestamp ?? currentTime).foregroundColor(.gray).font(.footnote).padding(.top, 10)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
        .frame(width: 250)
    }

    private var currentTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }
}

struct DeliveryView: View {
    var order: Order
    @ObservedObject var viewModel: OrderViewModel
    @Binding var deliveryImage: UIImage?

    var body: some View {
        VStack {
            loadImage(order.deliveryImageUrl, deliveryImage)
            Spacer().frame(height: 10)
            HStack {
                Text("Delivered").foregroundColor(.primary).font(.system(size: 16, weight: .medium))
                Spacer()
                Text(viewModel.getLifecycleEvent(for: "delivered")?.timestamp ?? currentTime).foregroundColor(.gray).font(.footnote).padding(.top, 10)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
        .frame(width: 250)
    }

    private var currentTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }
}

@ViewBuilder
private func loadImage(_ urlString: String?, _ image: UIImage?) -> some View {
    if let urlString = urlString, let url = URL(string: urlString) {
        KFImage(url)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
            .padding(.top, 5)
    } else if let image = image {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
            .padding(.top, 5)
    }
}
