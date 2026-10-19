# Provenance / 구현 출처

## Scope

This is a source-only separation of the independently named HingeVeil development project. Legacy project folders, comparison checkouts, archived apps, diagnostic history and user videos were not copied. The development record states that the independent implementation was based on behavior requirements and Apple SDK APIs rather than copying the earlier app's source.

The authoring agent had previously viewed earlier app code. This record therefore does not establish strict clean-room independence, non-infringement, exclusive rights or legal clearance. Source and visual similarity, redistribution rights and trademark availability require final human/legal review before publication.

## 구성과 출처

힌지베일 독립 개발 폴더의 소스·테스트·문서·백호 그림만 분리했습니다. 이전 앱·비교 저장소·앱 백업·개인 진단 이력·사용자 영상은 복사하지 않았습니다. 개발 기록은 사용자 동작 요구와 Apple SDK API를 기준으로 독립 구현했다고 명시합니다.

작성 에이전트는 이전 앱 코드를 열람한 이력이 있습니다. 따라서 엄격한 클린룸 개발·비침해·독점 권리·법적 검토 완료를 주장하지 않습니다. 공개 전에 코드·시각 표현의 유사성, 재배포 권한과 상표를 별도 검토해야 합니다.

| Component | Basis / 작성 근거 |
| --- | --- |
| VeilMotion, EffectGate | Bounded projection, soft aperture, smoothing and safety requirements / 제한 보정·윤곽·보간·안전 사양 |
| Metal renderer/shader | Apple MetalKit/CoreVideo APIs and independently written passes / Apple API와 자체 합성·블러 패스 |
| DesktopCapture | Apple ScreenCaptureKit API; no audio/microphone output configured |
| HingeSensor | Observed HID descriptor and IOKit API; keyboard/mouse devices excluded |
| SafetyGuard | Parent-verified POSIX pipe/process watchdog and Carbon global shortcut |
| UI/logo | AppKit-drawn logo and new bilingual UI text |
| White tiger | Newly AI-generated and edited illustration; not an actual child's drawing or a competitor asset |

## White tiger / 백호 그림

- File: Sources/HingeVeil/Resources/PreviewTiger.png
- Dimensions: 1586×992; generation date recorded as 2026-10-10.
- SHA-256: 0256ec5af53df27b820d3b774ddc73512e51e0c78d092c4faabd3f04be66d416
- Created with the built-in image generation tool. An original orange crayon tiger was generated without external references, then that generated draft was edited into a roaring white tiger.
- Final brief: one brave white tiger roaring on clean rectangular white paper; black stripes, uneven fangs and red mouth; substantially crooked, scratchy, asymmetrical elementary-school crayon style; no other scenery, lettering, signature, frame or watermark.
- This provenance is not a guarantee of copyright eligibility, exclusivity, third-party clearance or commercial asset rights.

내장 이미지 생성 도구로 외부 참조 없이 초안을 생성한 뒤 그 자체 초안을 백호로 수정했습니다. 기존 그림 파일을 변형 없이 포함했습니다. AI 생성물의 저작권 성립·독점성·제3자 권리·상업 이용 조건에 대한 보장은 아닙니다.

## Reference APIs

- https://developer.apple.com/documentation/screencapturekit
- https://developer.apple.com/documentation/metalkit
- Xcode IOKit HID SDK headers and local descriptor observations.
- System frameworks, SDKs and fonts are not redistributed as source assets here.

## Publication decision

On 2026-10-18 the owner explicitly selected MIT and the credit bsl lab. See LICENSE and LICENSE-STATUS.md. Contribution guidance is in CONTRIBUTING.md. The choice records the owner's intended grant; it does not itself establish third-party rights clearance. The development bundle identifier remains unchanged, and no public repository or binary release was created by this work.

2026-10-18 사용자가 MIT와 bsl lab 표기를 선택했습니다. LICENSE에 반영했으며 기여 안내도 추가했습니다. 선택 기록만으로 제3자 권리 검토가 완료되는 것은 아닙니다. 개발용 앱 식별자를 유지하며 실제 공개·실행파일 배포는 아직 하지 않았습니다.
