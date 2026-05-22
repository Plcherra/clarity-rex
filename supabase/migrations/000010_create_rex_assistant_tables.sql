create extension if not exists pgcrypto;

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text,
  timestamp timestamptz not null default now(),
  constraint conversations_user_id_id_uidx unique (user_id, id)
);

create index if not exists conversations_user_timestamp_idx
  on public.conversations (user_id, timestamp desc);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  conversation_id uuid not null,
  role text not null check (role in ('user', 'assistant')),
  content text not null,
  timestamp timestamptz not null default now(),
  constraint messages_user_id_id_uidx unique (user_id, id),
  constraint messages_conversation_user_fk
    foreign key (user_id, conversation_id)
    references public.conversations(user_id, id)
    on delete cascade
);

create index if not exists messages_user_conversation_timestamp_idx
  on public.messages (user_id, conversation_id, timestamp desc);

create table if not exists public.long_term_memory (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  memory_type text not null check (
    memory_type in ('fact', 'preference', 'event')
  ),
  content text not null,
  source_conversation_id uuid,
  source_message_id uuid,
  importance integer not null default 3 check (importance between 1 and 5),
  active boolean not null default true,
  superseded_by uuid,
  confidence numeric not null default 0.75 check (confidence between 0 and 1),
  correction_group text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_accessed_at timestamptz not null default now(),
  constraint long_term_memory_user_id_id_uidx unique (user_id, id),
  constraint long_term_memory_source_conversation_user_fk
    foreign key (user_id, source_conversation_id)
    references public.conversations(user_id, id)
    on delete set null (source_conversation_id),
  constraint long_term_memory_source_message_user_fk
    foreign key (user_id, source_message_id)
    references public.messages(user_id, id)
    on delete set null (source_message_id),
  constraint long_term_memory_superseded_by_user_fk
    foreign key (user_id, superseded_by)
    references public.long_term_memory(user_id, id)
    on delete set null (superseded_by)
);

create index if not exists long_term_memory_user_active_importance_idx
  on public.long_term_memory (
    user_id,
    active,
    importance desc,
    last_accessed_at desc
  );

create index if not exists long_term_memory_user_source_conversation_idx
  on public.long_term_memory (user_id, source_conversation_id);

create index if not exists long_term_memory_user_correction_group_idx
  on public.long_term_memory (user_id, correction_group)
  where correction_group is not null;

create table if not exists public.memory_corrections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  correction_type text not null check (
    correction_type in (
      'entity_name',
      'entity_relationship',
      'plan_detail',
      'rule_detail',
      'commitment_detail',
      'location',
      'preference',
      'other'
    )
  ),
  old_value text,
  new_value text not null,
  target_table text,
  target_id uuid,
  source_conversation_id uuid,
  source_message_id uuid,
  applied boolean not null default false,
  confidence numeric not null default 0.9 check (confidence between 0 and 1),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint memory_corrections_user_id_id_uidx unique (user_id, id),
  constraint memory_corrections_source_conversation_user_fk
    foreign key (user_id, source_conversation_id)
    references public.conversations(user_id, id)
    on delete set null (source_conversation_id),
  constraint memory_corrections_source_message_user_fk
    foreign key (user_id, source_message_id)
    references public.messages(user_id, id)
    on delete set null (source_message_id)
);

create index if not exists memory_corrections_user_target_idx
  on public.memory_corrections (user_id, target_table, target_id);

create index if not exists memory_corrections_user_created_idx
  on public.memory_corrections (user_id, created_at desc);

create table if not exists public.memory_candidates (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  candidate_type text not null check (
    candidate_type in (
      'long_term_memory',
      'entity',
      'entity_event',
      'personal_rule',
      'plan',
      'plan_milestone',
      'commitment',
      'correction',
      'archive',
      'merge'
    )
  ),
  payload jsonb not null,
  status text not null default 'pending' check (
    status in ('pending', 'approved', 'rejected', 'applied', 'failed')
  ),
  risk_level text not null default 'medium' check (
    risk_level in ('low', 'medium', 'high')
  ),
  decision jsonb,
  reason text,
  source_conversation_id uuid,
  source_message_id uuid,
  approved_by text,
  approved_at timestamptz,
  applied_at timestamptz,
  rejected_at timestamptz,
  applied_record_table text,
  applied_record_id uuid,
  verification jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint memory_candidates_user_id_id_uidx unique (user_id, id),
  constraint memory_candidates_source_conversation_user_fk
    foreign key (user_id, source_conversation_id)
    references public.conversations(user_id, id)
    on delete set null (source_conversation_id),
  constraint memory_candidates_source_message_user_fk
    foreign key (user_id, source_message_id)
    references public.messages(user_id, id)
    on delete set null (source_message_id)
);

create index if not exists memory_candidates_user_status_created_idx
  on public.memory_candidates (user_id, status, created_at desc);

create index if not exists memory_candidates_user_source_status_created_idx
  on public.memory_candidates (
    user_id,
    source_conversation_id,
    status,
    created_at desc
  );

create index if not exists memory_candidates_user_type_status_idx
  on public.memory_candidates (user_id, candidate_type, status);

create index if not exists memory_candidates_user_risk_status_idx
  on public.memory_candidates (user_id, risk_level, status);

create table if not exists public.entities (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  entity_type text not null check (
    entity_type in (
      'person',
      'place',
      'organization',
      'job',
      'project',
      'object',
      'topic',
      'other'
    )
  ),
  display_name text not null,
  normalized_name text not null,
  aliases text[] not null default '{}'::text[],
  relationship text,
  summary text,
  source_conversation_id uuid,
  source_message_id uuid,
  source_memory_id uuid,
  importance integer not null default 3 check (importance between 1 and 5),
  status text not null default 'active' check (
    status in ('active', 'inactive', 'archived')
  ),
  active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint entities_user_id_id_uidx unique (user_id, id),
  constraint entities_source_conversation_user_fk
    foreign key (user_id, source_conversation_id)
    references public.conversations(user_id, id)
    on delete set null (source_conversation_id),
  constraint entities_source_message_user_fk
    foreign key (user_id, source_message_id)
    references public.messages(user_id, id)
    on delete set null (source_message_id),
  constraint entities_source_memory_user_fk
    foreign key (user_id, source_memory_id)
    references public.long_term_memory(user_id, id)
    on delete set null (source_memory_id)
);

create unique index if not exists entities_user_active_normalized_name_uidx
  on public.entities (user_id, entity_type, normalized_name)
  where active = true;

create index if not exists entities_user_active_importance_idx
  on public.entities (user_id, active, importance desc, last_seen_at desc);

create index if not exists entities_user_source_conversation_idx
  on public.entities (user_id, source_conversation_id);

comment on column public.entities.metadata is
  'Entity normalization metadata. Supported keys include canonical_entity_id, alias_source, obsolete_aliases, obsolete_names, removed_wrong_aliases, and correction_confidence.';

create table if not exists public.entity_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  entity_id uuid not null,
  event_type text not null default 'note' check (
    event_type in (
      'note',
      'interaction',
      'relationship_update',
      'preference',
      'commitment',
      'conflict',
      'milestone',
      'other'
    )
  ),
  title text,
  content text not null,
  occurred_at timestamptz,
  source_conversation_id uuid,
  source_message_id uuid,
  source_memory_id uuid,
  importance integer not null default 3 check (importance between 1 and 5),
  active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint entity_events_user_id_id_uidx unique (user_id, id),
  constraint entity_events_entity_user_fk
    foreign key (user_id, entity_id)
    references public.entities(user_id, id)
    on delete cascade,
  constraint entity_events_source_conversation_user_fk
    foreign key (user_id, source_conversation_id)
    references public.conversations(user_id, id)
    on delete set null (source_conversation_id),
  constraint entity_events_source_message_user_fk
    foreign key (user_id, source_message_id)
    references public.messages(user_id, id)
    on delete set null (source_message_id),
  constraint entity_events_source_memory_user_fk
    foreign key (user_id, source_memory_id)
    references public.long_term_memory(user_id, id)
    on delete set null (source_memory_id)
);

create index if not exists entity_events_user_entity_created_idx
  on public.entity_events (user_id, entity_id, created_at desc);

create index if not exists entity_events_user_active_importance_idx
  on public.entity_events (user_id, active, importance desc, created_at desc);

create table if not exists public.personal_rules (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  rule_type text not null check (
    rule_type in (
      'finance',
      'transport',
      'food_delivery',
      'coffee',
      'rent',
      'health',
      'dating',
      'work',
      'immigration',
      'personal',
      'other'
    )
  ),
  title text not null,
  rule_text text not null,
  trigger_keywords text[] not null default '{}'::text[],
  enforcement_style text not null default 'gentle_direct' check (
    enforcement_style in ('gentle_direct', 'strict', 'reminder_only')
  ),
  source_conversation_id uuid,
  source_message_id uuid,
  source_memory_id uuid,
  priority integer not null default 3 check (priority between 1 and 5),
  status text not null default 'active' check (
    status in ('active', 'paused', 'broken', 'archived')
  ),
  active boolean not null default true,
  starts_at timestamptz,
  ends_at timestamptz,
  last_checked_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint personal_rules_user_id_id_uidx unique (user_id, id),
  constraint personal_rules_source_conversation_user_fk
    foreign key (user_id, source_conversation_id)
    references public.conversations(user_id, id)
    on delete set null (source_conversation_id),
  constraint personal_rules_source_message_user_fk
    foreign key (user_id, source_message_id)
    references public.messages(user_id, id)
    on delete set null (source_message_id),
  constraint personal_rules_source_memory_user_fk
    foreign key (user_id, source_memory_id)
    references public.long_term_memory(user_id, id)
    on delete set null (source_memory_id)
);

create index if not exists personal_rules_user_active_priority_idx
  on public.personal_rules (user_id, active, priority desc, updated_at desc);

create index if not exists personal_rules_user_rule_type_idx
  on public.personal_rules (user_id, rule_type, active);

create table if not exists public.plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  plan_type text not null check (
    plan_type in (
      'finance',
      'immigration',
      'career',
      'health',
      'dating',
      'housing',
      'creative',
      'personal',
      'other'
    )
  ),
  title text not null,
  description text,
  desired_outcome text,
  primary_entity_id uuid,
  source_conversation_id uuid,
  source_message_id uuid,
  source_memory_id uuid,
  priority integer not null default 3 check (priority between 1 and 5),
  status text not null default 'active' check (
    status in ('active', 'paused', 'completed', 'abandoned', 'archived')
  ),
  active boolean not null default true,
  start_date date,
  target_date date,
  completed_at timestamptz,
  last_reviewed_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint plans_user_id_id_uidx unique (user_id, id),
  constraint plans_primary_entity_user_fk
    foreign key (user_id, primary_entity_id)
    references public.entities(user_id, id)
    on delete set null (primary_entity_id),
  constraint plans_source_conversation_user_fk
    foreign key (user_id, source_conversation_id)
    references public.conversations(user_id, id)
    on delete set null (source_conversation_id),
  constraint plans_source_message_user_fk
    foreign key (user_id, source_message_id)
    references public.messages(user_id, id)
    on delete set null (source_message_id),
  constraint plans_source_memory_user_fk
    foreign key (user_id, source_memory_id)
    references public.long_term_memory(user_id, id)
    on delete set null (source_memory_id)
);

create index if not exists plans_user_active_priority_idx
  on public.plans (user_id, active, priority desc, updated_at desc);

create index if not exists plans_user_primary_entity_idx
  on public.plans (user_id, primary_entity_id);

create index if not exists plans_user_status_target_date_idx
  on public.plans (user_id, status, target_date);

create table if not exists public.plan_milestones (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  plan_id uuid not null,
  title text not null,
  description text,
  milestone_type text not null default 'checkpoint' check (
    milestone_type in ('goal', 'deadline', 'checkpoint', 'task', 'other')
  ),
  target_date date,
  completed_at timestamptz,
  source_conversation_id uuid,
  source_message_id uuid,
  source_memory_id uuid,
  priority integer not null default 3 check (priority between 1 and 5),
  status text not null default 'open' check (
    status in ('open', 'in_progress', 'completed', 'missed', 'canceled')
  ),
  active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint plan_milestones_user_id_id_uidx unique (user_id, id),
  constraint plan_milestones_plan_user_fk
    foreign key (user_id, plan_id)
    references public.plans(user_id, id)
    on delete cascade,
  constraint plan_milestones_source_conversation_user_fk
    foreign key (user_id, source_conversation_id)
    references public.conversations(user_id, id)
    on delete set null (source_conversation_id),
  constraint plan_milestones_source_message_user_fk
    foreign key (user_id, source_message_id)
    references public.messages(user_id, id)
    on delete set null (source_message_id),
  constraint plan_milestones_source_memory_user_fk
    foreign key (user_id, source_memory_id)
    references public.long_term_memory(user_id, id)
    on delete set null (source_memory_id)
);

create index if not exists plan_milestones_user_plan_target_idx
  on public.plan_milestones (user_id, plan_id, target_date);

create index if not exists plan_milestones_user_active_status_idx
  on public.plan_milestones (user_id, active, status, target_date);

create table if not exists public.commitments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  commitment_type text not null check (
    commitment_type in (
      'task',
      'habit',
      'promise',
      'money',
      'health',
      'relationship',
      'work',
      'immigration',
      'deadline',
      'other'
    )
  ),
  title text not null,
  commitment_text text not null,
  plan_id uuid,
  milestone_id uuid,
  entity_id uuid,
  source_conversation_id uuid,
  source_message_id uuid,
  source_memory_id uuid,
  priority integer not null default 3 check (priority between 1 and 5),
  status text not null default 'open' check (
    status in (
      'open',
      'in_progress',
      'completed',
      'missed',
      'canceled',
      'archived'
    )
  ),
  active boolean not null default true,
  due_at timestamptz,
  completed_at timestamptz,
  last_checked_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint commitments_user_id_id_uidx unique (user_id, id),
  constraint commitments_plan_user_fk
    foreign key (user_id, plan_id)
    references public.plans(user_id, id)
    on delete set null (plan_id),
  constraint commitments_milestone_user_fk
    foreign key (user_id, milestone_id)
    references public.plan_milestones(user_id, id)
    on delete set null (milestone_id),
  constraint commitments_entity_user_fk
    foreign key (user_id, entity_id)
    references public.entities(user_id, id)
    on delete set null (entity_id),
  constraint commitments_source_conversation_user_fk
    foreign key (user_id, source_conversation_id)
    references public.conversations(user_id, id)
    on delete set null (source_conversation_id),
  constraint commitments_source_message_user_fk
    foreign key (user_id, source_message_id)
    references public.messages(user_id, id)
    on delete set null (source_message_id),
  constraint commitments_source_memory_user_fk
    foreign key (user_id, source_memory_id)
    references public.long_term_memory(user_id, id)
    on delete set null (source_memory_id)
);

create index if not exists commitments_user_active_due_idx
  on public.commitments (user_id, active, status, due_at);

create index if not exists commitments_user_plan_idx
  on public.commitments (user_id, plan_id);

create index if not exists commitments_user_milestone_idx
  on public.commitments (user_id, milestone_id);

create index if not exists commitments_user_entity_idx
  on public.commitments (user_id, entity_id);

create table if not exists public.voice_turns (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  conversation_id uuid not null,
  user_message_id uuid,
  assistant_message_id uuid,
  transcript_confidence numeric,
  audio_duration_seconds numeric,
  input_mime_type text,
  output_audio_encoding text,
  stt_vendor text not null default 'deepgram',
  tts_vendor text not null default 'google_tts',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint voice_turns_user_id_id_uidx unique (user_id, id),
  constraint voice_turns_conversation_user_fk
    foreign key (user_id, conversation_id)
    references public.conversations(user_id, id)
    on delete cascade,
  constraint voice_turns_user_message_user_fk
    foreign key (user_id, user_message_id)
    references public.messages(user_id, id)
    on delete set null (user_message_id),
  constraint voice_turns_assistant_message_user_fk
    foreign key (user_id, assistant_message_id)
    references public.messages(user_id, id)
    on delete set null (assistant_message_id)
);

create index if not exists voice_turns_user_conversation_created_idx
  on public.voice_turns (user_id, conversation_id, created_at desc);

drop trigger if exists set_long_term_memory_updated_at on public.long_term_memory;
create trigger set_long_term_memory_updated_at
before update on public.long_term_memory
for each row
execute function public.set_updated_at();

drop trigger if exists set_memory_candidates_updated_at on public.memory_candidates;
create trigger set_memory_candidates_updated_at
before update on public.memory_candidates
for each row
execute function public.set_updated_at();

drop trigger if exists set_entities_updated_at on public.entities;
create trigger set_entities_updated_at
before update on public.entities
for each row
execute function public.set_updated_at();

drop trigger if exists set_entity_events_updated_at on public.entity_events;
create trigger set_entity_events_updated_at
before update on public.entity_events
for each row
execute function public.set_updated_at();

drop trigger if exists set_personal_rules_updated_at on public.personal_rules;
create trigger set_personal_rules_updated_at
before update on public.personal_rules
for each row
execute function public.set_updated_at();

drop trigger if exists set_plans_updated_at on public.plans;
create trigger set_plans_updated_at
before update on public.plans
for each row
execute function public.set_updated_at();

drop trigger if exists set_plan_milestones_updated_at on public.plan_milestones;
create trigger set_plan_milestones_updated_at
before update on public.plan_milestones
for each row
execute function public.set_updated_at();

drop trigger if exists set_commitments_updated_at on public.commitments;
create trigger set_commitments_updated_at
before update on public.commitments
for each row
execute function public.set_updated_at();

alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.long_term_memory enable row level security;
alter table public.memory_corrections enable row level security;
alter table public.memory_candidates enable row level security;
alter table public.entities enable row level security;
alter table public.entity_events enable row level security;
alter table public.personal_rules enable row level security;
alter table public.plans enable row level security;
alter table public.plan_milestones enable row level security;
alter table public.commitments enable row level security;
alter table public.voice_turns enable row level security;

drop policy if exists "Users can manage their own assistant conversations"
  on public.conversations;
create policy "Users can manage their own assistant conversations"
on public.conversations
for all to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "Users can manage their own assistant messages"
  on public.messages;
create policy "Users can manage their own assistant messages"
on public.messages
for all to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "Users can manage their own long term memory"
  on public.long_term_memory;
create policy "Users can manage their own long term memory"
on public.long_term_memory
for all to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "Users can manage their own memory corrections"
  on public.memory_corrections;
create policy "Users can manage their own memory corrections"
on public.memory_corrections
for all to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "Users can manage their own memory candidates"
  on public.memory_candidates;
create policy "Users can manage their own memory candidates"
on public.memory_candidates
for all to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "Users can manage their own entities"
  on public.entities;
create policy "Users can manage their own entities"
on public.entities
for all to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "Users can manage their own entity events"
  on public.entity_events;
create policy "Users can manage their own entity events"
on public.entity_events
for all to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "Users can manage their own personal rules"
  on public.personal_rules;
create policy "Users can manage their own personal rules"
on public.personal_rules
for all to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "Users can manage their own plans"
  on public.plans;
create policy "Users can manage their own plans"
on public.plans
for all to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "Users can manage their own plan milestones"
  on public.plan_milestones;
create policy "Users can manage their own plan milestones"
on public.plan_milestones
for all to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "Users can manage their own commitments"
  on public.commitments;
create policy "Users can manage their own commitments"
on public.commitments
for all to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "Users can manage their own voice turns"
  on public.voice_turns;
create policy "Users can manage their own voice turns"
on public.voice_turns
for all to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
