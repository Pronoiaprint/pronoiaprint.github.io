-- PRONOIA PRINT — instalación inicial independiente
-- Ejecutar una sola vez desde Supabase > SQL Editor.

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  slug text not null unique,
  description text not null default '',
  sizes text[] not null default '{}',
  colors text[] not null default array['Negro','Blanco'],
  placements text[] not null default '{}',
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.gallery_items (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  category text not null default 'Otros',
  image_url text not null,
  alt_text text not null default '',
  published boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.testimonials (
  id uuid primary key default gen_random_uuid(),
  customer_name text not null,
  customer_detail text not null default '',
  quote text not null,
  source text not null default 'Cargado por Pronoia',
  consent_confirmed boolean not null default false,
  published boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.faqs (
  id uuid primary key default gen_random_uuid(),
  question text not null,
  answer text not null,
  pending_confirmation boolean not null default false,
  published boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.site_settings (
  key text primary key,
  value jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.quote_requests (
  id uuid primary key default gen_random_uuid(),
  customer_name text not null,
  whatsapp text not null,
  email text,
  city text not null,
  product text not null,
  color text not null,
  size text not null,
  quantity integer not null check (quantity between 1 and 500),
  placement text not null,
  notes text not null default '',
  design_path text,
  design_filename text,
  status text not null default 'pendiente' check (status in ('pendiente','contactado','confirmado','descartado')),
  privacy_consent boolean not null default false,
  privacy_consent_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists products_updated_at on public.products;
create trigger products_updated_at before update on public.products for each row execute function public.set_updated_at();
drop trigger if exists gallery_items_updated_at on public.gallery_items;
create trigger gallery_items_updated_at before update on public.gallery_items for each row execute function public.set_updated_at();
drop trigger if exists testimonials_updated_at on public.testimonials;
create trigger testimonials_updated_at before update on public.testimonials for each row execute function public.set_updated_at();
drop trigger if exists faqs_updated_at on public.faqs;
create trigger faqs_updated_at before update on public.faqs for each row execute function public.set_updated_at();
drop trigger if exists site_settings_updated_at on public.site_settings;
create trigger site_settings_updated_at before update on public.site_settings for each row execute function public.set_updated_at();
drop trigger if exists quote_requests_updated_at on public.quote_requests;
create trigger quote_requests_updated_at before update on public.quote_requests for each row execute function public.set_updated_at();

alter table public.products enable row level security;
alter table public.gallery_items enable row level security;
alter table public.testimonials enable row level security;
alter table public.faqs enable row level security;
alter table public.site_settings enable row level security;
alter table public.quote_requests enable row level security;

grant usage on schema public to anon, authenticated;
grant select on public.products, public.gallery_items, public.testimonials, public.faqs, public.site_settings to anon;
grant insert on public.quote_requests to anon;
grant all on public.products, public.gallery_items, public.testimonials, public.faqs, public.site_settings, public.quote_requests to authenticated;

drop policy if exists "public read active products" on public.products;
create policy "public read active products" on public.products for select to anon, authenticated using (active = true);
drop policy if exists "admin manage products" on public.products;
create policy "admin manage products" on public.products for all to authenticated using (true) with check (true);

drop policy if exists "public read gallery" on public.gallery_items;
create policy "public read gallery" on public.gallery_items for select to anon, authenticated using (published = true);
drop policy if exists "admin manage gallery" on public.gallery_items;
create policy "admin manage gallery" on public.gallery_items for all to authenticated using (true) with check (true);

drop policy if exists "public read testimonials" on public.testimonials;
create policy "public read testimonials" on public.testimonials for select to anon, authenticated using (published = true and consent_confirmed = true);
drop policy if exists "admin manage testimonials" on public.testimonials;
create policy "admin manage testimonials" on public.testimonials for all to authenticated using (true) with check (true);

drop policy if exists "public read faqs" on public.faqs;
create policy "public read faqs" on public.faqs for select to anon, authenticated using (published = true);
drop policy if exists "admin manage faqs" on public.faqs;
create policy "admin manage faqs" on public.faqs for all to authenticated using (true) with check (true);

drop policy if exists "public read settings" on public.site_settings;
create policy "public read settings" on public.site_settings for select to anon, authenticated using (true);
drop policy if exists "admin manage settings" on public.site_settings;
create policy "admin manage settings" on public.site_settings for all to authenticated using (true) with check (true);

drop policy if exists "public submit quote" on public.quote_requests;
create policy "public submit quote" on public.quote_requests for insert to anon with check (
  status = 'pendiente' and privacy_consent = true and privacy_consent_at is not null
);
drop policy if exists "admin manage quotes" on public.quote_requests;
create policy "admin manage quotes" on public.quote_requests for all to authenticated using (true) with check (true);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('gallery', 'gallery', true, 8388608, array['image/jpeg','image/png','image/webp']),
  ('customer-designs', 'customer-designs', false, 10485760, array['image/jpeg','image/png','application/pdf'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "admin upload gallery" on storage.objects;
create policy "admin upload gallery" on storage.objects for insert to authenticated with check (bucket_id = 'gallery');
drop policy if exists "admin update gallery files" on storage.objects;
create policy "admin update gallery files" on storage.objects for update to authenticated using (bucket_id = 'gallery') with check (bucket_id = 'gallery');
drop policy if exists "admin delete gallery files" on storage.objects;
create policy "admin delete gallery files" on storage.objects for delete to authenticated using (bucket_id = 'gallery');

drop policy if exists "public upload customer designs" on storage.objects;
create policy "public upload customer designs" on storage.objects for insert to anon with check (bucket_id = 'customer-designs');
drop policy if exists "admin read customer designs" on storage.objects;
create policy "admin read customer designs" on storage.objects for select to authenticated using (bucket_id = 'customer-designs');
drop policy if exists "admin delete customer designs" on storage.objects;
create policy "admin delete customer designs" on storage.objects for delete to authenticated using (bucket_id = 'customer-designs');

insert into public.products (name, slug, description, sizes, colors, placements, active, sort_order)
values
  ('Remera', 'remera', 'El clásico para cualquier idea', array['XS','S','M','L','XL','XXL','A confirmar'], array['Negro','Blanco'], array['Frente','Espalda','Pecho','Manga'], true, 1),
  ('Buzo', 'buzo', 'Abrigo con identidad propia', array['XS','S','M','L','XL','XXL','A confirmar'], array['Negro','Blanco'], array['Frente','Espalda','Pecho','Manga'], true, 2),
  ('Tote bag', 'tote-bag', 'Tu diseño, todos los días', array['Único','A confirmar'], array['Negro','Blanco'], array['Frente','Reverso'], true, 3)
on conflict (slug) do nothing;

insert into public.faqs (question, answer, pending_confirmation, published, sort_order)
values
  ('¿Qué es el estampado DTF?', 'Es una técnica de impresión textil que permite transferir diseños con mucho detalle, color y buena definición sobre distintas prendas.', false, true, 1),
  ('¿Hay una cantidad mínima?', 'Pendiente de confirmar con Pronoia. Podés pedir presupuesto indicando la cantidad que necesitás.', true, true, 2),
  ('¿Qué formatos de archivo aceptan?', 'Podés cargar JPG, PNG o PDF de hasta 10 MB. Antes de producir, Pronoia revisará la calidad del archivo.', false, true, 3),
  ('¿Cuánto demora un pedido?', 'El plazo depende del producto, la cantidad y la complejidad del diseño. Se confirma con cada presupuesto.', true, true, 4),
  ('¿Hacen envíos?', 'Pronoia realiza envíos dentro de Argentina. El costo y plazo se confirman según la localidad.', false, true, 5),
  ('¿Cómo cuido la prenda?', 'Las instrucciones definitivas están pendientes de validación comercial y se entregarán junto con la confirmación del pedido.', true, true, 6)
on conflict do nothing;

insert into public.site_settings (key, value)
values
  ('contact', '{"whatsapp":"5491133132418","instagram":"pronoia.print"}'::jsonb),
  ('business', '{"headline":"Tu marca también se puede vestir.","description":"Indumentaria para empresas, emprendimientos, eventos, restaurantes, comercios, equipos y creadores de contenido."}'::jsonb)
on conflict (key) do nothing;
