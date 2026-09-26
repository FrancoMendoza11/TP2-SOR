# Escenario integrador

> **Alcance:** explica las precondiciones y los efectos del escenario integrador que reúne AppArmor, auditd y AIDE.
>
> **Cuándo leerlo:** después de configurar las tres áreas, antes de ejecutar `escenario_final.sh` y al interpretar sus evidencias.
>
> **Prerrequisitos:** [perfil AppArmor en enforce](./31-perfil-apparmor-instalacion-y-pruebas.md), [reglas auditd cargadas](./41-reglas-y-consultas-de-auditd.md) y [línea base AIDE activa](./43-integridad-con-aide.md).

## Propósito

El escenario pide reconstruir qué operación fue permitida, cuál fue bloqueada, qué actividad quedó en auditd y qué cambios detectó AIDE. Combina el control de acceso por aplicación, la auditoría de eventos seleccionados y la detección de cambios en archivos. Cada herramienta aporta una parte distinta.

## Antes de ejecutarlo

- Trabajá solo en la VM aislada Ubuntu Server 24.04 LTS del TP y conservá la instantánea `TP2_BASE`.
- Dejá el perfil de `/usr/local/bin/tp2-reader` en modo `enforce`.
- Cargá y verificá las reglas auditd de la parte 3.
- Configurá AIDE y generá la línea base inicial antes de los cambios del escenario; no la actualices antes de comprobarlos.

## Ejecución

Desde `codigo_base/`:

```bash
sudo ./scripts/escenario_final.sh
```

El script guarda una transcripción de sus pasos en `/srv/tp2/evidencias/escenario_<marca-de-tiempo>.txt`. Luego de ejecutarlo, reuní por separado las observaciones de AppArmor, auditd y AIDE; el script no reemplaza esas consultas.

## Efectos que produce el script

1. El script ejecuta `tp2-reader` sobre `publico.txt`; el perfil debe permitir la lectura.
2. El script intenta leer `confidencial.txt`; con AppArmor en `enforce`, el acceso debe rechazarse. El script sigue con el resto del escenario aunque la lectura devuelva un error.
3. El script ejecuta `tp2-event` con un mensaje fechado. Las reglas configuradas deben permitir consultar tanto la ejecución como la modificación de datos.
4. Después, el script agrega una línea a `publico.txt` y cambia sus permisos a `0640`. Si esa ruta está incluida en la configuración y en la línea base de AIDE, la comprobación posterior debe informar las diferencias relevantes.

## Reconstrucción de la evidencia

- Transcripción: confirma la lectura permitida de `publico.txt`; el registro del núcleo debe mostrar la denegación de `confidencial.txt`.
- auditd: consultá los eventos de ejecución y modificación con las claves definidas en las reglas.
- AIDE: explicá los cambios de contenido y metadatos que detecte al comparar con la línea base.
- Transcripción: usá la marca de tiempo del archivo y el mensaje de `tp2-event` como pistas para relacionar la actividad.

La evidencia debe explicar qué se intentó, qué se esperaba, qué ocurrió y qué demuestra; no alcanza con adjuntar una salida sin interpretación.

## Documentos relacionados

- [Resumen de AppArmor](./30-mapa-de-apparmor.md)
- [Reglas auditd](./41-reglas-y-consultas-de-auditd.md)
- [Llamadas al sistema y strace](./42-llamadas-al-sistema-y-strace.md)
- [AIDE e integridad](./43-integridad-con-aide.md)
- [Correlación de evidencia](./44-correlacion-de-evidencias.md)
