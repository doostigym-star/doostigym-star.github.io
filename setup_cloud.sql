-- باشگاه دوستی: ساختار پایگاه داده ابری و دسترسی امن مدیران
-- این فایل را یک‌بار در Supabase > SQL Editor اجرا کنید.

create table if not exists public.gym_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.gym_admins enable row level security;

create or replace function public.is_gym_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.gym_admins
    where user_id = (select auth.uid())
  );
$$;

revoke all on function public.is_gym_admin() from public;
grant execute on function public.is_gym_admin() to authenticated;

create table if not exists public.gym_state (
  id text primary key default 'main' check (id = 'main'),
  members jsonb not null default '[]'::jsonb,
  rent numeric not null default 0 check (rent >= 0),
  updated_at timestamptz not null default now()
);

alter table public.gym_state enable row level security;

drop policy if exists "gym admins can read state" on public.gym_state;
drop policy if exists "gym admins can insert state" on public.gym_state;
drop policy if exists "gym admins can update state" on public.gym_state;
drop policy if exists "gym admins can delete state" on public.gym_state;

create policy "gym admins can read state"
on public.gym_state for select to authenticated
using (public.is_gym_admin());

create policy "gym admins can insert state"
on public.gym_state for insert to authenticated
with check (public.is_gym_admin());

create policy "gym admins can update state"
on public.gym_state for update to authenticated
using (public.is_gym_admin())
with check (public.is_gym_admin());

create policy "gym admins can delete state"
on public.gym_state for delete to authenticated
using (public.is_gym_admin());

grant select, insert, update, delete on public.gym_state to authenticated;

-- افزودن gym_state به Realtime برای همگام‌سازی تغییرات بین دستگاه‌ها
-- اگر قبلاً عضو publication باشد، این بخش بدون خطا از آن عبور می‌کند.
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'gym_state'
  ) then
    alter publication supabase_realtime add table public.gym_state;
  end if;
end $$;
