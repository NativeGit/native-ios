import SwiftUI

struct TimeSheetView: View {
    @Binding var isScheduleLaterSelected: Bool
    @Binding var selectedDate: Date
    @Binding var selectedTime: Date
    @Binding var selectedHeight: CGFloat
    @State private var showTimePicker = false

    private let startTime = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!
    private let endTime = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date())!
    private let timeInterval: TimeInterval = 15 * 60

    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: 5)
                .frame(width: 45, height: 4.5)
                .foregroundColor(.gray)
                .padding()

            List {
                Button(action: {
                    isScheduleLaterSelected = false
                    togglePicker(show: false)
                    UserDefaults.standard.set(0, forKey: "scheduleExpirationTimestamp")
                }) {
                    rowContent(iconName: "clock", text: "As soon as possible", isSelected: !isScheduleLaterSelected)
                }

                Button(action: {
                    isScheduleLaterSelected = true
                    togglePicker(show: true)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        UserDefaults.standard.set(formatDateTime(selectedDate, time: selectedTime), forKey: "scheduledDateTime")
                        let expirationTimestamp = Date().timeIntervalSince1970
                        UserDefaults.standard.set(expirationTimestamp, forKey: "scheduleExpirationTimestamp")
                    }
                }) {
                    rowContent(iconName: "calendar", text: scheduleLaterText, isSelected: isScheduleLaterSelected)
                }
            }
            .listStyle(PlainListStyle())

            if isScheduleLaterSelected {
                pickerSection.transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: showTimePicker)
    }

    private var scheduleLaterText: String {
        return isScheduleLaterSelected ? formatDateTime(selectedDate, time: selectedTime) : "Schedule for later"
    }

    private func togglePicker(show: Bool) {
        withAnimation {
            selectedHeight = show ? 400 : 200
            showTimePicker = show
        }
    }

    private func rowContent(iconName: String, text: String, isSelected: Bool) -> some View {
        HStack {
            Image(systemName: iconName).foregroundColor(isSelected ? .primary : .gray)
            Text(text).foregroundColor(isSelected ? .primary : .gray)
            Spacer()
        }
        .padding(.vertical)
    }

    @ViewBuilder
    private var pickerSection: some View {
        HStack {
            DatePickerScrollView(selectedDate: $selectedDate, selectedTime: $selectedTime, openingHours: openingHours)
                .frame(width: 150)
            Spacer()
            TimePicker(selectedDate: $selectedDate, selectedTime: $selectedTime, openingHours: openingHours, timeInterval: timeInterval)
                .frame(width: 150)
        }
        .frame(width: 340)
    }
}

private func formatDateTime(_ date: Date, time: Date) -> String {
    let timeFormatter = DateFormatter()
    timeFormatter.dateFormat = "HH:mm"
    let timePart = timeFormatter.string(from: time)
    
    let calendar = Calendar.current
    if calendar.isDateInToday(date) {
        return "Today \(timePart)"
    } else if calendar.isDateInTomorrow(date) {
        return "Tomorrow \(timePart)"
    } else {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "E dd/MM"
        let datePart = dateFormatter.string(from: date)
        return "\(datePart) \(timePart)"
    }
}


struct DatePickerScrollView: View {
    @Binding var selectedDate: Date
    @Binding var selectedTime: Date
    let openingHours: [OpeningHours] // Your opening hours data

    private var initialOffset: Int {
        let currentHour = Calendar.current.component(.hour, from: Date())
        return currentHour > 18 ? 1 : 0 // Start from tomorrow if after 6 PM
    }

    private func isOpenOn(day: Date) -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: day) - 2 // Adjusting for array indexing
        
        guard weekday >= 0, weekday < openingHours.count else { return false }
        
        let dayOpeningHours = openingHours[weekday]
        return !(dayOpeningHours.open == "0" && dayOpeningHours.close == "0")
    }

    private func firstAvailableDate() -> Date? {
        for offset in 0..<7 {
            let day = Calendar.current.date(byAdding: .day, value: offset + initialOffset, to: Date())!
            if isOpenOn(day: day) {
                return day
            }
        }
        return nil
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack {
                ForEach(0..<7, id: \.self) { offset in
                    let day = Calendar.current.date(byAdding: .day, value: offset + initialOffset, to: Date())!
                    if isOpenOn(day: day) {
                        Button(action: {
                            selectedDate = day
                            // UserDefaults standard set actions
                        }) {
                            Text(formatDateWithTime(day))
                                .foregroundColor(Calendar.current.isDate(day, inSameDayAs: selectedDate) ? .primary : .gray)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .padding()
                    }
                }
            }
        }
        .onAppear {
            if !isOpenOn(day: selectedDate), let firstOpenDate = firstAvailableDate() {
                selectedDate = firstOpenDate
            }
        }
    }
    
    private func formatDateWithTime(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "E dd/MM" // Example: "Fri 23/02"
            return dateFormatter.string(from: date)
        }
    }
}

struct TimePicker: View {
    @Binding var selectedDate: Date
    @Binding var selectedTime: Date
    let openingHours: [OpeningHours]
    let timeInterval: TimeInterval

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }

    private var todayOpeningHours: OpeningHours? {
        let weekday = Calendar.current.component(.weekday, from: selectedDate) - 1
        return openingHours.indices.contains(weekday) ? openingHours[weekday] : nil
    }

    private var startTime: Date {
        guard let open = todayOpeningHours?.open else { return Date() }
        return dateFrom(hourString: open)
    }

    private var endTime: Date {
        guard let close = todayOpeningHours?.close else { return Date() }
        return dateFrom(hourString: close)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack {
                ForEach(generateTimeSlots(), id: \.self) { time in
                    Button(action: {
                        selectedTime = time
                        // Add your UserDefaults logic here as needed
                    }) {
                        Text(timeFormatter.string(from: time))
                            .foregroundColor(isSelectedTime(time) ? .primary : .gray)
                    }
                    .padding(.vertical)
                }
            }
        }
        .onAppear {
            let slots = generateTimeSlots()
            if !slots.contains(where: { isSelectedTime($0) }) {
                selectedTime = slots.first ?? selectedTime
            }
        }
    }
    
    private func dateFrom(hourString: String) -> Date {
        guard hourString != "0", let hour = Int(hourString.prefix(2)), let minute = Int(hourString.suffix(2)) else {
            return Date()
        }
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: selectedDate) ?? Date()
    }
    
    private func generateTimeSlots() -> [Date] {
        var slots: [Date] = []
        var currentTime = startTime
        
        while currentTime < endTime {
            slots.append(currentTime)
            currentTime = Calendar.current.date(byAdding: .second, value: Int(timeInterval), to: currentTime)!
        }
        
        return slots
    }
    
    private func isSelectedTime(_ time: Date) -> Bool {
        Calendar.current.isDate(selectedTime, equalTo: time, toGranularity: .minute)
    }
}
