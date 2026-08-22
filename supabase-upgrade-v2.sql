-- PRONOIA PRINT — actualización del panel autoadministrable
-- Ejecutar una sola vez desde Supabase > SQL Editor en el proyecto pronoia-print.

insert into public.site_settings (key, value)
values ('privacy', '{"data_collection_enabled":false,"business_name":"","privacy_email":"","privacy_notice_url":""}'::jsonb)
on conflict (key) do nothing;

drop policy if exists "public submit quote" on public.quote_requests;
create policy "public submit quote" on public.quote_requests for insert to anon with check (
  status = 'pendiente'
  and privacy_consent = true
  and privacy_consent_at is not null
  and exists (
    select 1 from public.site_settings
    where key = 'privacy'
      and coalesce((value->>'data_collection_enabled')::boolean, false) = true
  )
);

drop policy if exists "public upload customer designs" on storage.objects;
create policy "public upload customer designs" on storage.objects for insert to anon with check (
  bucket_id = 'customer-designs'
  and exists (
    select 1 from public.site_settings
    where key = 'privacy'
      and coalesce((value->>'data_collection_enabled')::boolean, false) = true
  )
);
