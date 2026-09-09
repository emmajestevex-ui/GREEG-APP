# GREEG APP - Guia breve de subida y compilacion

Este paquete es el proyecto original de GREEG APP actualizado para usar Supabase en la pantalla de activacion.

## 1. Supabase

La app ya esta configurada con:

```text
Project URL: https://qlfugpumolehqzzuvocn.supabase.co
Publishable key: sb_publishable_EAsMdYoIsenDI9ZYxKMcFA_3nuPXW5y
Funcion: public.activate_license(p_license_key text, p_device_id text)
```

Si necesitas recrear la tabla o la funcion, usa estos archivos:

```text
supabase/licenses_setup.sql
supabase/activate_license.sql
```

No pongas ninguna `secret key` ni `service_role` dentro de la app.

## 2. Subir a GitHub

1. Crea un repositorio nuevo, por ejemplo `GREEG-APP`.
2. No agregues README automatico.
3. Descomprime este ZIP.
4. Sube todo el contenido de la carpeta `3105-1.1.1`.
5. Asegurate de que suba tambien la carpeta `.github`.

La estructura debe quedar asi:

```text
GREEG-APP/
├── .github/workflows/build-ios.yml
├── ThreeOneOSFive/
├── ThreeOneOSFive.xcodeproj/
├── supabase/
├── README.md
└── GREEG_BUILD_GUIDE.md
```

## 3. Compilar la IPA unsigned

1. Entra al repositorio en GitHub.
2. Abre `Actions`.
3. Entra en `Build GREEG APP (unsigned)`.
4. Pulsa `Run workflow`.
5. Espera a que termine en verde.
6. Abre la ejecucion terminada.
7. Descarga el artifact `GREEG-APP-unsigned`.

Dentro estara:

```text
GREEG-APP-unsigned.ipa
```

La IPA queda sin firmar para que despues uses tu metodo de firma autorizado.

## 4. Como funciona la activacion

Cuando el cliente escribe una key, la app envia a Supabase:

```json
{
  "p_license_key": "GREEG-1",
  "p_device_id": "ios-identificador-persistente"
}
```

Supabase responde:

```json
{
  "success": true,
  "message": "Key activada correctamente"
}
```

Si `success` es `true`, la app guarda el acceso localmente. Si `success` es `false`, muestra el mensaje devuelto por Supabase.

El identificador del iPhone se genera una sola vez y se guarda en Keychain. Al volver a abrir la app, se revalida la key guardada contra Supabase para respetar keys desactivadas.

## 5. Cambios hechos

- Pantalla de activacion conectada a Supabase.
- Uso de la funcion `activate_license`.
- ID persistente de instalacion guardado en Keychain.
- Manejo de `success` y `message`.
- Diseno negro/rojo conservado.
- Workflow de GitHub Actions para generar IPA unsigned.
- Nombre visible reforzado como `GREEG APP`.

No se modificaron los archivos internos de exploit ni se agregaron nuevas funciones de ese tipo.
