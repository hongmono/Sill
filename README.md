# ScreenshotStack

스크린샷이 화면 우측 하단 스택에 쌓이는 메뉴바 앱.

## 빌드

    ./make-app.sh && open ScreenshotStack.app

개발 중에는 `swift run`.

## 사용법

| 동작 | 방법 |
|---|---|
| 영역 캡처 | ⇧⌘4 후 드래그 |
| 창 캡처 | ⇧⌘4 후 스페이스바, 창 클릭 |
| 전체 화면 | ⇧⌘3 |
| 파일로 꺼내기 | 썸네일을 Finder/다른 앱으로 드래그 (드롭되면 스택에서 사라짐) |
| 스택에서 제거 | 썸네일 호버 후 ✕ (파일도 삭제) |

스크린샷은 `~/Library/Application Support/ScreenshotStack/`에 저장되고, ✕로 닫으면 삭제된다.
최초 캡처 시 화면 기록 권한을 승인해야 한다.
