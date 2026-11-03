//
//  TopBar.swift
//  cyclo-ios
//
//  Created by Rohit Suresh on 9/10/25.
//

import SwiftUI

struct TopBar: View {
    let onProfileTapped: () -> Void
    let onSettingsTapped: () -> Void

    var body: some View {
        HStack{
            Spacer()

            Button(action: onProfileTapped) {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .foregroundColor(Color.cycloPrimary)
            }

            Spacer()
            Spacer()

            Text("Cyclo")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(Color.cycloPrimary)

            Spacer()
            Spacer()

            Button(action: onSettingsTapped) {
                Image(systemName: "gearshape.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .foregroundColor(Color.cycloPrimary)
            }
            Spacer()
        }
    }
}

#Preview {
    TopBar(onProfileTapped: {}, onSettingsTapped: {})
}
