//
//  TopBar.swift
//  cyclo-ios
//
//  Created by Rohit Suresh on 9/10/25.
//

import SwiftUI

struct TopBar: View {
    var body: some View {
        HStack{
            Spacer()
            
            Button(action: {
                // push to user profile page
            }) {
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
            
            Button(action: {
                // push to app settings
            }) {
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
    TopBar()
}
