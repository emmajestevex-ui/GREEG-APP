create or replace function public.activate_license(
    p_license_key text,
    p_device_id text
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
    v_license public.licenses%rowtype;
    v_key text;
begin
    v_key := upper(replace(trim(coalesce(p_license_key, '')), ' ', ''));

    if v_key = '' or trim(coalesce(p_device_id, '')) = '' then
        return json_build_object(
            'success', false,
            'message', 'Invalid key'
        );
    end if;

    select *
    into v_license
    from public.licenses
    where license_key = v_key
    for update;

    if not found then
        return json_build_object(
            'success', false,
            'message', 'Invalid key'
        );
    end if;

    if v_license.is_active = false then
        return json_build_object(
            'success', false,
            'message', 'Key disabled'
        );
    end if;

    if v_license.used_at is not null
        or v_license.device_id is not null
        or v_license.activated_at is not null then
        return json_build_object(
            'success', false,
            'message', 'This key has already been used'
        );
    end if;

    update public.licenses
    set
        device_id = p_device_id,
        activated_at = now(),
        used_at = now()
    where id = v_license.id;

    return json_build_object(
        'success', true,
        'message', 'Key activated successfully'
    );
end;
$$;

revoke all on function public.activate_license(text, text) from public;
grant execute on function public.activate_license(text, text) to anon;
grant execute on function public.activate_license(text, text) to authenticated;
