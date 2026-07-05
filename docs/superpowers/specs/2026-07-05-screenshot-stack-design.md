# Screenshot Stack — 설계 문서

날짜: 2026-07-05
상태: 승인됨

## 목표

Shottr/CleanShot X 스타일의 최소 기능 macOS 스크린샷 앱.
캡처한 스크린샷이 화면 오른쪽 가장자리에 스택으로 쌓이고,
드래그 앤 드롭 또는 ⌘C로 꺼내 쓸 수 있다.

## 범위

포함:
- 전역 단축키로 캡처 (⌥⇧4 = 영역/창, ⌥⇧3 = 전체 화면)
- 캡처 결과가 화면 오른쪽 가장자리 플로팅 스택에 썸네일로 쌓임
- 썸네일 드래그 → 파일로 어디든 드롭 (Finder, Slack 등)
- 썸네일 선택 후 ⌘C → 클립보드에 이미지+파일 복사
- 썸네일 호버 시 ✕ 버튼으로 닫기 (파일 삭제)
- 메뉴바 상주 (Dock 아이콘 없음)

제외 (YAGNI):
- 편집/주석 기능
- 자동 사라짐/핀
- 설정 화면, 왼쪽/오른쪽 위치 설정 (오른쪽 고정)
- 스크롤 캡처, OCR 등

## 기술 결정

| 결정 | 선택 | 이유 |
|---|---|---|
| 스택 | Swift + SwiftUI, 의존성 0개 | 네이티브 플로팅 패널/DnD/클립보드 필요 |
| 캡처 | `/usr/sbin/screencapture -i` 호출 | 네이티브 선택 UI 공짜. 스페이스바로 영역↔창 전환 내장. 캡처 UI 직접 구현 불필요 |
| 전역 단축키 | Carbon `RegisterEventHotKey` | 권한 불필요, 의존성 불필요, ~40줄 |
| 패널 | `NSPanel` (nonactivating, `.floating`, 모든 Spaces) | 포커스 안 뺏고 항상 위에 떠 있음 |
| 저장 | 임시 폴더(`~/Library/Application Support/ScreenshotStack/`)에 PNG | DnD가 파일 URL 기반이므로 파일 필수. 닫으면 삭제 |

## 구성 요소

1. **App / AppDelegate** — `LSUIElement` 메뉴바 앱. 상태 아이콘 + 메뉴(영역 캡처, 전체 캡처, 종료).
2. **HotkeyManager** — Carbon 핫키 등록. 콜백으로 CaptureService 호출.
3. **CaptureService** — `screencapture -i <경로>` / `screencapture <경로>` 실행. 파일이 생성되면(사용자가 ESC로 취소하면 안 생김) ScreenshotStore에 추가.
4. **ScreenshotStore** — `ObservableObject`. `[Screenshot]` 배열 (파일 URL + NSImage 썸네일). 추가/삭제.
5. **StackPanel** — 오른쪽 가장자리 고정 NSPanel + SwiftUI 콘텐츠. 스크린샷 0개면 숨김.
6. **ThumbnailView** — 썸네일 렌더. 클릭=선택 표시, `onDrag`로 파일 URL 제공, ⌘C 처리(NSPasteboard에 fileURL + PNG 데이터), 호버 ✕ 닫기.

## 데이터 흐름

```
전역 단축키 → CaptureService → screencapture CLI → PNG 파일 생성
  → ScreenshotStore.add → StackPanel에 썸네일 표시
  → 사용자: 드래그(파일 전달) / ⌘C(클립보드) / ✕(파일 삭제 + 스택 제거)
```

## 에러 처리

- 캡처 취소(ESC): 파일 미생성 → 무시.
- 화면 기록 권한 미승인: 최초 캡처 시 macOS가 자동으로 권한 안내 표시. 앱은 별도 처리 없음.
- 파일 삭제 실패: 스택에서는 제거, 에러는 로그만.

## 검증

- 수동: 빌드 → 단축키로 3종 캡처 → 스택 표시 → Finder로 DnD → ⌘C 후 미리보기에 붙여넣기 → ✕ 닫기 시 파일 삭제 확인.
- 자동 테스트는 두지 않음 (전부 시스템 UI 통합이라 단위 테스트 가치 낮음).
