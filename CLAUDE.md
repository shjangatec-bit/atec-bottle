# 유리병 편지 (atec-bottle)

에이텍컴퓨터 익명 소통 창구. 간담회에서 나온 익명게시판 건의를 '유리병 편지' 컨셉으로 만든 사이트.
직원이 이름 없이 편지를 써서 유리병에 담아 띄우면, 담당자(인사총무파트)가 읽고 게시·개별 답장·고충 이관 중 하나로 처리한다.

## 주소
- 직원용: https://shjangatec-bit.github.io/atec-bottle/
- 담당자용: https://shjangatec-bit.github.io/atec-bottle/admin.html (직원에게 공유하지 않음)
- 배포: `main` 브랜치에 push 하면 GitHub Pages가 1~2분 뒤 자동 반영 (Settings → Pages: main / root)

## 파일
| 파일 | 내용 |
| --- | --- |
| `index.html` | 직원 화면. 편지 쓰기 → 띄우기 연출 → 해변 게시판 → 내 병 찾기 |
| `admin.html` | 담당자 화면. 이메일·비밀번호 로그인, 검토 대기/처리 완료/전체 탭, 게시·개별 답장·고충 이관·되돌리기 |
| `config.js` | Supabase 주소와 **공개용(publishable) 키**, 공통 API 호출 함수. Secret/service_role 키는 절대 넣지 않는다 |
| `bottle_setup.sql` | Supabase 초기 설정(테이블, 권한, 함수). 이미 실행 완료 |
| `demo_data.sql` | 보고용 예시 편지 7건(병 번호 `DEMO-`, 본문 앞 `[예시]`). 맨 아래 줄로 예시만 삭제 |
| `img/` | 그림 파일(아래 참고) |

## Supabase
- 계정: shjang.atec1 조직의 `atec-bottle` 프로젝트 (Seoul, Free 플랜 → 7일 미사용 시 일시 정지됨)
- 테이블 `bottles`: code(병 번호), body, created_on(날짜만), status(pending/posted/private/grievance), category, reply, result(done/plan/no), replied_on
- 테이블 `admins`: 담당자 이메일 명단. 여기 있는 이메일만 담당자 화면 사용 가능
- 직원(비로그인)은 테이블에 직접 접근 불가. 함수로만 접근:
  - `submit_bottle(p_body)` → 무작위 병 번호(예: K7M2-Q9XA) 반환
  - `get_board()` → 게시된 편지만
  - `get_stats()` → 띄운 병/해변 도착/개별 전달/검토 중 숫자
  - `find_bottle(p_code)` → 그 번호의 상태와 답장
- 담당자: Supabase Auth 로그인 + `is_admin()` 확인, RLS로 select/update 허용
- Auth 설정에서 신규 가입은 꺼 둠. 담당자 추가는 Authentication → Users에서 만들고 `admins`에 이메일 추가
- 비밀번호 분실 시: 사용자를 지우고 같은 이메일로 다시 만들거나, SQL로 `encrypted_password` 갱신 (재설정 메일 화면은 없음)
- 전체 초기화: `truncate table public.bottles restart identity;` (되돌릴 수 없음)

## 운영 원칙 (화면 문구와 기능에 반영되어 있음)
- 안내문: "이름이나 계정 없이 접수됩니다. 편지에는 내용과 날짜만 남습니다." — Supabase 로그에 접속 정보가 남을 수 있어서 "접속 기록을 받지 않는다"는 표현은 쓰지 않는다. 사실과 다른 약속을 화면에 쓰지 않는다
- 특정 개인을 지목한 글은 게시하지 않고 고충처리 절차(고충처리위원)로 이관
- 게시 전 "원문에 특정인을 알아볼 수 있는 내용이 없는지" 확인 문구를 한 번 더 띄움
- 병 번호는 추측할 수 없는 8자리(헷갈리는 0,O,1,I,L 제외). 순번으로 바꾸지 말 것(남의 개별 답장이 보이게 됨)
- 직원이 쓰는 화면에는 분류 선택이 없다(담당자가 처리할 때 고름)
- 공감·댓글 기능은 넣지 않는다(특정인에 대한 동의 모으기 방지)

## 화면·디자인 결정 사항
- 수채화 톤. 글꼴: Gowun Batang(편지 본문), Gowun Dodum(UI)
- 편지 쓰기 배경: 휴대폰 `desk_v.webp`(세로), 컴퓨터 `desk_h.webp`(가로)
- 띄우기 연출(약 9초, '건너뛰기' 있음): 편지지가 말리며 병 등장 → 책상에서 바다(`sea.webp`)로 1.6초 겹쳐 전환 → 병이 물가에 내려와 눕고 잠겼다 떠오름 → 흔들리며 수평선으로 멀어짐 + 물결. Web Animations API 사용
- 연출은 기기의 '애니메이션 줄이기' 설정과 관계없이 **항상 켠다** (사용자 결정)
- 해변 게시판: 가로로 넓힌 그림 3조각 `board_top / board_mid(세로 반복) / board_bot`. 게시판 기둥 폭 `--B = max(min(560px, 84vw), 40.7vw)`, 전체 폭 `--W = B / 0.407`. 양옆 블러 없음
- 쪽지(직원 글)·답장(회사): 종이는 9-slice(`paper_note.webp`, `paper_reply.webp`, border-image)로 글 길이에 맞게 늘어나고, 집게(`clothespin.webp`)와 밀랍 봉인(`seal.webp`)은 작은 장식으로 따로 붙임
- 시도했다가 되돌린 것: 말린 모서리 장식(어색함), 게시판 배경 교체 1차안(기존이 나음). 다시 제안하지 말 것
- 원본 이미지(`note.webp`, `reply.webp`, `bottle.webp` 등)는 장식 추출용으로 남겨 둠

## 작업 방식
- 사용자: 인사총무파트 담당자. 쉬운 우리말로 짧게 설명, 바로 쓸 수 있는 결과를 선호
- 큰 변경은 먼저 캡처(스크린샷)로 보여 주고 확인받은 뒤 반영
- 이 작업 환경에서는 실제 Supabase에 접속이 안 될 수 있음 → Playwright로 Supabase 요청을 가짜 응답으로 바꿔 화면을 테스트하고, 실제 연결 확인은 사용자에게 요청
- 수정 후 `main`에 커밋·push → 사용자에게 "1~2분 뒤 새로고침" 안내
- 참고: 처음 보고용으로 만든 Claude 데모 링크(별도 페이지, 저장 안 됨)는 이 저장소와 별개이며 최신 연출이 반영되어 있지 않음
