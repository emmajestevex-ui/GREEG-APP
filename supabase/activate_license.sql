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
begin
    select *
    into v_license
    from public.licenses
    where license_key = upper(trim(p_license_key))
    for update;

    if not found then
        return json_build_object(
            'success', false,
            'message', 'Key invalida'
        );
    end if;

    if v_license.is_active = false then
        return json_build_object(
            'success', false,
            'message', 'Key desactivada'
        );
    end if;

    if v_license.device_id is null then
        update public.licenses
        set
            device_id = p_device_id,
            activated_at = now()
        where id = v_license.id;

        return json_build_object(
            'success', true,
            'message', 'Key activada correctamente'
        );
    end if;

    if v_license.device_id = p_device_id then
        return json_build_object(
            'success', true,
            'message', 'Dispositivo autorizado'
        );
    end if;

    return json_build_object(
        'success', false,
        'message', 'Esta key ya esta vinculada a otro dispositivo'
    );
end;
$$;

revoke all on function public.activate_license(text, text) from public;
grant execute on function public.activate_license(text, text) to anon;
grant execute on function public.activate_license(text, text) to authenticated;
