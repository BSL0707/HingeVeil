# Rights and provenance review / 권리·출처 점검

Date: 2026-10-18 · HingeVeil 0.1.11 · owner-selected credit: **bsl lab**.

This is a technical preparation record, not a legal opinion, title verification or non-infringement certificate. The owner selected MIT and bsl lab explicitly; this work does not verify the identity or legal capacity behind that credit.

기술적 준비 기록이며 법률 의견·권리자 신원 확인·비침해 증명서가 아닙니다. 사용자가 MIT와 bsl lab을 직접 선택했으며, 해당 표기 뒤의 법적 권리자 신원/권한을 검증한 것은 아닙니다.

## Code / 코드

- The allowlisted package contains the independently named HingeVeil project only. Earlier applications, comparison checkouts and their history are excluded.
- Local comparison examined 14 current Swift/Metal files against three existing local source sets (13, 7 and 14 files). There were no byte-identical whole files and no matching blocks of five or more consecutive filtered lines in that check.
- Filtering removed blank lines, import/include lines, line comments and lines shorter than 18 characters, and normalized whitespace. This is a narrow text comparison, not AST/semantic similarity analysis or a search of all external code. Shorter similarities and common Apple API boilerplate may exist.
- The authoring agent had previously viewed earlier app code. A clean comparison does not establish strict clean-room independence. Independent naming/rewording and MIT licensing do not cure copying of material the owner cannot license.
- Package.swift declares no third-party packages. Apple frameworks are called through SDK APIs and are not redistributed in the source ZIP. HID discovery is limited to the checked orientation-sensor descriptor; no keyboard/mouse keylogging is implemented in this source.

현재 Swift/Metal 14개 파일과 로컬에 있던 세 소스 집합을 비교한 범위에서는 통째로 같은 파일이나 위 필터 기준 5줄 이상 연속 일치 구간이 없었습니다. 의미/구조 유사성·외부 전체 코드 검색이 아니며 법률상 독립 구현을 증명하지 않습니다. 기존 코드 열람 이력을 숨기지 않습니다.

## Artwork and brand / 그림·브랜드

- The only raster source asset is PreviewTiger.png, an AI-generated white tiger. Its hash, dimensions and creation brief are recorded in PROVENANCE.md. The PNG was not replaced by a competitor image.
- The app/status logo is drawn in IconArtwork.swift using AppKit. It is not an imported competitor logo file.
- No competitor screenshot, user photograph or video is included. Included source artwork is covered by the selected MIT grant only to the extent licensable rights exist; no exclusive AI-image copyright is promised.
- No comprehensive Korean/global trademark, app-name, design-right or trade-dress search has been completed. HingeVeil and the logo are not represented as registered/cleared marks. If brand protection matters, arrange a jurisdiction-specific professional search before commercial promotion.

백호 생성 기록과 AppKit 로고 구현을 명시했습니다. 경쟁사 화면·사용자 사진·영상은 배포 소스에 넣지 않았습니다. AI 그림 독점 권리나 국내외 상표/디자인 가용성은 보장하지 않습니다.

## Owner decisions and remaining limits / 결정과 한계

- Completed: MIT selected, bsl lab credit, standard LICENSE, bilingual scope/provenance/security/contribution guidance.
- Still external to this technical preparation: final authority to license, third-party rights/trademark review, actual GitHub repository/CI/security settings and broader device/runtime testing.
- Apple Developer signing/notarization is explicitly outside this source-upload task, not an unfinished requirement for hosting source.

남은 외부 결정·검토를 완료한 것처럼 표시하지 마세요. 소스 공개 준비와 유료 앱 정식 출시 완료는 다릅니다.
