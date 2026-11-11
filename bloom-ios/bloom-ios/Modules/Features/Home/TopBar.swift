//
//  TopBar.swift
//  bloom-ios
//
//  Created by Rohit Suresh on 9/10/25.
//
//  Just the brand title now — Profile/Settings moved out to RootTabView's tab bar, so there's
//  nothing left for this to navigate to.
//

import SwiftUI

struct TopBar: View {
    var body: some View {
        Text("Bloom")
            .font(.system(size: 48, weight: .bold, design: .rounded))
            .foregroundStyle(Color.bloomPrimary)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

#Preview {
    TopBar()
}
