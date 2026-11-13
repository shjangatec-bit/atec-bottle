-- =========================================================
-- 유리병 편지 : Supabase 초기 설정
-- 사용법: Supabase 대시보드 > SQL Editor 에 전체 붙여넣고 Run
-- 맨 아래 '담당자 이메일' 부분만 실제 이메일로 바꿔서 실행하세요.
-- =========================================================

create extension if not exists pgcrypto with schema extensions;

-- 1. 편지 테이블 ------------------------------------------------
create table if not exists public.bottles (
  id          bigint generated always as identity primary key,
  code        text not null unique,                       -- 병 번호 (예: K7M2-Q9XA)
  body        text not null check (char_length(body) between 5 and 1000),
  created_on  date not null default ((now() at time zone 'Asia/Seoul')::date),  -- 날짜만 저장
  status      text not null default 'pending'
              check (status in ('pending','posted','private','grievance')),
  category    text check (category in ('근무환경','복지','업무 개선','질문','기타')),
  reply       text,
  result      text check (result in ('done','plan','no')),
  replied_on  date
);

-- 2. 담당자(관리자) 명단 ------------------------------------------
create table if not exists public.admins (
  email text primary key
);

alter table public.bottles enable row level security;
alter table public.admins  enable row level security;

-- 직원(비로그인)은 테이블에 직접 접근할 수 없고, 아래 함수로만 접근합니다.
revoke all on public.bottles from anon;
revoke all on public.admins  from anon, authenticated;
grant select, update on public.bottles to authenticated;  -- 실제 허용 범위는 아래 정책(관리자만)으로 제한

-- 3. 관리자 확인 함수 ---------------------------------------------
create or replace function public.is_admin()
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.admins
    where email = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$$;

-- 관리자만 전체 조회·수정 가능
drop policy if exists "admin_select" on public.bottles;
drop policy if exists "admin_update" on public.bottles;
create policy "admin_select" on public.bottles
  for select to authenticated using (public.is_admin());
create policy "admin_update" on public.bottles
  for update to authenticated using (public.is_admin()) with check (public.is_admin());

-- 4. 편지 띄우기 (직원용) ------------------------------------------
--    작성자 정보는 받지 않고, 추측할 수 없는 병 번호를 돌려줍니다.
create or replace function public.submit_bottle(p_body text)
returns text
language plpgsql security definer
set search_path = public, extensions
as $$
declare
  v_alpha text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';  -- 헷갈리는 글자(0,O,1,I,L) 제외
  v_bytes bytea;
  v_code  text;
  i int;
begin
  p_body := btrim(coalesce(p_body, ''));
  if char_length(p_body) < 5 or char_length(p_body) > 1000 then
    raise exception '내용은 5자 이상 1000자 이하로 적어 주세요.';
  end if;

  loop
    v_bytes := gen_random_bytes(8);
    v_code  := '';
    for i in 0..7 loop
      v_code := v_code || substr(v_alpha, (get_byte(v_bytes, i) % 31) + 1, 1);
      if i = 3 then v_code := v_code || '-'; end if;
    end loop;
    exit when not exists (select 1 from public.bottles where code = v_code);
  end loop;

  insert into public.bottles (code, body) values (v_code, p_body);
  return v_code;
end;
$$;

-- 5. 해변 게시판 (직원용) : 게시된 편지만 -----------------------------
create or replace function public.get_board()
returns table (category text, body text, created_on date,
               reply text, result text, replied_on date)
language sql stable security definer
set search_path = public
as $$
  select category, body, created_on, reply, result, replied_on
  from public.bottles
  where status = 'posted'
  order by created_on desc, id desc
  limit 200;
$$;

-- 6. 게시판 숫자 (직원용) ------------------------------------------
create or replace function public.get_stats()
returns json
language sql stable security definer
set search_path = public
as $$
  select json_build_object(
    'sent',    count(*),
    'posted',  count(*) filter (where status = 'posted'),
    'private', count(*) filter (where status in ('private','grievance')),
    'pending', count(*) filter (where status = 'pending')
  )
  from public.bottles;
$$;

-- 7. 내 병 찾기 (직원용) : 병 번호를 아는 사람만 ----------------------
create or replace function public.find_bottle(p_code text)
returns table (status text, category text, body text, created_on date,
               reply text, result text, replied_on date)
language sql stable security definer
set search_path = public
as $$
  select status, category, body, created_on,
         case when status in ('posted','private') then reply end,
         case when status = 'posted' then result end,
         replied_on
  from public.bottles
  where code = upper(btrim(p_code));
$$;

-- 8. 실행 권한 ----------------------------------------------------
revoke all on function public.submit_bottle(text) from public;
revoke all on function public.get_board()         from public;
revoke all on function public.get_stats()         from public;
revoke all on function public.find_bottle(text)   from public;
revoke all on function public.is_admin()          from public;

grant execute on function public.submit_bottle(text) to anon, authenticated;
grant execute on function public.get_board()         to anon, authenticated;
grant execute on function public.get_stats()         to anon, authenticated;
grant execute on function public.find_bottle(text)   to anon, authenticated;
grant execute on function public.is_admin()          to authenticated;

-- 9. 담당자 등록 : 아래 이메일을 실제 담당자 이메일로 바꾸세요 -------------
--    (Authentication > Users 에서 같은 이메일로 사용자를 먼저 만들어 두세요)
insert into public.admins (email) values (lower('담당자이메일@ateccomputer.kr'))
on conflict do nothing;
