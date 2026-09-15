INSERT INTO storage.buckets (id, name, public)
VALUES ('profile-media', 'profile-media', true)
ON CONFLICT (id) DO UPDATE SET public = true;

CREATE POLICY "profile media public read"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'profile-media');

CREATE POLICY "users upload own profile media"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'profile-media'
  AND (storage.foldername(name))[1] = (select auth.uid())::text
);

CREATE POLICY "users delete own profile media"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'profile-media'
  AND (storage.foldername(name))[1] = (select auth.uid())::text
);
