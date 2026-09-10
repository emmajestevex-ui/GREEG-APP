# GREEG APP — Build rápido con GitHub Actions

Este paquete cambia la identidad visual del proyecto a GREEG APP, usa el logo proporcionado, fuerza tema oscuro con acento rojo e incluye una pantalla local de acceso con claves GREEG-1 ... GREEG-1000.

## Compilar en GitHub
1. Crea un repositorio nuevo y sube TODO el contenido de esta carpeta (incluida `.github`).
2. Abre la pestaña **Actions** del repositorio.
3. Entra a **Build GREEG APP (unsigned)**.
4. Pulsa **Run workflow** → **Run workflow**.
5. Espera a que termine el trabajo.
6. Abre la ejecución terminada y descarga el artefacto **GREEG-APP-unsigned**.
7. Dentro estará `GREEG-APP-unsigned.ipa`.

La IPA generada por el workflow no se firma. Debes usar tu método de firma autorizado después.

## Sobre las keys
La pantalla incluida acepta `GREEG-1` hasta `GREEG-1000` y guarda localmente la key y el identificador del dispositivo. Esto sirve como bloqueo local de la instalación.

**Importante:** sin un servidor no es posible garantizar que una key usada en un iPhone quede inutilizable mundialmente en otro iPhone. Para keys realmente de un solo uso necesitas un backend que registre activaciones.

## Cambios realizados
- Nombre visible: GREEG APP
- Logo del usuario como App Icon y logo interno
- Tema oscuro permanente
- Acento rojo
- Pantalla de acceso por key
- Textos visibles principales de marca cambiados a GREEG APP
- Workflow de GitHub Actions para generar una IPA sin firmar

No se modificaron los archivos de exploit ni su implementación interna.
