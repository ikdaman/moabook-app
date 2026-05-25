#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=true

check() {
  local label="$1"
  local result="$2"
  if [ "$result" = "0" ]; then
    echo "✓ $label"
  else
    echo "✗ FAIL: $label"
    PASS=false
  fi
}

# 1. Android applicationId
grep -q 'applicationId = "project.side.ikdaman"' \
  "$ROOT/android/app/build.gradle.kts" 2>/dev/null
check "Android applicationId == project.side.ikdaman" "$?"

# 2. Android namespace
grep -q 'namespace = "project.side.ikdaman"' \
  "$ROOT/android/app/build.gradle.kts" 2>/dev/null
check "Android namespace == project.side.ikdaman" "$?"

# 3. Android versionCode > 22
VC=$(grep 'versionCode' "$ROOT/android/app/build.gradle.kts" | grep -o '[0-9]*' | head -1)
[ "${VC:-0}" -gt 22 ]
check "Android versionCode ($VC) > 22" "$?"

# 4. iOS bundle ID
grep -q 'PRODUCT_BUNDLE_IDENTIFIER = com.Ikdaman;' \
  "$ROOT/ios/Runner.xcodeproj/project.pbxproj" 2>/dev/null
check "iOS PRODUCT_BUNDLE_IDENTIFIER == com.Ikdaman" "$?"

# 5. project.side.moabook (flutter create 기본값) 잔재 없음
! grep -q 'project\.side\.moabook' \
  "$ROOT/android/app/build.gradle.kts" 2>/dev/null
check "No project.side.moabook remnants in build.gradle.kts" "$?"

if [ "$PASS" = "true" ]; then
  echo ""
  echo "All identity checks passed ✓"
  exit 0
else
  echo ""
  echo "Identity check FAILED ✗"
  exit 1
fi
