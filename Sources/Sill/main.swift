import AppKit

// top-level code는 기본적으로 MainActor 격리가 아니라, MainActor로 격리된
// AppDelegate 생성을 위해 명시적으로 격리 구간을 만든다.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory) // Dock 아이콘 없음, 메뉴바 전용
    app.run()
}
