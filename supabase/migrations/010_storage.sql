-- =============================================================================
-- 010_storage.sql
--
-- Supabase Storage buckets and their access policies.
--
-- -----------------------------------------------------------------------------
-- Why only one bucket is public
-- -----------------------------------------------------------------------------
-- `product-images` holds catalogue photography, which is marketing material.
-- Every other bucket holds customer identity documents, signed invoices,
-- insurance policies and expense receipts. A public bucket on Supabase means
-- anyone who guesses or obtains the URL can read the object forever, with no
-- authentication and no audit trail. For a customer's Aadhaar scan or a
-- financial document that is unacceptable, so those buckets are private and
-- reached only through short-lived signed URLs.
--
-- -----------------------------------------------------------------------------
-- Path convention
-- -----------------------------------------------------------------------------
-- Every object is stored as:
--
--     <showroom_id>/<entity_type>/<entity_id>/<filename>
--
-- The policies below match on `(storage.foldername(name))[1]`, the first path
-- segment, and test it against can_access_showroom(). That is what isolates
-- one showroom's documents from another's, so the convention is load-bearing
-- rather than cosmetic. `SupabaseConfig.storagePath()` on the client is the
-- only place that composes these paths.
-- =============================================================================

-- =============================================================================
-- Buckets
-- =============================================================================
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  -- Catalogue photography. Public: these images appear in a showroom's own
  -- marketing and there is nothing confidential about a picture of a bike.
  ('product-images', 'product-images', true, 26214400,
   array['image/jpeg', 'image/png', 'image/webp', 'image/heic']),

  ('showroom-assets', 'showroom-assets', true, 10485760,
   array['image/jpeg', 'image/png', 'image/webp', 'image/svg+xml']),

  -- Everything below is private.
  ('customer-documents', 'customer-documents', false, 10485760,
   array['image/jpeg', 'image/png', 'application/pdf']),

  ('vehicle-documents', 'vehicle-documents', false, 10485760,
   array['image/jpeg', 'image/png', 'application/pdf']),

  ('invoice-documents', 'invoice-documents', false, 10485760,
   array['application/pdf']),

  ('service-documents', 'service-documents', false, 10485760,
   array['image/jpeg', 'image/png', 'application/pdf']),

  ('insurance-documents', 'insurance-documents', false, 10485760,
   array['image/jpeg', 'image/png', 'application/pdf']),

  ('warranty-documents', 'warranty-documents', false, 10485760,
   array['image/jpeg', 'image/png', 'application/pdf']),

  ('expense-attachments', 'expense-attachments', false, 10485760,
   array['image/jpeg', 'image/png', 'application/pdf'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- =============================================================================
-- Policies
-- =============================================================================
do $$
declare
  v_policy record;
begin
  for v_policy in
    select policyname from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
  loop
    execute format(
      'drop policy if exists %I on storage.objects', v_policy.policyname
    );
  end loop;
end $$;

-- ---------------------------------------------------------- product images
-- Readable by anyone (the bucket is public anyway); writable only by someone
-- who may edit the catalogue.
create policy product_images_read on storage.objects
  for select
  using (bucket_id in ('product-images', 'showroom-assets'));

create policy product_images_write on storage.objects
  for insert to authenticated
  with check (
    bucket_id in ('product-images', 'showroom-assets')
    and public.has_permission('products', 'edit')
  );

create policy product_images_update on storage.objects
  for update to authenticated
  using (
    bucket_id in ('product-images', 'showroom-assets')
    and public.has_permission('products', 'edit')
  );

create policy product_images_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id in ('product-images', 'showroom-assets')
    and public.has_permission('products', 'delete')
  );

-- ------------------------------------------------------- private documents
-- Generated for each private bucket against the module that owns it, so the
-- permission required to read a document is the same one required to read the
-- record it belongs to.
do $$
declare
  v_map    record;
  v_buckets constant jsonb := jsonb_build_object(
    'customer-documents',  'customers',
    'vehicle-documents',   'vehicles',
    'invoice-documents',   'billing',
    'service-documents',   'service',
    'insurance-documents', 'insurance',
    'warranty-documents',  'warranty',
    'expense-attachments', 'expenses'
  );
begin
  for v_map in select key as bucket, value #>> '{}' as module
               from jsonb_each(v_buckets)
  loop
    -- Read. Two conditions, both required: the caller must hold the module's
    -- documents permission, AND the object must sit under a showroom they can
    -- reach. The first path segment carries that showroom id.
    execute format($f$
      create policy %1$I on storage.objects
        for select to authenticated
        using (
          bucket_id = %2$L
          and public.has_permission('documents', 'view')
          and public.has_permission(%3$L, 'view')
          and public.can_access_showroom(
                nullif((storage.foldername(name))[1], '')::uuid)
        )
    $f$, v_map.bucket || '_read', v_map.bucket, v_map.module);

    execute format($f$
      create policy %1$I on storage.objects
        for insert to authenticated
        with check (
          bucket_id = %2$L
          and public.has_permission('documents', 'upload')
          and public.can_access_showroom(
                nullif((storage.foldername(name))[1], '')::uuid)
        )
    $f$, v_map.bucket || '_write', v_map.bucket);

    -- Deleting a document that supports a financial record destroys evidence,
    -- so it needs the explicit documents.delete permission, which only
    -- administrators hold.
    execute format($f$
      create policy %1$I on storage.objects
        for delete to authenticated
        using (
          bucket_id = %2$L
          and public.has_permission('documents', 'delete')
          and public.can_access_showroom(
                nullif((storage.foldername(name))[1], '')::uuid)
        )
    $f$, v_map.bucket || '_delete', v_map.bucket);
  end loop;
end $$;

-- =============================================================================
-- Verification
-- =============================================================================
do $$
declare
  v_public_private text;
  v_policies int;
begin
  -- A private bucket accidentally marked public would expose every customer
  -- document to the internet. Worth failing the migration over.
  select string_agg(id, ', ') into v_public_private
  from storage.buckets
  where public = true
    and id not in ('product-images', 'showroom-assets');

  if v_public_private is not null then
    raise exception
      'These buckets hold confidential data but are marked public: %',
      v_public_private;
  end if;

  select count(*) into v_policies
  from pg_policies where schemaname = 'storage' and tablename = 'objects';

  raise notice
    'Storage: % buckets (2 public, 7 private), % object policies',
    (select count(*) from storage.buckets), v_policies;
end $$;
