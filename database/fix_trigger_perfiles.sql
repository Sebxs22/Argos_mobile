-- FIX: ACTUALIZACIÓN DEL TRIGGER DE REGISTRO
-- El problema es que la función de la base de datos no sabe que debe guardar los nuevos campos.
-- Ejecuta este script en el SQL Editor de Supabase.

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.perfiles (
    id, 
    nombre_completo, 
    telefono, 
    cedula, 
    pais, 
    ciudad, 
    acepta_terminos
  )
  VALUES (
    new.id, 
    new.raw_user_meta_data->>'nombre', 
    new.raw_user_meta_data->>'telefono',
    new.raw_user_meta_data->>'cedula',
    new.raw_user_meta_data->>'pais',
    new.raw_user_meta_data->>'ciudad',
    (new.raw_user_meta_data->>'acepta_terminos')::boolean
  );
  RETURN new;
END;
$$;

-- NOTA: Si tu función tiene un nombre diferente, cámbialo arriba. 
-- Pero por defecto en la mayoría de setups de Supabase es 'handle_new_user'.
