---
name: release-app
description: Use when the user asks to bump/release the moabook app version, "버전 올려줘", "배포해줘", "버전 올리고 푸시", "릴리즈" — bumps pubspec version, commits, pushes main, and pushes the three release tags.
---

# Release moabook App

## Overview

모아북(Flutter) 배포 자동화. "버전 올려줘 / 배포해줘" 요청 한 번이면:
pubspec 버전 범프 → 커밋 → main 푸시 → **태그 3종(`v*`, `android-v*`, `ios-v*`) 푸시**까지 끝낸다.

**핵심:** android/ios 스토어 파이프라인은 각각 `android-v*` / `ios-v*` 태그를 트리거로 동작한다. `v*` 하나만 푸시하면 배포가 안 걸린다. **세 태그를 항상 같이 푸시한다.**

## When to Use

- "앱 버전 올려줘", "배포해줘", "버전 올리고 커밋 푸시", "릴리즈해줘", "스토어 올려줘"
- 버그픽스/기능 머지 후 사용자가 배포 의사를 밝힐 때

## Steps

1. **현재 상태 확인**
   ```bash
   grep '^version:' pubspec.yaml
   git branch --show-current
   git status --short
   git tag --sort=-creatordate | head -12
   ```

2. **버전 결정 + 범프** — `pubspec.yaml`의 `version: X.Y.Z+N`.
   - 버그픽스 → patch (`Z`+1). 기능 → 사용자가 minor/major 지정 안 하면 patch 기본, 애매하면 물어본다.
   - 빌드넘버 `+N`은 **항상 +1**.
   - 예: `2.0.10+45` → `2.0.11+46`.

3. **변경분 커밋** — 작업 중이던 변경 + pubspec을 함께. swiftpm 등 내가 안 만든 untracked 파일은 스테이징하지 않는다(명시 요청 없으면).
   ```bash
   git add pubspec.yaml <변경 파일들>
   git commit -m "<type>: <설명> + vX.Y.Z"
   ```

4. **main 푸시**
   ```bash
   git push origin main
   ```

5. **태그 3종 생성 + 푸시 (필수, 빠뜨리지 말 것)**
   ```bash
   git tag vX.Y.Z android-vX.Y.Z ios-vX.Y.Z
   git push origin vX.Y.Z android-vX.Y.Z ios-vX.Y.Z
   ```

6. **보고** — 범프된 버전, 커밋 해시, 푸시된 태그 3개를 명시한다.

## Quick Reference

| 항목 | 값 |
|------|-----|
| 버전 파일 | `pubspec.yaml` → `version: X.Y.Z+N` |
| 빌드넘버 | 매 릴리즈 `+N` +1 |
| 공통 태그 | `vX.Y.Z` |
| Android 배포 태그 | `android-vX.Y.Z` |
| iOS 배포 태그 | `ios-vX.Y.Z` |
| 리모트 | `github-personal:ikdaman/moabook-app.git` (개인 계정) |

## Common Mistakes

- ❌ `v*` 태그만 푸시 → 스토어 배포 안 걸림. **항상 3종 푸시.**
- ❌ 빌드넘버 `+N` 안 올림 → 스토어가 같은 빌드 거부. **항상 +1.**
- ❌ swiftpm 등 무관한 untracked 파일 같이 커밋. 작업 변경분 + pubspec만.
- ❌ 기존 태그 네이밍 확인 안 하고 추측 → `git tag --sort=-creatordate`로 먼저 확인.
