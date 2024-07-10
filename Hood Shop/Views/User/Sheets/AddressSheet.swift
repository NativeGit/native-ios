import SwiftUI

struct AddressSheet: View {
    @Binding var addresses: [Address]
    var onAddNewAddress: () -> Void
    var onAddressSelected: (Address) -> Void
    var presentDeliveryAddressSheet: () -> Void
    @Environment(\.presentationMode) var presentationMode
    @State private var showingActionSheet = false
    @State private var addressToDelete: Address?

    var sortedAddresses: [Address] {
        addresses.sorted { $0.isDefault && !$1.isDefault }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 5)
            .frame(width: 45, height: 4.5)
            .foregroundColor(.gray)
            .padding()
        List {
            ForEach(sortedAddresses.indices, id: \.self) { index in
                let address = sortedAddresses[index]
                HStack(spacing: 0) {
                    Button(action: {
                        onAddressSelected(address)
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Image(systemName: "location").padding(.trailing, 8).foregroundColor(index == 0 ? .black : .gray)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("\(address.street), \(address.building)").foregroundColor(index == 0 ? .black : .gray)
                                Text(address.postcode).font(.subheadline).foregroundColor(index == 0 ? .black : .gray)
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    Image(systemName: "ellipsis").foregroundColor(.primary).padding(.leading).onTapGesture {
                        self.addressToDelete = address
                        self.showingActionSheet = true
                    }
                }
                .frame(height: 50)
            }
            Button(action: {
                presentDeliveryAddressSheet()
                presentationMode.wrappedValue.dismiss()
            }) {
                HStack {
                    Image(systemName: "plus").font(.system(size: 16, weight: .bold)).padding(.trailing, 8).foregroundColor(assets.brandColor)
                    Text("Add New Address").bold().foregroundColor(assets.brandColor)
                    Spacer()
                }
                .frame(height: 50)
            }
        }
        .actionSheet(isPresented: $showingActionSheet) {
            ActionSheet(title: Text("Actions"), message: Text("Choose an option"), buttons: [
                .destructive(Text("Delete")) {
                    if let addressToDelete = addressToDelete { deleteAddress(addressToDelete) }
                },
                .cancel()
            ])
        }
        .listStyle(PlainListStyle())
    }

    private func deleteAddress(_ address: Address) {
        addresses.removeAll { $0.id == address.id }
        if address.isDefault, !addresses.isEmpty {
            onAddressSelected(addresses[0])
            addresses[0].isDefault = true
        }
    }
}
