# greeg app - Guia breve

Este paquete es la version cliente de greeg app. La app crea automaticamente los patches internos despues de activar una key, sin pedirle al cliente que importe ni guarde un archivo `.3105`.

## 1. Archivos privados de los patches

Los archivos privados ya van colocados aqui:

```text
ThreeOneOSFive/BundledPatchPayloads/
```

Nombres incluidos:

```text
assetindexer.H5ak1JM1Eck~2FxRcJrEp~2FMzeuqmY~3D
shaders.HPt9DZviTSXL9hpGW9QNOMigNLA~3D
com.dts.freefireth.plist
```

La app creara automaticamente tres patches internos.

Patch `Asset Indexer`:

```text
com.dts.freefireth
Documents/contentcache/Compulsory/ios/gameassetbundles/avatar/assetindexer.H5ak1JM1Eck~2FxRcJrEp~2FMzeuqmY~3D
```

Patch `Shaders`:

```text
com.dts.freefireth
Documents/contentcache/Optional/ios/gameassetbundles/shaders.HPt9DZviTSXL9hpGW9QNOMigNLA~3D
```

Patch `144 fps`:

```text
com.dts.freefireth
Library/Preferences/com.dts.freefireth.plist
```

Los patches internos se guardan en Application Support, no en Documents. La UI no muestra importar, exportar ni cambiar reglas; solo deja editar el nombre del patch.

## 2. Supabase

La app ya esta configurada con:

```text
Project URL: https://qlfugpumolehqzzuvocn.supabase.co
Publishable key: sb_publishable_EAsMdYoIsenDI9ZYxKMcFA_3nuPXW5y
Funcion: public.activate_license(p_license_key text, p_device_id text)
```

Ejecuta estos SQL en Supabase para que la key sea de un solo uso:

```text
supabase/licenses_setup.sql
supabase/activate_license.sql
```

La funcion nueva funciona asi:

- Si la key no existe, responde `Invalid key`.
- Si la key esta desactivada, responde `Key disabled`.
- Si la key ya tiene `used_at`, `device_id` o `activated_at`, responde `This key has already been used`.
- Si es la primera vez, guarda `device_id`, `activated_at`, `used_at` y responde `Key activated successfully`.

La app no vuelve a llamar Supabase al abrir si ya esta activada localmente. Asi no se bloquea sola, pero si borran/reinstalan la app, la key ya usada no vuelve a activar.

No pongas ninguna `secret key` ni `service_role` dentro de la app.

## 3. Subir a GitHub

1. Crea un repositorio nuevo, por ejemplo `GREEG-APP`.
2. No agregues README automatico.
3. Descomprime este ZIP.
4. Sube todo el contenido de esta carpeta.
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

## 4. Compilar la IPA unsigned

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

## 5. Cambios hechos

- Nombre visible cambiado a `greeg app`.
- Pantalla de key en ingles.
- Cleaner, Wallpapers y Files ocultos de la navegacion.
- Patches `Asset Indexer`, `Shaders` y `144 fps` generados automaticamente desde payloads embebidos.
- Botones cliente: `Apply`, `Original` y `Edit Name`.
- Importar, exportar, crear y editar reglas removidos de la UI.
- `UIFileSharingEnabled` desactivado.
- Supabase configurado para consumir cada key una sola vez.

Nota honesta: cualquier archivo dentro de una IPA puede ser extraido por alguien con conocimientos tecnicos. Este cambio evita que el cliente reciba el paquete en Files o lo exporte desde la app; no convierte la IPA en una caja imposible de inspeccionar.
