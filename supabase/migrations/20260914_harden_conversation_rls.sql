-- LAST CALL security hardening
-- Keeps conversation membership and message visibility scoped to the actual conversation.
-- The production migration was applied through Supabase on 2026-09-14.

drop policy if exists "members see membership" on public.conversation_members;
create policy "members see membership" on public.conversation_members for select using (
  conversation_members.user_id = auth.uid()
  or exists (
    select 1 from public.conversation_members viewer
    where viewer.conversation_id = conversation_members.conversation_id
      and viewer.user_id = auth.uid()
  )
);

drop policy if exists "users join conversations" on public.conversation_members;

drop policy if exists "members create conversations" on public.conversations;

drop policy if exists "members read messages" on public.messages;
create policy "members read messages" on public.messages for select using (
  exists (
    select 1 from public.conversation_members cm
    where cm.conversation_id = messages.conversation_id
      and cm.user_id = auth.uid()
      and cm.status in ('accepted','pending')
  )
);

drop policy if exists "members send messages" on public.messages;
create policy "members send messages" on public.messages for insert with check (
  messages.sender_id = auth.uid()
  and exists (
    select 1 from public.conversation_members cm
    where cm.conversation_id = messages.conversation_id
      and cm.user_id = auth.uid()
      and cm.status = 'accepted'
  )
  and not exists (
    select 1 from public.conversation_members blocked_target
    where blocked_target.conversation_id = messages.conversation_id
      and blocked_target.user_id <> auth.uid()
      and blocked_target.status = 'blocked'
  )
);

drop policy if exists "users mark messages read" on public.messages;

create or replace function public.mark_message_read(message_id uuid)
returns boolean language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'Not authenticated'; end if;
  update public.messages m
     set read_at = coalesce(m.read_at, now())
   where m.id = message_id
     and m.sender_id <> uid
     and exists (select 1 from public.conversation_members cm where cm.conversation_id=m.conversation_id and cm.user_id=uid and cm.status='accepted');
  return found;
end; $$;
revoke all on function public.mark_message_read(uuid) from public;
grant execute on function public.mark_message_read(uuid) to authenticated;

create or replace function public.protect_notification_update()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.user_id <> old.user_id
     or new.actor_id is distinct from old.actor_id
     or new.type <> old.type
     or new.story_id is distinct from old.story_id
     or new.conversation_id is distinct from old.conversation_id
     or new.created_at <> old.created_at then
    raise exception 'Only notification read state can be changed';
  end if;
  return new;
end; $$;

drop trigger if exists protect_notification_update on public.notifications;
create trigger protect_notification_update
before update on public.notifications
for each row execute function public.protect_notification_update();
