# Screenshot Stack 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 캡처한 스크린샷이 화면 오른쪽 가장자리 스택에 쌓이고 DnD/⌘C로 꺼내 쓰는 메뉴바 앱.

**Architecture:** Swift Package 실행 파일 하나. `screencapture` CLI가 캡처 UI 전부를 담당하고, 앱은 (1) 전역 단축키, (2) 결과 PNG를 담는 ObservableObject 스토어, (3) 오른쪽 가장자리 플로팅 NSPanel + SwiftUI 썸네일 스택만 구현한다.

**Tech Stack:** Swift 5.9+, SwiftUI, AppKit, Carbon(핫키), 외부 의존성 0개.

**Spec:** `docs/superpowers/specs/2026-07-05-screenshot-stack-design.md`

## Global Constraints

- macOS 13 이상, Swift tools 5.9.
- 외부 패키지 의존성 금지 (Carbon/AppKit/SwiftUI만).
- 자동 단위 테스트 없음 (스펙 결정: 전부 시스템 UI 통합). 각 태스크는 `swift build` 성공 + 수동 검증으로 게이트.
- 스크린샷 저장 위치: `~/Library/Application Support/ScreenshotStack/`.
- 단축키: ⌥⇧4 = 영역/창(대화형), ⌥⇧3 = 전체 화면.
- 스택 패널: 화면 오른쪽 가장자리, 세로 중앙, 스크린샷 0개면 숨김.
- 검증 시 참고: `swift run`으로 실행하면 화면 기록 권한은 실행한 터미널 앱에 귀속된다. 최초 캡처 시 권한 대화상자가 뜨면 승인 후 재시도.

---

### Task 1: 프로젝트 골격 + 메뉴바 앱

**Files:**
- Create: `Package.swift`
- Create: `Sources/ScreenshotStack/main.swift`
- Create: `Sources/ScreenshotStack/AppDelegate.swift`
- Create: `.gitignore`

**Interfaces:**
- Produces: `AppDelegate: NSObject, NSApplicationDelegate` — 이후 태스크들이 `applicationDidFinishLaunching`에 초기화 코드를 추가한다.

- [ ] **Step 1: Package.swift 작성**

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ScreenshotStack",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "ScreenshotStack", path: "Sources/ScreenshotStack")
    ]
)
```

- [ ] **Step 2: .gitignore 작성**

```
.build/
.DS_Store
ScreenshotStack.app/
```

- [ ] **Step 3: main.swift 작성**

실행 타깃 최상위 코드가 엔트리포인트다 (`@main` 불필요).

```swift
import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // Dock 아이콘 없음, 메뉴바 전용
app.run()
```

- [ ] **Step 4: AppDelegate.swift 작성 (상태 아이콘 + 종료 메뉴만)**

```swift
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "camera.viewfinder",
            accessibilityDescription: "Screenshot Stack"
        )
        let menu = NSMenu()
        menu.addItem(withTitle: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
    }
}
```

- [ ] **Step 5: 빌드 확인**

Run: `swift build`
Expected: `Build complete!` (경고 없이)

- [ ] **Step 6: 수동 검증**

Run: `swift run` (백그라운드로 실행)
Expected: 메뉴바에 카메라 아이콘 표시, 클릭 시 "종료" 메뉴, 종료 동작. Dock 아이콘 없음.
확인 후 앱 종료.

- [ ] **Step 7: Commit**

```bash
git add Package.swift Sources .gitignore
git commit -m "feat: 메뉴바 앱 골격"
```

---

### Task 2: ScreenshotStore + CaptureService + 캡처 메뉴

**Files:**
- Create: `Sources/ScreenshotStack/ScreenshotStore.swift`
- Create: `Sources/ScreenshotStack/CaptureService.swift`
- Modify: `Sources/ScreenshotStack/AppDelegate.swift`

**Interfaces:**
- Consumes: Task 1의 `AppDelegate`.
- Produces:
  - `ScreenshotStore: ObservableObject` — `@Published var screenshots: [Screenshot]`, `@Published var selectedID: UUID?`, `func add(url: URL)`, `func remove(_ shot: Screenshot)`, `func copySelected()`, `static let directory: URL`. `Screenshot`은 `Identifiable`이며 `id: UUID`, `url: URL`, `image: NSImage`.
  - `CaptureService` — `init(store: ScreenshotStore)`, `func captureInteractive()`, `func captureFullScreen()`.

- [ ] **Step 1: ScreenshotStore.swift 작성**

```swift
import AppKit
import Combine

final class ScreenshotStore: ObservableObject {
    struct Screenshot: Identifiable {
        let id = UUID()
        let url: URL
        let image: NSImage
    }

    @Published var screenshots: [Screenshot] = []
    @Published var selectedID: UUID?

    static let directory: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ScreenshotStack")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    func add(url: URL) {
        guard let image = NSImage(contentsOf: url) else { return }
        screenshots.insert(Screenshot(url: url, image: image), at: 0)
        selectedID = screenshots.first?.id // 새 캡처가 곧바로 ⌘C 대상
    }

    func remove(_ shot: Screenshot) {
        try? FileManager.default.removeItem(at: shot.url)
        screenshots.removeAll { $0.id == shot.id }
        if selectedID == shot.id { selectedID = screenshots.first?.id }
    }

    func copySelected() {
        guard let shot = screenshots.first(where: { $0.id == selectedID }) else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([shot.url as NSURL, shot.image])
    }
}
```

- [ ] **Step 2: CaptureService.swift 작성**

```swift
import AppKit

final class CaptureService {
    private let store: ScreenshotStore

    init(store: ScreenshotStore) {
        self.store = store
    }

    /// 대화형 캡처. screencapture -i는 드래그=영역, 스페이스바=창 캡처를 자체 지원한다.
    func captureInteractive() {
        run(flags: ["-i"])
    }

    func captureFullScreen() {
        run(flags: [])
    }

    private func run(flags: [String]) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss.SSS"
        let url = ScreenshotStore.directory
            .appendingPathComponent("Screenshot \(formatter.string(from: Date())).png")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = flags + [url.path]
        process.terminationHandler = { [weak store] _ in
            DispatchQueue.main.async {
                // ESC로 취소하면 파일이 안 생긴다 — 그 경우 무시
                if FileManager.default.fileExists(atPath: url.path) {
                    store?.add(url: url)
                }
            }
        }
        try? process.run()
    }
}
```

- [ ] **Step 3: AppDelegate.swift에 스토어/캡처/메뉴 연결**

파일 전체를 아래로 교체:

```swift
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = ScreenshotStore()
    private lazy var capture = CaptureService(store: store)
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "camera.viewfinder",
            accessibilityDescription: "Screenshot Stack"
        )
        let menu = NSMenu()
        menu.addItem(withTitle: "영역/창 캡처 (⌥⇧4)", action: #selector(captureInteractive), keyEquivalent: "")
        menu.addItem(withTitle: "전체 화면 캡처 (⌥⇧3)", action: #selector(captureFullScreen), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
    }

    @objc private func captureInteractive() {
        capture.captureInteractive()
    }

    @objc private func captureFullScreen() {
        capture.captureFullScreen()
    }
}
```

- [ ] **Step 4: 빌드 확인**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 5: 수동 검증**

Run: `swift run` → 메뉴바 아이콘 → "영역/창 캡처" 클릭 → 영역 드래그.
Run: `ls ~/Library/Application\ Support/ScreenshotStack/`
Expected: `Screenshot <타임스탬프>.png` 파일 생성. ESC로 취소하면 파일 미생성.
(최초 실행 시 화면 기록 권한 요청이 뜨면 승인 후 재시도.)

- [ ] **Step 6: Commit**

```bash
git add Sources
git commit -m "feat: screencapture 기반 캡처와 스크린샷 스토어"
```

---

### Task 3: 오른쪽 가장자리 스택 패널 (표시 + 닫기)

**Files:**
- Create: `Sources/ScreenshotStack/StackPanelController.swift`
- Create: `Sources/ScreenshotStack/StackView.swift`
- Modify: `Sources/ScreenshotStack/AppDelegate.swift`

**Interfaces:**
- Consumes: `ScreenshotStore` (Task 2 시그니처 그대로).
- Produces:
  - `KeyablePanel: NSPanel` — `var onCopy: (() -> Void)?` (Task 4에서 사용).
  - `StackPanelController` — `init(store: ScreenshotStore)`. 스토어 변화를 구독해 패널 표시/숨김/크기를 스스로 관리.
  - `StackView: View` — `init(store: ScreenshotStore, makeKey: @escaping () -> Void)`.
  - `ThumbnailView: View` — Task 4가 이 뷰를 수정한다.

- [ ] **Step 1: StackPanelController.swift 작성**

```swift
import AppKit
import Combine
import SwiftUI

/// borderless 패널은 기본적으로 key window가 될 수 없어 ⌘C를 못 받는다 — 오버라이드 필요.
final class KeyablePanel: NSPanel {
    var onCopy: (() -> Void)?

    override var canBecomeKey: Bool { true }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command),
           event.charactersIgnoringModifiers == "c" {
            onCopy?()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

final class StackPanelController {
    private let panel: KeyablePanel
    private var cancellable: AnyCancellable?
    private let panelWidth: CGFloat = 176
    private let itemHeight: CGFloat = 112 // 썸네일 104 + 간격 8

    init(store: ScreenshotStore) {
        panel = KeyablePanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hidesOnDeactivate = false
        panel.onCopy = { [weak store] in store?.copySelected() }

        let view = StackView(store: store, makeKey: { [weak panel] in panel?.makeKey() })
        panel.contentView = NSHostingView(rootView: view)

        cancellable = store.$screenshots
            .receive(on: DispatchQueue.main)
            .sink { [weak self] shots in self?.layout(count: shots.count) }
    }

    private func layout(count: Int) {
        guard count > 0, let screen = NSScreen.main else {
            panel.orderOut(nil)
            return
        }
        let visible = screen.visibleFrame
        let height = min(CGFloat(count) * itemHeight + 16, visible.height)
        panel.setFrame(
            NSRect(x: visible.maxX - panelWidth, y: visible.midY - height / 2,
                   width: panelWidth, height: height),
            display: true
        )
        panel.orderFrontRegardless()
    }
}
```

- [ ] **Step 2: StackView.swift 작성 (표시 + 호버 ✕ 닫기)**

```swift
import SwiftUI

struct StackView: View {
    @ObservedObject var store: ScreenshotStore
    let makeKey: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 8) {
                ForEach(store.screenshots) { shot in
                    ThumbnailView(
                        shot: shot,
                        isSelected: store.selectedID == shot.id,
                        select: {
                            store.selectedID = shot.id
                            makeKey() // 패널을 key로 만들어야 ⌘C가 패널에 도착
                        },
                        close: { store.remove(shot) }
                    )
                }
            }
            .padding(8)
        }
    }
}

struct ThumbnailView: View {
    let shot: ScreenshotStore.Screenshot
    let isSelected: Bool
    let select: () -> Void
    let close: () -> Void
    @State private var hovering = false

    var body: some View {
        Image(nsImage: shot.image)
            .resizable()
            .scaledToFill()
            .frame(width: 160, height: 104)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.black.opacity(0.2),
                            lineWidth: isSelected ? 3 : 1)
            )
            .shadow(radius: 4)
            .overlay(alignment: .topTrailing) {
                if hovering {
                    Button(action: close) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white, .black.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .padding(4)
                }
            }
            .onHover { hovering = $0 }
    }
}
```

- [ ] **Step 3: AppDelegate에 패널 컨트롤러 연결**

`AppDelegate.swift`의 프로퍼티 선언부에 추가:

```swift
    private var panelController: StackPanelController!
```

`applicationDidFinishLaunching` 맨 앞에 추가:

```swift
        panelController = StackPanelController(store: store)
```

- [ ] **Step 4: 빌드 확인**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 5: 수동 검증**

Run: `swift run` → 캡처 2~3장.
Expected: 화면 오른쪽 가장자리 세로 중앙에 썸네일 스택 표시. 최신이 맨 위. 호버 시 ✕ 표시, ✕ 클릭 시 스택에서 제거 + `ls`로 파일 삭제 확인. 마지막 항목 닫으면 패널 숨김. 다른 앱 클릭해도 패널이 위에 유지되고 포커스를 뺏지 않음.

- [ ] **Step 6: Commit**

```bash
git add Sources
git commit -m "feat: 오른쪽 가장자리 스크린샷 스택 패널"
```

---

### Task 4: 선택 + ⌘C 복사 + 드래그 앤 드롭

**Files:**
- Modify: `Sources/ScreenshotStack/StackView.swift` (`ThumbnailView`의 body)

**Interfaces:**
- Consumes: `KeyablePanel.onCopy`(Task 3에서 이미 `store.copySelected()`에 연결됨), `ThumbnailView.select` 클로저, `Screenshot.url`.
- Produces: 없음 (동작 완성).

- [ ] **Step 1: ThumbnailView에 탭 선택과 드래그 추가**

`ThumbnailView`의 body에서 `.shadow(radius: 4)` 바로 다음에 두 줄 추가:

```swift
            .shadow(radius: 4)
            .onTapGesture(perform: select)
            .onDrag { NSItemProvider(object: shot.url as NSURL) }
```

(파일 URL 프로바이더라서 Finder/Slack 등에 드롭하면 파일로 전달된다. ⌘C 경로는 이미 연결돼 있다: 탭 → `makeKey()` → ⌘C → `KeyablePanel.performKeyEquivalent` → `store.copySelected()`.)

- [ ] **Step 2: 빌드 확인**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 3: 수동 검증**

Run: `swift run` → 캡처 2장 후:
1. 썸네일 클릭 → 파란(accent) 테두리로 선택 표시 이동.
2. ⌘C → 미리보기 앱에서 ⌘N (클립보드로 새 문서) → 캡처 이미지 확인. Finder에서 ⌘V → 파일 복사 확인.
3. 썸네일을 Finder 데스크톱으로 드래그 → PNG 파일 복사 확인.

- [ ] **Step 4: Commit**

```bash
git add Sources
git commit -m "feat: 썸네일 선택, ⌘C 복사, 드래그 앤 드롭"
```

---

### Task 5: 전역 단축키

**Files:**
- Create: `Sources/ScreenshotStack/HotkeyManager.swift`
- Modify: `Sources/ScreenshotStack/AppDelegate.swift`

**Interfaces:**
- Consumes: `CaptureService.captureInteractive()`, `CaptureService.captureFullScreen()`.
- Produces: `HotkeyManager` — `func register(keyCode: UInt32, modifiers: UInt32, id: UInt32, handler: @escaping () -> Void)`.

- [ ] **Step 1: HotkeyManager.swift 작성**

Carbon `RegisterEventHotKey`는 접근성 권한 없이 동작하는 유일한 전역 핫키 API다.

```swift
import Carbon.HIToolbox

final class HotkeyManager {
    private var handlers: [UInt32: () -> Void] = [:]
    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var eventHandler: EventHandlerRef?

    init() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event, EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID), nil,
                    MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID
                )
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData!).takeUnretainedValue()
                manager.handlers[hotKeyID.id]?()
                return noErr
            },
            1, &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }

    func register(keyCode: UInt32, modifiers: UInt32, id: UInt32, handler: @escaping () -> Void) {
        handlers[id] = handler
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x5353_5441), id: id) // "SSTA"
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        hotKeyRefs.append(ref)
    }
}
```

- [ ] **Step 2: AppDelegate에 핫키 등록**

`AppDelegate.swift` 상단에 import 추가:

```swift
import Carbon.HIToolbox
```

프로퍼티 추가:

```swift
    private let hotkeys = HotkeyManager()
```

`applicationDidFinishLaunching` 마지막에 추가:

```swift
        hotkeys.register(
            keyCode: UInt32(kVK_ANSI_4),
            modifiers: UInt32(optionKey | shiftKey),
            id: 1
        ) { [weak self] in self?.capture.captureInteractive() }
        hotkeys.register(
            keyCode: UInt32(kVK_ANSI_3),
            modifiers: UInt32(optionKey | shiftKey),
            id: 2
        ) { [weak self] in self?.capture.captureFullScreen() }
```

`capture`가 `private lazy var`라 클로저에서 접근하려면 그대로 두면 된다 (self 경유).

- [ ] **Step 3: 빌드 확인**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 4: 수동 검증**

Run: `swift run` → 다른 앱(예: Safari)에 포커스를 둔 상태에서:
- ⌥⇧4 → 십자선 커서 → 드래그로 영역 캡처 → 스택에 추가. 다시 ⌥⇧4 → 스페이스바 → 창 클릭 → 창 캡처.
- ⌥⇧3 → 전체 화면이 즉시 스택에 추가.

- [ ] **Step 5: Commit**

```bash
git add Sources
git commit -m "feat: 전역 단축키 ⌥⇧4/⌥⇧3"
```

---

### Task 6: 앱 번들 스크립트 + 최종 검증

**Files:**
- Create: `Info.plist`
- Create: `make-app.sh`
- Create: `README.md`

**Interfaces:**
- Consumes: 완성된 실행 파일 (`swift build -c release` 산출물).
- Produces: 더블클릭 실행 가능한 `ScreenshotStack.app`.

- [ ] **Step 1: Info.plist 작성**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.hongmono.ScreenshotStack</string>
    <key>CFBundleName</key>
    <string>ScreenshotStack</string>
    <key>CFBundleExecutable</key>
    <string>ScreenshotStack</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
```

- [ ] **Step 2: make-app.sh 작성**

```bash
#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
APP=ScreenshotStack.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/ScreenshotStack "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"
codesign --force --sign - "$APP" # ad-hoc 서명: 화면 기록 권한(TCC)이 안정적으로 유지되게 함
echo "built: $APP"
```

Run: `chmod +x make-app.sh`

- [ ] **Step 3: 번들 빌드 확인**

Run: `./make-app.sh`
Expected: `built: ScreenshotStack.app`
Run: `open ScreenshotStack.app`
Expected: 메뉴바 앱 실행 (Dock 아이콘 없음). 최초 캡처 시 화면 기록 권한 요청 → 승인.

- [ ] **Step 4: README.md 작성**

```markdown
# ScreenshotStack

스크린샷이 화면 오른쪽 가장자리 스택에 쌓이는 메뉴바 앱.

## 빌드

    ./make-app.sh && open ScreenshotStack.app

개발 중에는 `swift run`.

## 사용법

| 동작 | 방법 |
|---|---|
| 영역 캡처 | ⌥⇧4 후 드래그 |
| 창 캡처 | ⌥⇧4 후 스페이스바, 창 클릭 |
| 전체 화면 | ⌥⇧3 |
| 클립보드 복사 | 썸네일 클릭 후 ⌘C |
| 파일로 꺼내기 | 썸네일을 Finder/다른 앱으로 드래그 |
| 스택에서 제거 | 썸네일 호버 후 ✕ (파일도 삭제) |

스크린샷은 `~/Library/Application Support/ScreenshotStack/`에 저장되고, ✕로 닫으면 삭제된다.
최초 캡처 시 화면 기록 권한을 승인해야 한다.
```

- [ ] **Step 5: 스펙 검증 체크리스트 (수동, 번들 앱으로)**

1. ⌥⇧4 영역 캡처 → 스택 표시 ✓
2. ⌥⇧4 + 스페이스바 창 캡처 ✓
3. ⌥⇧3 전체 화면 ✓
4. ESC 취소 → 스택 변화 없음 ✓
5. 썸네일 클릭 + ⌘C → 미리보기 ⌘N으로 붙여넣기 ✓
6. 썸네일 드래그 → Finder에 파일 복사 ✓
7. ✕ 닫기 → 파일 삭제 + 마지막 항목이면 패널 숨김 ✓
8. 다른 Space/전체화면 앱에서도 패널 표시 ✓

- [ ] **Step 6: Commit**

```bash
git add Info.plist make-app.sh README.md
git commit -m "feat: 앱 번들 스크립트와 README"
```
