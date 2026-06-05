//
//  TYScreenShotToolApp.swift
//  TYScreenShotTool
//
//  Created by Sheldon on 2026/6/5.
//

import SwiftUI

@main
struct TYScreenShotToolApp: App {
    private let globalHotKeyService: GlobalHotKeyService

    init() {
        let service = GlobalHotKeyService(hotKey: .screenshot)
        _ = service.register()
        self.globalHotKeyService = service
    }

    var body: some Scene {
        MenuBarExtra("ScreenshotTool", systemImage: "camera.viewfinder") {
            MenuBarContentView()
        }
        .menuBarExtraStyle(.menu)
    }
}
