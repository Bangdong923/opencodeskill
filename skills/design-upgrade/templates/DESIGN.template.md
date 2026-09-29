# DESIGN — <프로젝트 이름>

방향: <한 줄. 예: 차분한 사내 리포트, 흰 바탕 + 남색 강조 1개, 여백으로 위계>

## 토큰 (audit.ps1이 이 블록을 읽는다 — 형식 유지)

```tokens
colors: #111827, #4b5563, #9ca3af, #e5e7eb, #f9fafb, #ffffff, #1d4ed8
font-sizes: 13, 15, 17, 20, 26, 34, 44
spacing: 4, 8, 12, 16, 24, 32, 48, 64, 96
radius: 8, 16, 999
fonts: Pretendard, Inter
```

## 역할
| 토큰 | 용도 |
|---|---|
| #111827 | 제목, 본문 글자 |
| #4b5563 | 보조 글자 (흰 바탕 대비 7:1) |
| #9ca3af | 비활성, 구분선 위 아이콘 — 본문 글자에 쓰지 않음 |
| #e5e7eb | 선, 테두리 |
| #f9fafb | 섹션 배경 |
| #ffffff | 페이지 배경, 카드 |
| #1d4ed8 | 강조(버튼, 링크, 핵심 숫자) — 한 화면에 1~2곳 |

## 글자
- 본문 17px / line-height 1.6 / 최대 폭 68ch
- 제목 line-height 1.2, 굵기 700. 보조 글자 13~15px
- 글꼴: 한글 Pretendard, 숫자·영문 Inter (없으면 system-ui)

## 레이아웃
- 콘텐츠 최대 폭 1120px, 좌우 여백 모바일 16px / 데스크톱 32px
- 섹션 간격 64~96px, 카드 안 여백 24px, 요소 간격 8~16px
- 모바일 1열 → 768px 이상 2열 → 1024px 이상 3열

## 요소
- 버튼: 높이 44px 이상, radius 999, 강조색 배경 + 흰 글자, hover 시 약간 어둡게, :focus-visible 테두리 2px
- 카드: 흰 바탕 + #e5e7eb 테두리 1px, 그림자는 쓰지 않거나 아주 약하게 1단계
- 움직임: 150~250ms ease-out, prefers-reduced-motion이면 끔
