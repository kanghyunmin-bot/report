# App Store 배포 준비

이 변경은 제출용 코드와 빌드 설정을 준비합니다. 서명된 설치판, App Store 심사 통과 또는 가격 설정 완료를 뜻하지 않습니다.

## 개발자 계정을 만든 다음

1. Apple Developer Program 가입을 마치고 Team ID를 확인합니다. 약관·결제는 계정 소유자가 직접 진행합니다.
2. `Config/Signing.xcconfig`에서 `DEVELOPMENT_TEAM`과 본인 소유의 고유한 `HANJU_BUNDLE_ID`를 설정합니다. `com.example.hanjustack`은 예시이므로 그대로 제출할 수 없습니다.
3. 앱 ID와 `.widget` 확장 ID를 등록하고 같은 App Group을 두 타깃에 연결합니다. `HANJU_APP_GROUP`과 실제 등록한 그룹 ID가 같아야 합니다. Xcode에서 Signing & Capabilities를 확인합니다.
4. 전체 Xcode와 XcodeGen이 설치된 Mac에서 `./scripts/check.sh`, `./build.sh`를 실행합니다. Apple 계정은 Xcode Settings에 추가합니다.
5. `./scripts/archive.sh`로 Universal archive를 만듭니다. Xcode Organizer에서 Validate App을 실행하고 서명·프로비저닝·위젯 포함 여부를 확인합니다.
6. TestFlight로 앱과 위젯의 실제 저장·동시 수정·재실행·샌드박스 가져오기/내보내기를 검사합니다. 소스 검사만으로 이 항목들을 검증한 것으로 간주하지 않습니다.
7. App Store Connect에 앱을 등록하고 스크린샷·설명·지원 URL·공개 개인정보 처리방침 URL·연령 등급·개인정보 응답을 입력합니다. 유료 계약/세금/은행 정보는 계정 소유자가 처리합니다.
8. 일회성 유료 앱 가격은 App Store Connect에서 설정합니다. US$2.99는 제안 가격이며 코드에서 결제하거나 실제 가격을 설정하지 않습니다. 현재 기능을 위한 구독/IAP는 없습니다.

## 공유 저장

앱과 위젯은 `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)`가 반환하는 같은 컨테이너의 `state.json`을 사용합니다. 다른 앱의 `Library/Containers` 경로를 직접 읽거나 쓰지 않습니다. 공유 저장소가 없으면 앱은 명확한 오류를 표시하고 종료합니다. 위젯을 별도 파일로 조용히 저장하는 폴백은 없습니다.

파일 조정과 `_revision`으로 쓰기를 직렬화합니다. 위젯 수정 후 오래된 앱 화면이 저장되면 그 저장을 거절하고 최신 상태를 불러옵니다. 앱 안의 빠른 연속 수정은 저장 응답 뒤에 모아서 저장합니다. 충돌 때 자동 합성을 시도하지 않으므로 사용자는 해당 편집을 다시 해야 합니다.

## 기존 개인용 설치에서 이동

기존 개인용 앱에서 저장 파일을 백업한 다음, 새 앱의 **계획 가져오기…**로 해당 JSON을 선택합니다. 파일 선택은 App Sandbox의 사용자 선택 권한으로 처리합니다. 이전 설치의 앱 지원 폴더를 몰래 읽거나 임시 예외 권한을 추가하지 않습니다.

- 이전 앱 파일: `~/Library/Application Support/HanjuStack/state.json`
- 이전 위젯 파일: `~/Library/Containers/local.hanju.stack.widget/Data/Documents/state.json`

기존 앱과 위젯은 별도 파일이었으므로, 필요한 쪽 파일을 확인하고 선택하세요. 가져오기 전에 현재 공유 계획은 `before-import-<UUID>.json`으로 공유 컨테이너에 백업됩니다. 메뉴의 **계획 백업 내보내기…**로 사용자 폴더에 복사할 수 있습니다. v2/v3 저장은 기존 시각과 길이를 보존하며 v4로 변환됩니다. 신버전의 앱과 위젯을 함께 설치하세요.

## 개인정보

현재 앱은 계정·분석 SDK·광고·네트워크 전송이 없습니다. 계획은 사용자 Mac의 공유 컨테이너와 사용자가 내보낸 백업에 저장됩니다. 앱의 PrivacyInfo에는 앱 설정(UserDefaults)과 애니메이션 경과시간(systemUptime)의 사용 이유를 기재했습니다. 위젯은 별도 PrivacyInfo를 포함합니다. 기능/SDK를 추가하면 개인정보 처리방침·manifest·App Store 응답도 함께 재검토하세요.

공개 개인정보 처리방침은 `PRIVACY.md`의 내용을 기준으로 소유자의 연락처와 공개 웹 URL을 준비하세요. 개발자 계정이나 프로비저닝 프로파일, 인증서 및 키는 저장소에 올리지 마세요.

Apple 참고:
- https://developer.apple.com/documentation/xcode/configuring-app-groups
- https://developer.apple.com/documentation/security/app-sandbox
- https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api
- https://developer.apple.com/help/app-store-connect/manage-app-pricing/set-a-price
