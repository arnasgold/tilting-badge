//
//  BadgeTestApp.swift
//  BadgeTest
//
//  Created by Arnas on 25/08/2023.
//

import SwiftUI

@main
struct BadgeTestApp: App {
    var body: some Scene {
        let viewModel = SharedViewModel()
        
        WindowGroup {
            TiltImageView(viewModel: viewModel)
        }
    }
}
