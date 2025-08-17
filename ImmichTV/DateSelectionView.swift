//
//  DateSelectionView.swift
//  ImmichTV
//
//  Created by David Lüthi on 31.03.2025.
//

import SwiftUI

struct DateSelectionView: View {
    // State for selected date components
    let label: String
    @Binding var chosenDate: Date?
    @Binding var reset: Bool
    @State var valid = false
    @State private var selectedDay: Int? = nil //Calendar.current.component(.day, from: Date())
    @State private var selectedMonth: Int? = nil // = Calendar.current.component(.month, from: Date())
    @State private var selectedYear: Int? = nil // = Calendar.current.component(.year, from: Date())
    
    // Focus states for tvOS navigation
    @FocusState private var focusedButton: String? // Track which button is focused
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
                Text(label).font(.caption2)
                HStack(spacing: 0) {
                    MyDatePicker(selected: $selectedDay, lowerBound: 1, higherBound: 31, currentNumber: Calendar.current.component(.day, from: Date()))
                        .onChange(of: selectedDay) {
                            let date = formattedDate
                            chosenDate = valid ? date : nil
                        }
                    MyDatePicker(selected: $selectedMonth, lowerBound: 1, higherBound: 12, currentNumber: Calendar.current.component(.month, from: Date()))
                        .onChange(of: selectedMonth) {
                            let date = formattedDate
                            chosenDate = valid ? date : nil
                        }
                    MyDatePicker(selected: $selectedYear, lowerBound: 2000, higherBound: Calendar.current.component(.year, from: Date()), currentNumber: Calendar.current.component(.year, from: Date()))
                        .onChange(of: selectedYear) {
                            let date = formattedDate
                            chosenDate = valid ? date : nil
                        }
                }
            }
            .padding(0)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.1)) // Light gray background
            )
            .font(.system(size: 16, weight: .medium, design: .rounded)) // Custom font
            .textFieldStyle(.plain) // Removes default styling (optional)
            .onChange(of: reset) { _, after in
                if after {
                    selectedDay = nil 
                    selectedMonth = nil
                    selectedYear = nil
                    reset = false
                }
            }
    }
    
    // Helper to convert month number to name
    private func monthName(for month: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        let date = Calendar.current.date(from: DateComponents(month: month))!
        return formatter.string(from: date)
    }
    
    // Computed property for formatted selected date
    private var formattedDate: Date? {
        if selectedDay == nil && selectedMonth == nil && selectedYear != nil {
            selectedDay = 1
            selectedMonth = 1
        }
        if selectedDay == nil || selectedMonth == nil || selectedYear == nil {
            valid = false
            return nil
        }
        let calendar = Calendar.current
        var components = DateComponents()
        components.day = selectedDay
        components.month = selectedMonth
        components.year = selectedYear
        
        if let date = calendar.date(from: components) {
            chosenDate = date
            selectedDay = Calendar.current.component(.day, from: date)
            selectedMonth = Calendar.current.component(.month, from: date)
            selectedYear = Calendar.current.component(.year, from: date)
            valid = true
            return date
        } else {
            selectedDay = nil
            selectedMonth = nil
            selectedYear = nil
            valid = false
            return nil
        }
    }
}


struct MyDatePicker: View {
    @Binding var selected: Int?
    let lowerBound: Int
    let higherBound: Int
    let currentNumber: Int
    @FocusState private var focusedButton: String? // Track which button is focused
    
    var body: some View {
        HStack(spacing: 0) {
            // Day Picker
            Picker("", selection: $selected) {
                Text("\(currentNumber)").font(.system(size: 16, weight: .medium, design: .rounded)).tag(currentNumber)
                Text("--").font(.system(size: 16, weight: .medium, design: .rounded)).tag(nil as Int?) // Associates with nil
                ForEach(Array(lowerBound...higherBound), id: \.self) { number in
                    Text("\(number)").tag(number)
                        .font(.system(size: 16, weight: .medium, design: .rounded)) // Custom font
                        .tag(number as Int?) // Optional tag to match selection type
                }
            }
            .pickerStyle(.menu)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.1)) // Light gray background
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(focusedButton == "picker" ? Color.purple : Color.gray, lineWidth: 2) // Dynamic border
            )
            .foregroundStyle(focusedButton == "picker" ? .purple : .primary) // Text color adapts to light/dark mode
            .font(.system(size: 16, weight: .medium, design: .rounded)) // Custom font
            .textFieldStyle(.plain) // Removes default styling (optional)
            .tint(.purple) // Cursor color
            .focused($focusedButton, equals: "picker")
        }
    }
}

#if os(tvOS)
#else
struct DateSelectionVIewIOS: View {
    let label: String
    @Binding var selectDate: Date?
    @FocusState private var focusedButton: String? // Track which button is focused
    
    var body: some View {
        if let date = selectDate {
            DatePicker(label, selection: Binding(
                    get: { date },
                    set: { selectDate = $0 }
                ), displayedComponents: [.date]
            )
            .datePickerStyle(.compact)
            .immichTVTestFieldStyle(isFocused: focusedButton == "date")
            .focused($focusedButton, equals: "date")
            .frame(width: 200, height: 50)
        } else {
            Button(action: {
                selectDate  = Date()
            }) { Text(label).frame(width: 200, height: 32) }.buttonStyle(ImmichTVButtonStyle(isFocused: focusedButton == "date"))
                .focused($focusedButton, equals: "date")
        }
    }
}
#endif
