//
//  HomePage.swift
//  cyclo-ios
//
//  Created by Rohit Suresh on 9/8/25.
//

import SwiftUI
import Foundation

struct HomePage: View {
    
    let fertilityValue = "LOW"
    let pregnancyChance = "LOW"
    let calendar = Calendar.current
    let weekDates: [Date] = {
        let today = Date()
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: today)
        let startOfWeek = calendar.date(byAdding: .day, value: -(weekday - 1), to: today)!
        return (0..<7).map { calendar.date(byAdding: .day, value: $0, to: startOfWeek)! }
    }()
    
    var body: some View {
        VStack{
            TopBar()
            
            Spacer() //Hstack spacer
            
            HStack(spacing: 16) {
                ForEach(weekDates, id: \.self) { date in
                    VStack {
                        // Letter of the day
                        Text(dayLetter(for: date))
                            .font(.headline)
                        
                        // Numeric day
                        Text("\(dayNumber(for: date))")
                            .font(.subheadline)
                    }
                    .padding(8)
                    .background(isToday(date) ? Color.cycloSecondary.opacity(0.3) : Color.clear)
                    .cornerRadius(8)
                }
            }
            
            Spacer()
            
            VStack {
                Text("N").font(.system(size: 64, weight: .bold, design: .rounded))
                
                Text("Days Until Period").font(.system(size: 28, weight: .thin))
                
            }
            
            Spacer()
            
            Text("Fertility is ") +
            Text("\(fertilityValue)")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.cycloPrimary) +
            Text(" today")
            
            Text("Chances of preganancy are ") +
            Text("\(pregnancyChance)")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.cycloPrimary) +
            Text(" today")
            
            Spacer()
            
            Button(action: {
                // Send to period log page
            }) {
                Text("Log Period")
                    .padding()
                    .background(Color.cycloPrimary)
                    .foregroundStyle(.white)
                    .cornerRadius(16)
            }
            
            Spacer()
            
            Button(action: {
                // Send to symptoms log page
            }) {
                Text("Log Symptoms")
                    .padding()
                    .background(Color.cycloSecondary)
                    .foregroundStyle(.white)
                    .cornerRadius(16)
            }
            
            Spacer()
            Spacer()
            Spacer()
            Spacer()
            Spacer()
            Spacer()
            
        }.padding()
    }
    // Helpers
    func dayLetter(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E" // "Mon", "Tue", etc.
        return String(formatter.string(from: date).prefix(1))
    }

    func dayNumber(for date: Date) -> Int {
        calendar.component(.day, from: date)
    }

    func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }
}

#Preview {
    HomePage()
}
