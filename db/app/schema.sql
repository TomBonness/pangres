create schema if not exists app;
create table if not exists app.guestbook (
  id         bigint generated always as identity primary key,
  author     text not null,
  body       text not null,
  created_at timestamptz not null default now()
);
