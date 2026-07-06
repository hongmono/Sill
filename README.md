# Sill

스크린샷이 화면 우측 하단 스택에 쌓이는 메뉴바 앱.

## 설치

```bash
brew install hongmono/tap/sill
```

또는 [Releases](https://github.com/hongmono/Sill/releases)에서 DMG 다운로드. 업데이트는 앱이 자동 확인한다(Sparkle).

## 빌드

    ./make-app.sh && open Sill.app

개발 중에는 `swift run`.

## 사용법

| 동작 | 방법 |
|---|---|
| 영역/창 캡처 | ⇧⌘4 후 드래그 (스페이스바 → 창 클릭) |
| 전체 화면 | ⇧⌘3 |
| 캡처 후 프리뷰 | 캡처하면 큰 프리뷰가 뜬다 — **Enter** 스택에 저장, **O** 텍스트 추출, **ESC** 버리기 |
| 파일로 꺼내기 | 썸네일을 Finder/다른 앱으로 드래그 (드롭되면 스택에서 사라짐) |
| 스택에서 제거 | 썸네일 호버 후 ✕ (파일도 삭제) |
| 텍스트 추출 (OCR) | 프리뷰에서 O, 또는 스택 썸네일 우클릭 → "텍스트 추출" |
| 번역 | OCR 카드에서 **T** — 언어 자동감지 후 한국어면 영어로, 그 외엔 한국어로 |

프리뷰의 OCR 키(기본 O)는 설정에서 변경할 수 있고, 한글 입력 상태에서도 같은 자리 키('ㅐ')로 동작한다.
OCR 결과는 화면 중앙 카드에 뜬다 — Enter/⌘C로 복사, **T로 번역**(원문 아래 표시), ESC로 닫기.
번역 엔진은 설정에서 고른다: **애플 온디바이스**(기본·무료·오프라인, 처음 쓸 때 언어 모델 다운로드 안내가 한 번 뜰 수 있음)
또는 **DeepL API**(설정에 API 키 입력 — 키체인 저장, free/pro 키는 자동 판별).

스크린샷은 `~/Library/Application Support/Sill/`에 저장되고, ✕로 닫으면 삭제된다.
최초 캡처 시 화면 기록 권한을 승인해야 한다.

## 릴리스

`release` 브랜치에 push하거나 Actions에서 Release 워크플로를 수동 실행하면
유니버설 바이너리 빌드 → Developer ID 서명 → 공증(notarize) → DMG가 GitHub Release에 올라간다.

필요한 리포지토리 시크릿 (Lathe와 동일):
`SIGNING_CERT_P12`, `SIGNING_CERT_PASSWORD`, `KEYCHAIN_PASSWORD`,
`APPLE_NOTARY_KEY_P8_BASE64`, `APPLE_NOTARY_KEY_ID`, `APPLE_NOTARY_ISSUER_ID`,
`SPARKLE_PRIVATE_KEY`, 그리고 [homebrew-tap](https://github.com/hongmono/homebrew-tap)
자동 갱신용 `TAP_PUSH_TOKEN` (repo 권한 PAT, 없으면 tap 갱신만 스킵됨)
