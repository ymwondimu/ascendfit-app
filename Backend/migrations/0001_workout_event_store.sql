create extension if not exists pgcrypto;

create table workout_plans (
    id uuid primary key default gen_random_uuid(),
    schema_version integer not null check (schema_version = 1),
    document jsonb not null,
    created_at timestamptz not null default now()
);

create table workout_sessions (
    id uuid primary key default gen_random_uuid(),
    workout_plan_id uuid not null references workout_plans(id),
    status text not null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table session_events (
    id uuid primary key default gen_random_uuid(),
    workout_session_id uuid not null references workout_sessions(id) on delete cascade,
    sequence_number bigint not null,
    kind text not null,
    payload jsonb not null,
    occurred_at timestamptz not null,
    unique (workout_session_id, sequence_number)
);

create index session_events_replay_order
    on session_events (workout_session_id, sequence_number);
