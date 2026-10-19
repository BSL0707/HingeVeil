# Contributing / 기여 안내

Korean and English reports are welcome. Discuss major changes before implementation. Keep patches small and explain validation. Only submit material you have the right to contribute under the project's [MIT license](LICENSE); do not copy competitor code, screenshots or assets with unclear permission. No contributor agreement or copyright assignment is added by this document.

한국어·영어 제보를 받습니다. 큰 변경은 먼저 논의하고 작은 수정과 검증 결과를 제출해주세요. 프로젝트의 [MIT](LICENSE)로 기여할 권리가 있는 자료만 제출하세요. 경쟁사 코드·화면·권리 불명확한 그림을 복사하지 마세요. 이 문서는 별도 CLA나 저작권 양도 계약이 아닙니다.

## Checks

```sh
bash scripts/ci.sh
```

The command runs offline source/index/history checks, Python tests, Swift tests and the packaged build/resource checks. GitHub-hosted CI uses the same command, with a read-only token and no persisted credentials. It does not run real desktop capture, a lid sensor, GUI/GPU fixtures or releases. The first GitHub-hosted execution is still unverified until a repository is created.

Keep Korean and English localizations in sync. `Docs/Manual.<language>.md` must exactly match the corresponding bundled `Manual.<language>.txt`. Do not remove the emergency shortcut, watchdog, 15-second safety limit, stale-frame protection or capture permission checks. Motion/capture/render changes also need hardware and generated-window/GPU tests described in README.md; passing CI alone is insufficient.

한·영 번역과 문서/앱 내 설명서를 함께 수정하세요. 긴급키·감시 프로세스·15초 제한·오래된 프레임 차단·권한 검사를 제거하지 마세요. 효과 변경은 CI 외에 실제 장비와 그림/창/GPU 검사도 필요합니다.

## Reports and conduct

Use the bug/feature forms. Describe chip/model year/screen size and macOS version, not serial numbers. Sanitize diagnostic error text and screenshots before sharing. For security vulnerabilities, use [SECURITY.md](SECURITY.md), never public issue comments. Be respectful; no harassment, personal information or unrelated promotional posts. No response-time or compatibility guarantee is made.

기기 일련번호 대신 칩·연식·화면 크기·macOS 버전을 적어주세요. 진단 오류 문구와 화면에는 개인정보가 있을 수 있습니다. 보안 취약점은 공개 이슈가 아닌 비공개 제보 경로로 보내세요. 상호 존중하며 개인정보 공개·괴롭힘·무관한 광고는 하지 마세요.
