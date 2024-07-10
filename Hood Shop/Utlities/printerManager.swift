import UIKit
import BRLMPrinterKit

class PrinterManager {

    // Function to print an image using the Brother printer
    func printImage(image: UIImage) {
        // Create a Bluetooth channel using the printer's serial number
        let channel = BRLMChannel(bluetoothSerialNumber: "J3G536281")

        // Open the printer driver
        let generateResult = BRLMPrinterDriverGenerator.open(channel)
        guard generateResult.error.code == BRLMOpenChannelErrorCode.noError,
              let printerDriver = generateResult.driver else {
            print("Error - Open Channel: \(generateResult.error.code)")
            return
        }
        defer {
            printerDriver.closeChannel()
        }

        // Create print settings for the QL-820NWB model
        guard let printSettings = BRLMQLPrintSettings(defaultPrintSettingsWith: .QL_820NWB) else {
            print("Error - Unable to create print settings.")
            return
        }

        // Set label size and auto-cut settings
        printSettings.labelSize = .dieCutW62H100 // Adjust to your label size
        if UserDefaults.standard.string(forKey: "autoPrint") != "1" {
            printSettings.autoCut = true
        }

        // Resize the image to be printed
        let resizedImage = resizeImage(image: image, scale: 1.2) // 1.2 for 20% increase

        // Convert UIImage to CGImage for printing
        guard let cgImage = resizedImage.cgImage else {
            print("Error - Unable to convert UIImage to CGImage.")
            return
        }

        // Print the image
        let printError = printerDriver.printImage(with: cgImage, settings: printSettings)
        if printError.code != .noError {
            print("Error - Print Image: \(printError.code)")
        }
    }

    // Function to resize an image by a given scale factor
    private func resizeImage(image: UIImage, scale: CGFloat) -> UIImage {
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage ?? image
    }
}
