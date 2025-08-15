-- Enable pgcrypto for gen_random_uuid if not already
create extension if not exists pgcrypto;

-- 1) Tables
create table if not exists public.spellquest_albums (
  id uuid primary key default gen_random_uuid(),
  album_id text not null unique,
  title text not null,
  difficulty int not null default 1,
  is_official boolean not null default true,
  order_index int not null default 0,
  published_at timestamptz null,
  tags text[] null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.spellquest_puzzles (
  id uuid primary key default gen_random_uuid(),
  puzzle_id text not null unique,
  album_id uuid not null references public.spellquest_albums(id) on delete cascade,
  word text not null,
  display_title text null,
  image_path text not null,
  difficulty int not null default 1,
  order_index int not null default 0,
  is_official boolean not null default true,
  published_at timestamptz null,
  tags text[] null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 2) updated_at trigger
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end; $$;

drop trigger if exists set_updated_at_spellquest_albums on public.spellquest_albums;
create trigger set_updated_at_spellquest_albums
before update on public.spellquest_albums
for each row execute function public.set_updated_at();

drop trigger if exists set_updated_at_spellquest_puzzles on public.spellquest_puzzles;
create trigger set_updated_at_spellquest_puzzles
before update on public.spellquest_puzzles
for each row execute function public.set_updated_at();

-- 3) Indexes
create index if not exists idx_spellquest_albums_pub_order
  on public.spellquest_albums (is_official, published_at, order_index);

create index if not exists idx_spellquest_puzzles_album_order
  on public.spellquest_puzzles (album_id, order_index);

create index if not exists idx_spellquest_puzzles_pub_difficulty
  on public.spellquest_puzzles (is_official, published_at, difficulty);

-- 4) RLS
alter table public.spellquest_albums enable row level security;
alter table public.spellquest_puzzles enable row level security;

drop policy if exists "read_published_albums" on public.spellquest_albums;
create policy "read_published_albums"
  on public.spellquest_albums
  for select
  using (is_official = true and published_at is not null);

drop policy if exists "read_published_puzzles" on public.spellquest_puzzles;
create policy "read_published_puzzles"
  on public.spellquest_puzzles
  for select
  using (is_official = true and published_at is not null);

-- 5) Storage bucket with public read
insert into storage.buckets (id, name, public)
values ('spellquest-images', 'spellquest-images', true)
on conflict (id) do nothing;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects' and policyname = 'public_read_spellquest_images'
  ) then
    create policy "public_read_spellquest_images"
      on storage.objects
      for select
      using (bucket_id = 'spellquest-images');
  end if;
end $$;