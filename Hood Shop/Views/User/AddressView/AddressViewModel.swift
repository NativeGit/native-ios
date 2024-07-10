import SwiftUI
import Combine
import CoreLocation

class AddressViewModel: ObservableObject {
    @Published var cancellables: Set<AnyCancellable> = []
    @Published var didSelectResult = false
    @Published var street = ""
    @Published var postcode = ""
    @Published var building = ""
    @Published var name = ""
    @Published var phone = ""
    @Published var floor = ""
    @Published var apartment = ""
    @Published var instructions = ""
    @Published var searchResults: [String] = []
    @Published var navigateToAddress2 = false
    @Published var addressCoordinate = CLLocation(latitude: 0.0, longitude: 0.0)
    @Published var coordinates: CLLocationCoordinate2D?
    @Published var fieldErrors: [Field: Bool] = [:]

    var onSave: (Address) -> Void

    init(onSave: @escaping (Address) -> Void) {
        self.onSave = onSave
    }

    func searchForAddress() {
        let apiKey = "AIzaSyCRMAfQhTSj3SdwTs_npaciMPom7zsEAwo"
        let urlString = "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=\(postcode.replacingOccurrences(of: " ", with: "+"))&components=country:GB&types=geocode&key=\(apiKey)"
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: GooglePlacesResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { response in
                self.searchResults = response.predictions.compactMap { self.isValidUKPostcode($0.description) ? $0.description : nil }
            })
            .store(in: &cancellables)
    }

    func handleSearchResultTap(_ result: String) {
        let components = result.components(separatedBy: ", ")
        if components.count >= 2 {
            postcode = components.first { isValidUKPostcode($0) } ?? ""
            street = !components[0].contains("London") ? components[0] : ""
            fetchCoordinates(for: postcode)
        }
        searchResults = []
    }

    private func isValidUKPostcode(_ postcode: String) -> Bool {
        let regex = "([Gg][Ii][Rr] 0[Aa]{2})|((([A-Za-z][0-9]{1,2})|(([A-Za-z][A-Ha-hJ-Yj-y][0-9]{1,2})|(([A-Za-z][0-9][A-Za-z])|([A-Za-z][A-Ha-hJ-Yj-y][0-9]?[A-Za-z]))))\\s?[0-9][A-Za-z]{2})"
        return postcode.range(of: regex, options: .regularExpression) != nil
    }

    private func fetchCoordinates(for address: String) {
        CLGeocoder().geocodeAddressString(address) { placemarks, _ in
            if let location = placemarks?.first?.location?.coordinate {
                self.coordinates = location
                self.addressCoordinate = CLLocation(latitude: location.latitude, longitude: location.longitude)
                UserDefaults.standard.set("\(location.latitude)", forKey: "lat")
                UserDefaults.standard.set("\(location.longitude)", forKey: "lng")
                self.navigateToAddress2 = true
            }
        }
    }

    func saveAddress() {
        let address = Address(
            street: street,
            building: building,
            postcode: postcode,
            name: name,
            phone: phone,
            lat: addressCoordinate.coordinate.latitude,
            lng: addressCoordinate.coordinate.longitude
        )
        onSave(address)
    }
}
