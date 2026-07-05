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

## 릴리스

`release` 브랜치에 push하거나 Actions에서 Release 워크플로를 수동 실행하면
유니버설 바이너리 빌드 → Developer ID 서명 → 공증(notarize) → DMG가 GitHub Release에 올라간다.

필요한 리포지토리 시크릿 (Lathe와 동일):
`SIGNING_CERT_P12`, `SIGNING_CERT_PASSWORD`, `KEYCHAIN_PASSWORD`,
`APPLE_NOTARY_KEY_P8_BASE64`, `APPLE_NOTARY_KEY_ID`, `APPLE_NOTARY_ISSUER_ID`
