import SwiftUI

struct AddressView: View {
    @Environment(\.dismiss) var dismiss
    @FocusState private var focusedField: Field?
    @ObservedObject var viewModel: AddressViewModel

    var body: some View {
        NavigationView {
            VStack {
                InputView(label: "Postcode", text: $viewModel.postcode, focused: $focusedField, equals: .email)
                    .onChange(of: viewModel.postcode) { value in
                        if viewModel.didSelectResult { viewModel.didSelectResult = false; return }
                        if value.isEmpty {
                            viewModel.searchResults = []
                        } else {
                            viewModel.searchForAddress()
                        }
                    }
                    .autocapitalization(.allCharacters)

                if viewModel.didSelectResult {
                    Button(action: { viewModel.navigateToAddress2 = true }) {
                        Text("Continue")
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                }

                NavigationLink(destination: AddressView2(viewModel: viewModel), isActive: $viewModel.navigateToAddress2) { EmptyView() }

                if !viewModel.didSelectResult {
                    searchResultsView.padding(.top, 20)
                }

                Spacer()
            }
            .navigationBarTitle("", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Enter your postcode").font(.headline).foregroundColor(.primary)
                }
            }
            .navigationBarItems(leading: Button(action: { dismiss() }) {
                Image(systemName: "chevron.left").foregroundColor(.black)
            })
            .navigationBarBackButtonHidden(true)
            .padding()
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .accentColor(.black)
    }

    private var searchResultsView: some View {
        ForEach(viewModel.searchResults, id: \.self) { result in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 5).fill(Color.white)
                HStack {
                    Image(systemName: "location.fill").foregroundColor(.gray).padding(.trailing, 5)
                    Text(result.replacingOccurrences(of: ", UK", with: ""))
                }
            }
            .padding(.horizontal)
            .frame(height: 40)
            .onTapGesture { viewModel.handleSearchResultTap(result) }
        }
    }
}
