---
description: HTML 디자인 점검만 실행 (파일은 수정하지 않음)
---
아래 명령을 실행해줘. 파일은 수정하지 마.

powershell -NoProfile -ExecutionPolicy Bypass -File "{{KIT_DIR}}/scripts/audit.ps1" -Path "$1"

결과를 한국어로 정리해줘:
1. 오류 → 경고 순서로, 항목마다 "무엇이 문제 / 어떻게 고치면 되는지" 한 줄씩
2. 가장 먼저 고칠 3가지
3. 고치고 싶으면 /upgrade-design $1 을 쓰라고 안내
