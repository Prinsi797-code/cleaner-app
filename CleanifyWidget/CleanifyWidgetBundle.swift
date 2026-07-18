//
//  CleanifyWidgetBundle.swift
//  CleanifyWidget
//
//  Created by Aniket Dhandhukiya on 17/07/26.
//

import WidgetKit
import SwiftUI

@main
struct CleanifyWidgetBundle: WidgetBundle {
    var body: some Widget {
        CleanifyWidget()
        CleanifyWidgetControl()
        CleanifyWidgetLiveActivity()
    }
}
