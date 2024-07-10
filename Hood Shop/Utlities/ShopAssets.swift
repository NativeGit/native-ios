import SwiftUI

let shopId = "798"
let assets = GlobalAssets.shared.getAssets(for: shopId)

class GlobalAssets {
    static let shared = GlobalAssets()
    
    private let defaultAssets = ShopAssets(
        brandTitle: "Default Title",
        brandColor: Color.blue,
        brandFont: "Arial",
        brandFontSize: 16,
        logoPaddinTop: 0,
        name: "Default Name",
        icon: "https://minitel.co.uk/images/uploads/1icon.png",
        bio: "Default Bio",
        coordinate: (latitude: 0.0, longitude: 0.0),
        instagram: "default_instagram",
        pricePercentage: 1.0,
        pickup: false,
        nextDay: false,
        isHeader: false
    )
    
    private let shopAssets: [String: ShopAssets] = [
        "1": ShopAssets(
            brandTitle: "BEIGEL BAKE",
            brandColor: Color(hex: "#D20F32"),
            brandFont: "Verdana Bold",
            brandFontSize: 20,
            logoPaddinTop: 0,
            name: "Beigel Bake",
            icon: "https://minitel.co.uk/images/uploads/1icon.png",
            bio: "It's Free Beigel Friday! 🥯🥯🎉",
            coordinate: (latitude: 51.52465200268983, longitude: -0.07180371838756233),
            instagram: "beigel_bake",
            pricePercentage: 1.24,
            pickup: false,
            nextDay: false,
            isHeader: true
        ),
        "798": ShopAssets(
            brandTitle: "slice",
            brandColor: Color(hex: "#124E46"),
            brandFont: "Noteworthy",
            brandFontSize: 34,
            logoPaddinTop: -15,
            name: "Slice Pizza",
            icon: "",
            bio: "Delicious pizza by the slice",
            coordinate: (latitude: 51.53371593340245, longitude: -0.17223041838701442),
            instagram: "panzers_deli",
            pricePercentage: 1.0,
            pickup: true,
            nextDay: true,
            isHeader: false
        )
    ]
    
    func getAssets(for shopId: String) -> ShopAssets {
        return shopAssets[shopId] ?? defaultAssets
    }
}

struct ShopAssets {
    var brandTitle: String
    var brandColor: Color
    var brandFont: String
    var brandFontSize: CGFloat
    var logoPaddinTop: Double
    var name: String
    var icon: String
    var bio: String
    var coordinate: (latitude: Double, longitude: Double)
    var instagram: String
    var pricePercentage: Double
    var pickup: Bool
    var nextDay: Bool
    var isHeader: Bool
}

