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

## Preparación de AIDE después del punto 9.3

En el punto 9.3 se creó `prueba_aide.txt`, se agregó contenido a `publico.txt`
y se cambiaron sus permisos de `0644` a `0640`. Para separar esa prueba del
integrador, se indicó revertir esos cambios y crear una nueva línea base,
sin guardar copias de los archivos modificados. El usuario confirmó haber
completado esa preparación; sus salidas de VM todavía no están incorporadas
en esta nota.

El procedimiento indicado fue quitar únicamente el agregado documentado
al final de `publico.txt`:

```bash
sudo python3 - <<'PY'
from pathlib import Path

archivo = Path("/srv/tp2/datos/publico.txt")
agregado = b"\nCambio controlado para la prueba de AIDE\n"
contenido = archivo.read_bytes()

if not contenido.endswith(agregado):
    raise SystemExit(
        "No se modificó el archivo: el final no coincide con el agregado del 9.3."
    )

archivo.write_bytes(contenido[:-len(agregado)])
print("Agregado del 9.3 eliminado.")
PY
```

Si el final no coincide, detenerse y revisar el contenido antes de continuar.
Si coincide, eliminar el archivo de prueba y restaurar los permisos:

```bash
sudo rm -f -- /srv/tp2/datos/prueba_aide.txt
sudo chmod 0644 /srv/tp2/datos/publico.txt
sudo aide --config=/srv/tp2/config/aide.conf --init
```

Solo si la inicialización termina correctamente, reemplazar la referencia
anterior y comprobarla:

```bash
sudo mv /srv/tp2/aide/aide.db.new /srv/tp2/aide/aide.db
sudo aide --config=/srv/tp2/config/aide.conf --check
```

Se espera `AIDE found NO differences between database and filesystem. Looks okay!!`.
La nueva referencia incorpora los tiempos actuales: deshacer el contenido y
los permisos no restaura `mtime` y `ctime`. No se modifica `eventos.log`,
AppArmor ni auditd. El reporte original del 9.3 se conserva en
[aide_check_cambios.txt](./evidencias/aide_check_cambios.txt).

No usar `restaurar_entorno.sh` para esta limpieza: retira el laboratorio,
incluidos el perfil AppArmor, las reglas auditd y `/srv/tp2`. Tampoco repetir
`preparar_entorno.sh`, porque sobrescribe los datos y vacía `eventos.log`.

## Procedimiento del punto 10

Todos los comandos siguientes se ejecutan en la VM, desde `codigo_base/`.
Mantener la misma terminal para conservar las variables de evidencia y hora.

### 1. Verificar las precondiciones

```bash
sudo aa-status
```

Confirmar que `/usr/local/bin/tp2-reader` esté entre los perfiles en `enforce`.
Si el perfil ya está instalado y cargado, pero está en `complain`:

```bash
sudo aa-enforce /usr/local/bin/tp2-reader
```

Verificar el servicio de auditoría y las reglas activas:

```bash
sudo systemctl is-active auditd
sudo auditctl -l | grep tp2_
```

Se espera `active` y las dos reglas con las claves `tp2_exec` y `tp2_datos`.
Si faltan y el archivo completo ya está instalado en
`/etc/audit/rules.d/99-tp2.rules`, cargarlas y volver a consultar:

```bash
sudo augenrules --load
sudo auditctl -l | grep tp2_
```

Comprobar la referencia AIDE y los permisos iniciales:

```bash
sudo aide --config=/srv/tp2/config/aide.conf --check
stat -c '%a %n' /srv/tp2/datos/publico.txt
```

AIDE debe informar que no hay diferencias y `publico.txt` debe tener permisos
`644`, para que el cambio posterior a `640` sea observable. No continuar si
alguna precondición falla. Los permisos DAC también deben permitir la lectura
del archivo confidencial, como se demostró en la parte de AppArmor.

### 2. Guardar el estado previo

```bash
EVIDENCIA="/srv/tp2/evidencias/integrador_$(date +%Y%m%d_%H%M%S)"
sudo mkdir -p "$EVIDENCIA"
INICIO="$(date '+%Y-%m-%d %H:%M:%S')"

sudo aa-status 2>&1 | sudo tee "$EVIDENCIA/apparmor_antes.txt"
sudo auditctl -l 2>&1 | sudo tee "$EVIDENCIA/audit_reglas.txt"
sudo aide --config=/srv/tp2/config/aide.conf --check 2>&1 \
  | sudo tee "$EVIDENCIA/aide_antes.txt"
```

### 3. Ejecutar el escenario una sola vez

```bash
sudo ./scripts/escenario_final.sh 2>&1 \
  | sudo tee "$EVIDENCIA/escenario.txt"
```

El script también guarda una transcripción en
`/srv/tp2/evidencias/escenario_<marca-de-tiempo>.txt`. No ejecuta AIDE ni
reúne los registros de AppArmor y auditd: esas consultas se hacen después.

No repetir el escenario para obtener evidencia, porque cada ejecución agrega
contenido. Sí se pueden repetir las consultas sin ejecutar otra vez el script.

### 4. Consultar AppArmor y auditd

```bash
sudo journalctl -k --since "$INICIO" --no-pager \
  | grep -i apparmor \
  | sudo tee "$EVIDENCIA/apparmor_despues.txt"

sudo ausearch -k tp2_exec -ts recent -i \
  | sudo tee "$EVIDENCIA/audit_exec.txt"

sudo ausearch -k tp2_datos -ts recent -i \
  | sudo tee "$EVIDENCIA/audit_datos.txt"
```

Buscar una denegación `DENIED` del perfil de `tp2-reader` sobre
`/srv/tp2/datos/confidencial.txt`. Ejecutar las consultas `ausearch`
inmediatamente después del escenario. `recent` puede incluir la limpieza
previa del 9.3: distinguir los eventos por hora, PID, ejecutable, rutas y
el mensaje `escenario_integrador_<marca-de-tiempo>`.

Las lecturas no tienen por qué aparecer bajo `tp2_datos`, cuya regla está
orientada a modificaciones. La evidencia del bloqueo se busca en AppArmor.

### 5. Comparar con AIDE y revisar los archivos

Sin actualizar ni regenerar la base:

```bash
sudo aide --config=/srv/tp2/config/aide.conf --check 2>&1 \
  | sudo tee "$EVIDENCIA/aide_despues.txt"

sudo tail -n 3 /srv/tp2/datos/publico.txt
sudo tail -n 3 /srv/tp2/datos/eventos.log
stat -c '%a %n' /srv/tp2/datos/publico.txt
```

Se espera encontrar la línea `cambio integrador ...`, el mensaje
`escenario_integrador_...` y permisos `640`. Detectar diferencias es el
resultado esperado de AIDE, no un fallo de configuración. Su código de salida
puede ser distinto de cero; con una tubería, `$?` normalmente corresponde a
`tee`, no a AIDE.

## Efectos que produce el script

1. El script ejecuta `tp2-reader` sobre `publico.txt`; el perfil debe permitir la lectura.
2. El script intenta leer `confidencial.txt`; con AppArmor en `enforce`, el acceso debe rechazarse. El script sigue con el resto del escenario aunque la lectura devuelva un error.
3. El script ejecuta `tp2-event` con un mensaje fechado. Las reglas configuradas deben permitir consultar tanto la ejecución como la modificación de datos.
4. Después, el script agrega una línea a `publico.txt` y cambia sus permisos a `0640`. Si esa ruta está incluida en la configuración y en la línea base de AIDE, la comprobación posterior debe informar las diferencias relevantes.

| Archivo | Diferencias esperadas en AIDE |
| --- | --- |
| `publico.txt` | Contenido, tamaño, SHA-256, tiempos y permisos de `0644` a `0640`. |
| `eventos.log` | Contenido, tamaño, SHA-256 y tiempos por la entrada agregada por `tp2-event`. |

## Reconstrucción de la evidencia

- Transcripción: confirma la lectura permitida de `publico.txt`; el registro del núcleo debe mostrar la denegación de `confidencial.txt`.
- auditd: consultá los eventos de ejecución y modificación con las claves definidas en las reglas.
- AIDE: explicá los cambios de contenido y metadatos que detecte al comparar con la línea base.
- Transcripción: usá la marca de tiempo del archivo y el mensaje de `tp2-event` como pistas para relacionar la actividad.

La evidencia debe explicar qué se intentó, qué se esperaba, qué ocurrió y qué demuestra; no alcanza con adjuntar una salida sin interpretación.

Según el punto 10 de la consigna, esta reconstrucción forma parte de la
conclusión del informe, no de un cuestionario nuevo. AppArmor restringe
operaciones, auditd registra eventos y AIDE compara estados. Usar los
resultados reales para explicar cómo se complementaron en esta ejecución.

## Estado de las evidencias

La carpeta `integrador_<marca-de-tiempo>` generada en la VM se incorporará
más adelante a `docs/evidencias/`. Hasta entonces, los resultados de esta
nota son expectativas del procedimiento, no resultados verificados de la
ejecución final.

Archivos previstos dentro de esa carpeta:

- `apparmor_antes.txt` y `audit_reglas.txt` para las precondiciones.
- `aide_antes.txt` para la comparación limpia previa.
- `escenario.txt` para la transcripción de la ejecución.
- `apparmor_despues.txt` para la denegación.
- `audit_exec.txt` y `audit_datos.txt` para la actividad registrada.
- `aide_despues.txt` para las diferencias detectadas.

Cuando se incorporen las salidas, enlazarlas e interpretar los eventos de
esa ejecución sin sustituir las evidencias originales del punto 9.3.

## Documentos relacionados

- [Resumen de AppArmor](./30-mapa-de-apparmor.md)
- [Reglas auditd](./41-reglas-y-consultas-de-auditd.md)
- [Llamadas al sistema y strace](./42-llamadas-al-sistema-y-strace.md)
- [AIDE e integridad](./43-integridad-con-aide.md)
- [Correlación de evidencia](./44-correlacion-de-evidencias.md)
