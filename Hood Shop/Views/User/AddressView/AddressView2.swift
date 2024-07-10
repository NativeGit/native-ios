import SwiftUI
import CoreLocation

struct AddressView2: View {
    @FocusState private var focusedField: Field?
    @ObservedObject var viewModel: AddressViewModel

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollViewReader { scrollView in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading) {
                        InputView(label: "Postcode", text: $viewModel.postcode, focused: $focusedField, equals: .email).disabled(true)
                        InputView(label: "Street", text: $viewModel.street, focused: $focusedField, equals: .street, showError: .constant(viewModel.fieldErrors[.street] ?? false))
                        InputView(label: "Building name / number", text: $viewModel.building, focused: $focusedField, equals: .building, showError: .constant(viewModel.fieldErrors[.building] ?? false))
                        Text("Contact details").font(.subheadline).padding(.top).padding(.bottom, -5)
                        InputView(label: "Name", text: $viewModel.name, focused: $focusedField, equals: .name, showError: .constant(viewModel.fieldErrors[.name] ?? false))
                        InputView(label: "Phone", text: $viewModel.phone, focused: $focusedField, equals: .phone, showError: .constant(viewModel.fieldErrors[.phone] ?? false)).keyboardType(.phonePad)
                        Text("Optional").font(.subheadline).padding(.top).padding(.bottom, -5)
                        HStack {
                            InputView(label: "Floor", text: $viewModel.floor, focused: $focusedField, equals: .floor)
                            InputView(label: "Apartment", text: $viewModel.apartment, focused: $focusedField, equals: .apartment)
                        }
                        InputView(label: "Other instructions for the courier", text: $viewModel.instructions, focused: $focusedField, equals: .instructions).padding(.bottom)
                    }
                    .onChange(of: focusedField) { newValue in
                        if let newValue = newValue { withAnimation { scrollView.scrollTo(newValue, anchor: .top) } }
                    }
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(viewModel.postcode).font(.headline).foregroundColor(.primary)
                }
            }
            Button(action: {
                viewModel.fieldErrors = [:]
                if viewModel.street.isEmpty { viewModel.fieldErrors[.street] = true }
                if viewModel.building.isEmpty { viewModel.fieldErrors[.building] = true }
                if viewModel.name.isEmpty { viewModel.fieldErrors[.name] = true }
                if viewModel.phone.isEmpty { viewModel.fieldErrors[.phone] = true }
                if viewModel.fieldErrors.isEmpty {
                    viewModel.saveAddress()
                }
            }) {
                Text("Save address").font(.system(size: 16, weight: .bold)).frame(maxWidth: .infinity, alignment: .center)
            }
            .padding()
            .background(assets.brandColor)
            .foregroundColor(.white)
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.bottom, 10)
            .padding(.top, 5)
        }
    }
}
