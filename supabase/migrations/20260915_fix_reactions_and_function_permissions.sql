ALTER TABLE public.reactions DROP CONSTRAINT IF EXISTS reactions_kind_check;
ALTER TABLE public.reactions ADD CONSTRAINT reactions_kind_check CHECK (kind IN ('drink', 'beer'));

CREATE INDEX IF NOT EXISTS blocks_blocked_id_idx ON public.blocks(blocked_id);
CREATE INDEX IF NOT EXISTS comments_user_id_idx ON public.comments(user_id);
CREATE INDEX IF NOT EXISTS conversation_members_user_id_idx ON public.conversation_members(user_id);
CREATE INDEX IF NOT EXISTS follows_following_id_idx ON public.follows(following_id);
CREATE INDEX IF NOT EXISTS messages_sender_id_idx ON public.messages(sender_id);
CREATE INDEX IF NOT EXISTS notifications_actor_id_idx ON public.notifications(actor_id);
CREATE INDEX IF NOT EXISTS notifications_conversation_id_idx ON public.notifications(conversation_id);
CREATE INDEX IF NOT EXISTS notifications_story_id_idx ON public.notifications(story_id);
CREATE INDEX IF NOT EXISTS reactions_user_id_idx ON public.reactions(user_id);
CREATE INDEX IF NOT EXISTS reports_reported_user_id_idx ON public.reports(reported_user_id);
CREATE INDEX IF NOT EXISTS reports_reporter_id_idx ON public.reports(reporter_id);
CREATE INDEX IF NOT EXISTS reports_story_id_idx ON public.reports(story_id);
CREATE INDEX IF NOT EXISTS stories_author_id_idx ON public.stories(author_id);

REVOKE EXECUTE ON FUNCTION public.notify_story_engagement() FROM anon, authenticated;
