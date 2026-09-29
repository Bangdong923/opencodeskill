# OpenCode 스킬 키트

집(Claude Code)에서 쓰던 스킬 중 회사 OpenCode(codemate)에서 쓸 수 있는 것을 한 번에 설치하는 묶음.
핵심은 이미지를 볼 수 없는 모델로 HTML 디자인을 업그레이드하는 `design-upgrade`. Node 없이 Windows 기본 PowerShell만 쓴다.

**회사 PC에서 받아 설치하는 방법은 [회사-사용-가이드.md](회사-사용-가이드.md) 참고.**

## 들어 있는 스킬 (13개)
| 스킬 | 하는 일 | 출처·라이선스 |
|---|---|---|
| `design-upgrade` | 디자인 점검 → 시안 → 비교 페이지 (`/upgrade-design`, `/design-audit`) | 직접 제작 |
| `design-taste-frontend` | 프론트엔드 디자인 전반 기준 | Leonxlnx/taste-skill, MIT |
| `redesign-existing-projects` | 기존 페이지 점검·개선 | 〃 |
| `high-end-visual-design` | 부드럽고 고급스러운 방향 | 〃 |
| `minimalist-ui` | 에디토리얼 미니멀 방향 | 〃 |
| `industrial-brutalist-ui` | 브루탈리스트(스위스 타이포·터미널) 방향 | 〃 |
| `stitch-design-taste` | DESIGN.md 디자인 시스템 작성 | 〃 |
| `gpt-taste` | GSAP 스크롤 모션 중심 랜딩 | 〃 |
| `full-output-enforcement` | 코드 생략(`// ...`) 없이 끝까지 출력 | 〃 |
| `karpathy-guidelines` | 코딩 실수 줄이는 원칙 (최소 변경, 검증) | MIT |
| `prompt-master` | 다른 AI 도구용 프롬프트 작성 | nidhinjs/prompt-master, MIT |
| `grilling` | 계획·결정을 질문으로 검증 | mattpocock/skills, MIT |
| `skill-creator` | 새 스킬 만들기 (평가 스크립트는 Python 필요) | Anthropic, Apache 2.0 |

라이선스 원문은 `third-party/` 폴더와 각 스킬 폴더에 있다.

**뺀 것**: docx·pptx·xlsx·pdf (Anthropic 독점 라이선스 — 복사 반출 불가), hwpx·deep-research (라이선스 불명 / Claude 전용 도구 의존), brandkit·imagegen·image-to-code (이미지 생성 모델 필요), hyperframes 계열 (CLI·npm·인터넷 필요).

## 폴더 구성
| 경로 | 내용 |
|---|---|
| `skills/` | 위 13개 스킬 |
| `commands/` | `/upgrade-design`, `/design-audit` 명령어 |
| `example/sample.html` | 일부러 문제를 넣은 연습용 페이지 |
| `install.ps1` | 설치 스크립트 |

## 다른 스킬 쓰는 법
OpenCode는 요청 내용을 보고 알맞은 스킬을 알아서 불러온다. 확실히 쓰게 하려면 이름을 말하면 된다.
- "karpathy-guidelines 스킬 따라서 이 함수 고쳐줘"
- "grilling 스킬로 이 계획 검증해줘"
- "prompt-master로 사내 챗봇용 프롬프트 만들어줘"

## 설치 (회사 PC, 한 번만)
1. zip을 받았으면 **압축 풀기 전에** 파일 우클릭 → 속성 → 아래쪽 "차단 해제" 체크 → 확인 (보이지 않으면 건너뛰어도 됨)
2. 원하는 곳에 압축 풀기
3. 푼 폴더에서 주소창에 `powershell` 입력 → 엔터 → 아래 실행
   ```
   powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1
   ```
4. 마지막에 `OK (요약: 오류 4 · 경고 15)`가 보이면 성공
5. OpenCode를 다시 시작

설치 위치: `%USERPROFILE%\.config\opencode\skills`, `...\commands`
같은 이름이 이미 있으면 `backup-design-kit-날짜` 폴더로 옮겨 두고 설치한다.

## 사용
OpenCode에서 HTML이 있는 프로젝트 폴더를 열고:

```
/design-audit report.html
```
점검만. 문제 목록과 고칠 순서를 알려준다.

```
/upgrade-design report.html
/upgrade-design report.html 더 차분하고 고급스럽게
```
1. 원본 점검 → 2. DESIGN.md(없으면 방향별로 새로) → 3. 시안 `report-A.html`, `report-B.html` 제작 → 4. 시안마다 점검 오류 0까지 수정 → 5. `compare.html` 생성 후 멈춤

그다음 **compare.html을 브라우저로 직접 열어서** 보고 말로 고른다.
```
B안으로. 제목은 더 크게, 카드 테두리는 없애고, 모바일에서 버튼은 전체 폭으로
```
→ 반영 후 `report-final.html` 저장. 원본은 그대로 남는다.

## 잘 쓰는 요령
- **DESIGN.md를 한 번 잘 만들어 두는 게 제일 효과가 크다.** 회사 색·글꼴이 정해져 있으면 `skills/design-upgrade/templates/DESIGN.template.md`를 프로젝트 폴더에 `DESIGN.md`로 복사해서 ```tokens 블록 값만 고쳐 두면, 이후 모든 페이지가 같은 기준으로 만들어진다.
- 피드백은 "예쁘게"보다 "제목 더 크게 / 여백 넓게 / 색 줄여" 같이 구체적으로.
- 모델이 화면을 못 보므로, 비교 페이지 위쪽 **모바일 390** 버튼으로 모바일 모양은 꼭 직접 확인.

## 문제 해결
| 증상 | 해결 |
|---|---|
| 스크립트 실행이 막힘 ("실행할 수 없습니다", 정책 관련 메시지) | 회사 그룹 정책으로 PowerShell 스크립트가 막힌 경우. IT에 허용 여부 확인 필요 (우회하지 말 것) |
| `/upgrade-design`이 안 보임 | OpenCode 재시작. `%USERPROFILE%\.config\opencode\commands\`에 파일이 있는지 확인 |
| 스킬을 못 찾음 | `%USERPROFILE%\.config\opencode\skills\design-upgrade\SKILL.md`가 있는지 확인. OpenCode 설정 폴더가 다른 곳이면 `install.ps1 -Target "그 폴더"` |
| 한글이 깨져 보임 | 스크립트 파일을 메모장 등으로 다시 저장하지 말 것 (UTF-8 BOM 필요). zip에서 다시 설치 |

## 점검 스크립트가 보는 것
대비(4.5:1 / 큰 글자 3:1), viewport, @media, 고정 폭, max-width, 누르는 영역 44px, :focus, reduced-motion, img alt, 글꼴 수, 글자 크기·여백·모서리·색의 DESIGN.md 토큰 일치, line-height, !important·인라인 스타일 수.
못 보는 것: 부모 요소·그라데이션·이미지 위 글자의 대비, 외부 CSS, JS로 넣는 스타일, "예쁜지". 마지막은 사람이 본다.
