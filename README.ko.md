# HingeVeil · 힌지베일

[![설치파일 다운로드 / Download for macOS · v0.1.11 · Apple Silicon](Docs/Download.svg)](https://github.com/BSL0707/HingeVeil/releases/download/v0.1.11/HingeVeil-0.1.11-AppleSilicon.dmg)

[한국어 설치방법](#한국어-설치방법) · [English installation](README.md#english-installation) · [릴리스·SHA-256 확인](https://github.com/BSL0707/HingeVeil/releases/tag/v0.1.11)

macOS 14 이상 · Apple Silicon (arm64) · **공개 개발 미리보기**. 지원되는 내장 덮개 센서와 내장 화면이 있는 맥북용이며, 모든 기종의 호환을 보장하지 않습니다.

## 한국어 설치방법

1. 위 버튼으로 **DMG 설치파일**을 받습니다. `Source code (zip)`은 소스이며 설치파일이 아닙니다.
2. 기존 HingeVeil·다른 덮개 효과 앱을 종료합니다. DMG를 열고 **HingeVeil.app → Applications(응용 프로그램)** 으로 끌어 넣습니다. 디스크를 추출한 뒤 응용 프로그램 폴더의 HingeVeil을 실행합니다.
3. **화면 권한 확인**을 누르고 시스템 설정 → 개인정보 보호 및 보안 → **화면 및 시스템 오디오 녹음**에서 HingeVeil을 허용합니다. macOS에 따라 '화면 기록'으로 표시됩니다. 안내가 나오면 종료 및 다시 열기를 선택합니다.

**Apple Developer ID 서명·공증이 없는 임시 서명 개발판입니다.** macOS가 실행을 막을 수 있습니다. 출처와 파일을 확인하고 본인이 신뢰하는 경우에만 시스템이 제공하는 앱별 **확인 없이 열기**를 사용하세요. Gatekeeper·SIP를 끄거나 격리 속성을 지우지 마세요. [Apple 공식 안내](https://support.apple.com/ko-kr/102445)

[한글 설치·권한·탈출 상세 안내](https://github.com/BSL0707/HingeVeil/releases/download/v0.1.11/Install.ko.txt) · [English installation guide](https://github.com/BSL0707/HingeVeil/releases/download/v0.1.11/Install.en.txt) · [한글 사용설명서](Docs/Manual.ko.md) · [English manual](Docs/Manual.en.md)

기본 시작 각도 90°에서는 덮개를 93° 이상 충분히 연 뒤 내리세요. 화면이 가려지면 **효과 화면 클릭** 또는 **Control+Option+Command+Esc**로 즉시 해제합니다. 캡처까지 멈추려면 실제 덮개 효과를 끄거나 앱을 종료하세요.

## 앱 소개

[English](README.md) · [한국어 설명서](Docs/Manual.ko.md) · [English manual](Docs/Manual.en.md)

덮개 움직임에 맞춰 제한된 반대 방향 보정·부드러운 윤곽·블러를 표시하는 네이티브 macOS 개발 앱입니다. 눈 위치를 추적하지 않으며 화면의 공간상 물리적 고정을 보장하지 않습니다.

버전 0.1.11 · 제작 **bsl lab** · [MIT 라이선스](LICENSE).

소스와 설치 앱을 공개한 개발 미리보기 버전입니다. 모든 기종 호환이나 유료 출시 완료를 뜻하지 않습니다. [구현 출처·검토 한계](PROVENANCE.md)와 [라이선스 범위](LICENSE-STATUS.md)를 확인하세요.

## 언어와 동작

- 한 앱에서 시스템 설정 따름·한국어·English 선택. UI·메뉴·현재 상태·설명서가 즉시 바뀝니다.
- macOS 14 이상, arm64 빌드. 지원되는 내장 덮개 센서와 내장 화면이 필요합니다.
- 시작 85/90/95/100도·기본 90도. 블러 네 단계·기본 2단계.
- 일반 시작 약 0.18초·종료 약 0.24초. 패널상 세로 확대 상한 12%.
- 효과 시작부터 최대 15초 고정 안전 제한. 시작 각도보다 3도 이상 열면 다시 준비됩니다.
- 클릭·Control+Option+Command+Esc로 즉시 해제. 별도 감시는 작동 중 앱이 멈추면 약 3초 뒤 종료하도록 설계돼 있습니다.
- 백호 미리보기는 화면 권한 불필요. 실제 화면 테스트는 2초 표시 후 종료 전환.
- 모든 기종·미션 컨트롤·잠자기/잠금 복귀·HDR·장시간 메모리/전력 검증은 남아 있습니다.

## 개인정보와 화면 공유 표시

화면 프레임은 메모리에서 로컬 처리합니다. 화면 녹화 파일 저장기·화면 업로드·소리/마이크 캡처·분석 서버·계정·결제 서비스는 포함하지 않습니다. 실제 효과가 켜져 있으면 시작 지연을 줄이기 위해 화면 캡처 연결을 유지하므로 macOS 공유 표시가 남을 수 있습니다. 캡처까지 멈추려면 실제 효과를 끄거나 종료하세요. 진단 인수를 명시하면 숫자/상태 보고서나 자체 그림 PNG를 저장할 수 있으니 공개 전에 내용을 확인하세요. [보안·개인정보 안내](SECURITY.md)도 참고하세요.

## 빌드와 검증

전체 Xcode와 Swift·macOS SDK·Metal 컴파일러가 필요합니다. 외부 패키지 의존성은 선언하지 않았습니다. 빌드 스크립트는 해당 실행에만 툴체인을 지정하며 시스템 개발자 경로를 바꾸지 않습니다.

```sh
bash build.sh
Build/HingeVeil.app/Contents/MacOS/HingeVeil --check-localizations
Build/HingeVeil.app/Contents/MacOS/HingeVeil --self-check --previews
Build/HingeVeil.app/Contents/MacOS/HingeVeil --self-check --preview-artwork --previews
Build/HingeVeil.app/Contents/MacOS/HingeVeil --check-transitions --zero-alpha
Build/HingeVeil.app/Contents/MacOS/HingeVeil --check-guard
python3 scripts/audit_publication.py
python3 -m unittest discover -s scripts -p 'test_*.py'
```

비대화형 소스·테스트·빌드 전체 검사는 `bash scripts/ci.sh`로 실행합니다. GitHub 검사 설정은 고정된 checkout 버전·읽기 전용 권한·인증정보 미보관을 사용합니다. 바탕화면 캡처·앱 설치·릴리스 게시는 하지 않습니다. 현재 [GitHub Actions 결과](https://github.com/BSL0707/HingeVeil/actions/workflows/ci.yml)를 확인할 수 있습니다.

창/전환 검사는 실제 화면 대신 자체 그림을 잠깐 표시합니다. 센서·캡처·긴급키·감시·설정 저장 없이 언어별 UI만 검토하려면 다음을 사용합니다.

```sh
Build/HingeVeil.app/Contents/MacOS/HingeVeil --review-ui --language ko
Build/HingeVeil.app/Contents/MacOS/HingeVeil --review-ui --language en --review-manual
```

검토 모드는 45초 뒤 닫히며 실제 효과 조작은 비활성화됩니다. 일반 사용은 인수 없이 앱을 여세요. 이 후보는 임시 서명본으로 Developer ID 서명·공증본이 아닙니다. 재빌드하면 이 앱의 화면 권한을 다시 연결해야 할 수 있습니다. Gatekeeper·시스템 전체 보안 기능을 끄지 마세요.

## 소스 공개 준비

부모 프로젝트·비교 자료·백업·실제 영상·진단·캐시·빌드 산출물·서명 키·인증정보를 공개 패키지에 넣지 마세요. 내보내기 스크립트는 허용 목록만 점검·패키징하며 업로드는 하지 않습니다. 자동 검사는 휴리스틱으로 비밀정보·취약점·권리 문제가 없다는 보장이 아닙니다. [공개 준비 검토](Docs/PublicationReview.md), [구현 출처](PROVENANCE.md)를 확인하세요.

[업로드 순서](Docs/GitHubUpload.ko.md) · [기여 안내](CONTRIBUTING.md) · [보안 제보](SECURITY.md) · [변경 이력](CHANGELOG.md).

Apple Developer 가입·Developer ID 서명·공증은 이번 소스 업로드 작업에서 제외했습니다. 로컬 실행을 위한 임시 서명(ad-hoc)은 빌드에 남아 있으며 유료 인증서나 Apple 계정을 사용하지 않습니다.
