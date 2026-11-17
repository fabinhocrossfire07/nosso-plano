begin;
create table public.households (
 id uuid primary key default gen_random_uuid(), name text not null check(length(name) between 1 and 100),
 owner_id uuid not null references auth.users(id),created_at timestamptz not null default now()
);
create table public.household_members (
 household_id uuid not null references public.households(id) on delete cascade,
 user_id uuid not null unique references auth.users(id) on delete cascade,
 display_name text not null check(display_name in ('Fabio','Bárbara')),
 joined_at timestamptz not null default now(), primary key(household_id,user_id),unique(household_id,display_name)
);
create table public.household_invites (
 id uuid primary key default gen_random_uuid(),household_id uuid not null references public.households(id) on delete cascade,
 email text not null,token_hash text unique not null,expires_at timestamptz not null default now()+interval '7 days',
 used_at timestamptz,created_at timestamptz not null default now()
);
create table public.finance_records (
 id uuid primary key default gen_random_uuid(),household_id uuid not null references public.households(id) on delete cascade,
 kind text not null check(kind in ('transaction','budget','goal','debt','settings','receipt')),
 payload jsonb not null,version integer not null default 1,
 created_by uuid not null default auth.uid() references auth.users(id),
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),deleted_at timestamptz
);
create index finance_household_idx on public.finance_records(household_id,created_at desc) where deleted_at is null;
create unique index finance_budget_unique on public.finance_records(household_id,(payload->>'scope'),(payload->>'category')) where kind='budget' and deleted_at is null;
create unique index finance_settings_unique on public.finance_records(household_id) where kind='settings' and deleted_at is null;
create unique index finance_receipt_unique on public.finance_records(household_id,(payload->>'hash')) where kind='receipt' and deleted_at is null;

create function public.is_household_member(target uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.household_members m where m.household_id=target and m.user_id=auth.uid());
$$;
revoke all on function public.is_household_member(uuid) from public;
grant execute on function public.is_household_member(uuid) to authenticated;

alter table public.households enable row level security;
alter table public.household_members enable row level security;
alter table public.household_invites enable row level security;
alter table public.finance_records enable row level security;
create policy household_read on public.households for select to authenticated using (public.is_household_member(id));
create policy members_read on public.household_members for select to authenticated using (public.is_household_member(household_id));
create policy records_read on public.finance_records for select to authenticated using (public.is_household_member(household_id));
create policy records_insert on public.finance_records for insert to authenticated with check (public.is_household_member(household_id) and created_by=auth.uid());
create policy records_update on public.finance_records for update to authenticated using (public.is_household_member(household_id)) with check (public.is_household_member(household_id));
-- No direct deletes or membership writes. Deletions are versioned soft deletions.
grant select on public.households,public.household_members to authenticated;
grant select,insert,update on public.finance_records to authenticated;
revoke all on public.household_invites from anon,authenticated;

create function public.create_household(person_name text) returns uuid language plpgsql security definer set search_path='' as $$
declare household uuid;
begin
 if auth.uid() is null then raise exception 'Entre na sua conta.'; end if;
 if not exists(select 1 from auth.users where id=auth.uid() and email_confirmed_at is not null) then raise exception 'Confirme seu e-mail antes de continuar.'; end if;
 if person_name not in ('Fabio','Bárbara') then raise exception 'Escolha Fabio ou Bárbara.'; end if;
 if exists(select 1 from public.household_members where user_id=auth.uid()) then raise exception 'Você já participa de uma família.'; end if;
 insert into public.households(name,owner_id) values('Fabio & Bárbara',auth.uid()) returning id into household;
 insert into public.household_members(household_id,user_id,display_name)values(household,auth.uid(),person_name);
 return household;
end;$$;
create function public.invite_partner(partner_email text) returns text language plpgsql security definer set search_path='' as $$
declare household uuid;raw_token text;normalized text:=lower(trim(partner_email));
begin
 select h.id into household from public.households h where h.owner_id=auth.uid();
 if household is null then raise exception 'Somente quem criou o espaço pode convidar.';end if;
 if normalized !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' or length(normalized)>254 then raise exception 'E-mail inválido.'; end if;
 if exists(select 1 from auth.users where id=auth.uid() and lower(email)=normalized) then raise exception 'Use o e-mail da outra pessoa.';end if;
 if(select count(*) from public.household_members where household_id=household)>=2 then raise exception 'O espaço já tem duas pessoas.';end if;
 -- A new invite revokes previous pending links.
 update public.household_invites set expires_at=now() where household_id=household and used_at is null;
 raw_token:=gen_random_uuid()::text||gen_random_uuid()::text;
 insert into public.household_invites(household_id,email,token_hash)values(household,normalized,encode(sha256(convert_to(raw_token,'UTF8')),'hex'));
 return raw_token;
end;$$;
create function public.accept_household_invite(invite_token text) returns uuid language plpgsql security definer set search_path='' as $$
declare invitation public.household_invites;person_name text;confirmed_email text;
begin
 if auth.uid() is null then raise exception 'Entre na sua conta.';end if;
 select lower(email) into confirmed_email from auth.users where id=auth.uid() and email_confirmed_at is not null;
 if confirmed_email is null then raise exception 'Confirme o e-mail para aceitar o convite.';end if;
 select * into invitation from public.household_invites where token_hash=encode(sha256(convert_to(invite_token,'UTF8')),'hex') and used_at is null and expires_at>now() for update;
 if invitation.id is null or invitation.email<>confirmed_email then raise exception 'Convite inválido, expirado ou destinado a outro e-mail.';end if;
 -- Serialize partner acceptance and enforce the two-person limit.
 perform 1 from public.households where id=invitation.household_id for update;
 if exists(select 1 from public.household_members where user_id=auth.uid()) then raise exception 'Sua conta já participa de um espaço.';end if;
 if(select count(*) from public.household_members where household_id=invitation.household_id)>=2 then raise exception 'O espaço já tem duas pessoas.';end if;
 select case when display_name='Fabio' then 'Bárbara' else 'Fabio' end into person_name from public.household_members where household_id=invitation.household_id limit 1;
 insert into public.household_members(household_id,user_id,display_name)values(invitation.household_id,auth.uid(),person_name);
 update public.household_invites set used_at=now() where id=invitation.id;
 return invitation.household_id;
end;$$;
revoke all on function public.create_household(text),public.invite_partner(text),public.accept_household_invite(text) from public;
grant execute on function public.create_household(text),public.invite_partner(text),public.accept_household_invite(text) to authenticated;

create function public.validate_finance_record() returns trigger language plpgsql set search_path='' as $$
declare p jsonb:=new.payload;key text;date_key text;valid boolean:=false;
begin
 if tg_op='UPDATE' then
  if new.household_id<>old.household_id or new.kind<>old.kind or new.created_by<>old.created_by or new.created_at<>old.created_at then raise exception 'A origem do registro não pode ser alterada.';end if;
  new.version:=old.version+1;new.updated_at:=now();
 end if;
 if jsonb_typeof(p)<>'object' then raise exception 'Dados inválidos.';end if;
 if new.kind in ('transaction','budget','goal','debt') and not coalesce(p->>'scope' in ('Fabio','Bárbara','Conjunto'),false) then raise exception 'Responsabilidade inválida.';end if;
 case new.kind
 when 'transaction' then
  valid:=length(p->>'description') between 1 and 200 and p->>'type' in ('income','expense','transfer') and p->>'status' in ('paid','pending') and p->>'payer' in ('Fabio','Bárbara') and length(p->>'category') between 1 and 80 and length(coalesce(p->>'account',''))<=80 and length(coalesce(p->>'note',''))<=1000;
  if coalesce(p->>'receipt','')<>'' then
   perform 1 from public.finance_records r where r.id::text=p->>'receipt' and r.household_id=new.household_id and r.kind='receipt' and r.deleted_at is null for update;
   if not found then raise exception 'Comprovante não encontrado neste espaço.';end if;
  end if;
 when 'budget' then valid:=length(p->>'category') between 1 and 80;
 when 'goal' then valid:=length(p->>'name') between 1 and 100 and (p->>'target')::numeric>0;
 when 'debt' then valid:=length(p->>'name') between 1 and 100 and (p->>'rate')::numeric between 0 and 1000;
 when 'settings' then valid:=jsonb_typeof(p->'reserveMonths')='number' and coalesce(p->>'reserveMonths','') ~ '^[0-9]+$' and (p->>'reserveMonths')::int between 1 and 24 and jsonb_typeof(p->'essential')='array' and jsonb_array_length(p->'essential')<=40;
 when 'receipt' then
  valid:=length(p->>'name') between 1 and 200 and p->>'type' in ('application/pdf','image/png','image/jpeg') and (p->>'size')::numeric between 1 and 10000000 and p->>'hash' ~ '^[a-f0-9]{64}$' and p->>'key'=new.household_id::text||'/'||new.id::text;
  if tg_op='UPDATE' and (new.payload<>old.payload) then raise exception 'O arquivo original não pode ser substituído.';end if;
 end case;
 if not coalesce(valid,false) then raise exception 'Preencha os campos obrigatórios corretamente.';end if;
 for key in select unnest(case new.kind when 'transaction' then array['amount'] when 'budget' then array['amount'] when 'goal' then array['target','saved'] when 'debt' then array['balance','payment'] else array[]::text[] end) loop
  if jsonb_typeof(p->key)<>'number' or not coalesce(p->>key ~ '^[0-9]+$',false) or (p->>key)::numeric>100000000000 then raise exception 'Valor monetário inválido: %',key;end if;
 end loop;
 date_key:=case new.kind when 'transaction' then 'date' when 'goal' then 'deadline' when 'debt' then 'due' else null end;
 if date_key is not null and not coalesce(p->>date_key ~ '^\d{4}-\d{2}-\d{2}$' and to_char((p->>date_key)::date,'YYYY-MM-DD')=p->>date_key,false) then raise exception 'Data inválida.';end if;
 if new.kind='receipt' and new.deleted_at is not null and exists(select 1 from public.finance_records r where r.household_id=new.household_id and r.kind='transaction' and r.deleted_at is null and r.payload->>'receipt'=new.id::text) then raise exception 'Remova o vínculo do lançamento antes de excluir o comprovante.';end if;
 return new;
end;$$;
create trigger finance_validate before insert or update on public.finance_records for each row execute function public.validate_finance_record();

-- Private bucket. Direct browser uploads avoid Vercel request-size constraints.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('receipts','receipts',false,10000000,array['application/pdf','image/png','image/jpeg']);
create policy receipts_select on storage.objects for select to authenticated using(bucket_id='receipts' and exists(select 1 from public.household_members m where m.user_id=auth.uid() and m.household_id::text=(storage.foldername(name))[1]));
create policy receipts_insert on storage.objects for insert to authenticated with check(bucket_id='receipts' and exists(select 1 from public.household_members m where m.user_id=auth.uid() and m.household_id::text=(storage.foldername(name))[1]));
create policy receipts_delete on storage.objects for delete to authenticated using(bucket_id='receipts' and exists(select 1 from public.household_members m where m.user_id=auth.uid() and m.household_id::text=(storage.foldername(name))[1]));
-- Soft deletions are UPDATE events, which retain household filtering and RLS.
alter publication supabase_realtime add table public.finance_records;
alter publication supabase_realtime add table public.household_members;
commit;
