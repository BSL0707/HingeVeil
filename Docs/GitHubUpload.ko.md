# GitHub 업로드 가이드

[English](GitHubUpload.en.md) · [README](../README.ko.md)

대상: HingeVeil 0.1.11 소스 · 공개 표기: **bsl lab** · [MIT](../LICENSE).

이 문서는 업로드 순서입니다. 준비 작업 자체는 저장소 생성·커밋·업로드·공개 전환을 실행하지 않습니다. Apple Developer 가입·유료 서명·공증은 이번 소스 업로드 범위에서 제외합니다. 실행파일 배포와 소스 공개는 별도입니다.

## 1. 이 폴더만 사용

제공된 GitHub용 ZIP을 풀어 나온 `HingeVeil` 폴더를 사용하세요. ZIP 한 개만 GitHub에 올리는 것이 아니라, 압축을 푼 소스와 숨김 `.github`·`.gitignore` 파일을 함께 올립니다. Finder의 숨김 파일 표시는 Command+Shift+마침표로 바꿀 수 있습니다.

부모 개발 폴더 전체·옛 macTilt·비교 저장소·실제 화면 영상·백업·진단 파일·`.build`·`Build`는 올리지 마세요. 공개 ZIP에는 실행 앱·인증서·이전 Git 이력이 들어 있지 않습니다. 원래 작동 중인 앱도 교체하지 않습니다.

## 2. 업로드 전 로컬 확인

터미널의 현재 위치가 **분리된 HingeVeil 폴더**인지 먼저 확인하고 실행합니다.

```sh
pwd
bash scripts/ci.sh
```

전체 Xcode와 Python 3.10 이상이 필요합니다. 로컬 빌드의 ad-hoc 임시 서명은 유료 인증서나 Apple 계정을 사용하지 않습니다. 자동 검사는 센서·실제 화면 캡처·시스템 권한 초기화를 시작하지 않습니다. GPU·덮개 실물 테스트는 별도입니다.

## 3. 새 Git 저장소 준비

GitHub에서 이름 `HingeVeil`의 **빈 저장소**를 만듭니다. 처음에는 비공개로 파일 구성을 확인하는 것을 권장합니다. README·LICENSE·.gitignore 자동 생성은 선택하지 마세요. 이미 파일을 준비했습니다. 로컬 명령의 `OWNER`는 실제 GitHub 계정/조직명으로 바꿉니다. 아래는 안내용이며 자동 실행하지 않습니다.

커밋에는 작성자 이메일이 기록됩니다. GitHub 이메일 설정에서 본인의 no-reply 주소를 확인하고, 아래 자리표시자를 그 주소로 바꾸세요. 실명이나 개인 이메일을 원치 않으면 공개하지 마세요. 토큰·비밀번호를 원격 URL에 넣지 마세요.

```sh
git init -b main
git config --local user.name "bsl lab"
git config --local user.email "YOUR_GITHUB_NOREPLY_ADDRESS"
git config --local core.logAllRefUpdates true
git add --dry-run .
git add .
python3 scripts/check_git_history.py
git diff --cached --stat
git commit -m "Prepare HingeVeil 0.1.11 source"
python3 scripts/check_git_history.py
git remote add origin https://github.com/OWNER/HingeVeil.git
git push -u origin main
```

기존 `.git`이나 원격 저장소가 있으면 위 초기화 순서를 다시 실행하지 말고 먼저 확인하세요. 검사에 걸리면 업로드를 멈춥니다. 민감정보를 삭제한 새 커밋만 추가해도 이전 커밋의 정보는 없어지지 않습니다. 실제 키가 노출됐으면 해당 서비스에서 폐기·교체가 우선이며 이 문서는 이력 강제 삭제를 자동 실행하지 않습니다.

`check_git_history.py`는 인덱스와 모든 참조에서 도달 가능한 커밋의 파일·커밋 메타데이터에 제한된 패턴 검사를 합니다. 값은 출력하지 않습니다. `.git`이 없으면 `not_initialized`로 표시하며 이력이 깨끗하다는 뜻은 아닙니다. 얕은 복제는 거부합니다. 도달 불가능한 객체·reflog·원격·Git LFS·서명/태그의 모든 정보까지 보증하지 않습니다.

## 4. 저장소에서 설정할 항목

- Actions의 `Source checks` 실행이 통과하는지 확인합니다. 로컬 검증 완료가 실제 GitHub CI 통과를 뜻하지는 않습니다. 비공개 저장소에서는 Actions 사용량·과금 설정도 확인하세요.
- 제공한 워크플로는 GitHub-hosted macOS에서 테스트·빌드만 합니다. 토큰은 읽기 전용, checkout 인증정보 미보관, 외부 액션 SHA 고정입니다. 배포·결제·앱 업로드는 하지 않습니다.
- 가능하면 `main`에 직접 강제 푸시를 막고, PR 및 `macOS source and build` 검사 통과를 요구합니다. 사용 가능한 보호 설정은 GitHub 요금제에 따라 확인하세요.
- 보안 기능에서 지원되는 secret scanning·push protection을 확인합니다. 로컬 패턴 검사만으로 대체하지 마세요.
- 공개 전 [출처/권리 검토](RightsReview.md)를 읽습니다. MIT 선택은 제3자 코드·이미지·상표 권리 확인을 대신하지 않습니다.
- 공개할 때 비공개 취약점 제보를 켭니다. 현재 공식 경로는 Settings → Security and quality → Advanced Security → Private vulnerability reporting입니다. 켠 뒤 Security → Advisories에 제보 버튼이 나타나는지 확인하세요. 실제 설정 전에는 제보 경로가 준비됐다고 홍보하지 마세요.
- 실제 계정의 no-reply 커밋 주소·저장소 소유자·공개할 이름을 마지막으로 확인합니다. `com.bsl0707.hingeveil.preview`는 개발용 앱 식별자이며 비밀키가 아닙니다. 유지한 채 소스를 올릴 수 있지만 정식 바이너리 발행 전에는 별도로 결정하세요.

## 5. 공개와 설치 앱 배포 구분

소스를 공개하면 다른 사람이 내려받아 복제·수정·상업 이용할 수 있습니다. MIT의 저작권/허락 고지 유지 조건을 확인하세요. 나중에 비공개로 돌려도 이미 받은 복사본까지 회수되지는 않습니다.

이번 ZIP은 **소스 전용**입니다. 설치파일, 유료 판매/라이선스 인증, 자동 업데이트 서버를 제공하는 패키지가 아닙니다. 모든 맥북 기종·Mission Control·잠금/잠자기 복귀·HDR·장시간 전력/메모리 검증 완료를 주장하지 마세요.

## 공식 참고 자료

2026-10-18 확인: [GitHub 라이선스 안내](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository), [비공개 취약점 제보](https://docs.github.com/en/code-security/how-tos/report-and-fix-vulnerabilities/configure-vulnerability-reporting/configure-for-a-repository), [GitHub-hosted runner](https://docs.github.com/en/actions/reference/runners/github-hosted-runners), [고정한 checkout v7.0.1](https://github.com/actions/checkout/tree/3d3c42e5aac5ba805825da76410c181273ba90b1).
