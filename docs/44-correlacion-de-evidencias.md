# Correlación de evidencias

> **Alcance:** cómo generar una actividad controlada y correlacionar las observaciones de strace y auditd.
>
> **Cuándo leerlo:** al reunir la evidencia de la parte 3 o redactar qué demuestra cada salida.
>
> **Prerrequisitos:** las notas de [strace](./42-llamadas-al-sistema-y-strace.md) y [auditd](./41-reglas-y-consultas-de-auditd.md).

Esta nota documenta el punto **9.2 de la consigna** y la ejecución realizada
el 3 de octubre de 2026.

## Documentos relacionados

- [Resumen de auditoría e integridad](./40-mapa-de-auditoria-e-integridad.md)
- [Llamadas al sistema y strace](./42-llamadas-al-sistema-y-strace.md)
- [Reglas auditd](./41-reglas-y-consultas-de-auditd.md)
- [AIDE](./43-integridad-con-aide.md)
- [Escenario integrador](./50-escenario-integrador.md)

## Secuencia de trabajo y correlación

Esta nota reúne los pasos 2 y 4 de la secuencia de la parte 3. Para cargar reglas y consultar eventos, seguí [41 — reglas y consultas de auditd](./41-reglas-y-consultas-de-auditd.md).

### 2. Generar y observar el evento

Después, ejecutá `tp2-event` bajo `strace`. Una sola ejecución produce varios
efectos observables:

Antes de ejecutar, verificá que las dos reglas del punto 9.1 estén activas:

```bash
sudo auditctl -l | grep tp2_
```

No hace falta cargar el perfil AppArmor para este punto. El perfil del TP
controla `tp2-reader`, mientras que acá se ejecuta `tp2-event`. AppArmor en
`enforce` sí es una precondición del escenario integrador del punto 10.

En la VM, ejecutá:

```bash
sudo strace -f -e trace=execve,openat,write \
  -o /srv/tp2/evidencias/strace_tp2_event.txt \
  /usr/local/bin/tp2-event "evento_grupo_N"
```

Reemplazá `N` por el número del grupo. No ejecutes el programa por separado:
`strace` ya lo lanza y guarda las llamadas seleccionadas. En la prueba
documentada se usó `"1000"` como mensaje, no como configuración del UID.

```text
tp2-event
  -> strace observa execve, openat y write
  -> auditd registra la ejecución con la clave tp2_exec
  -> auditd registra la apertura para escritura con la clave tp2_datos
  -> eventos.log queda modificado
```

Consultá las salidas después de ejecutar:

```bash
sudo cat /srv/tp2/evidencias/strace_tp2_event.txt
sudo ausearch -k tp2_exec -ts recent -i
sudo ausearch -k tp2_datos -ts recent -i
```

`-ts recent` usa una ventana temporal móvil. Conviene guardar las salidas
durante la prueba; para consultar una ejecución antigua, elegí su intervalo
con `-ts` y `-te` en lugar de usar `recent`.

### 4. Correlacionar ambas observaciones

La evidencia de `strace` y la de `ausearch` describen partes de la misma
actividad. La consigna pide relacionar al menos:

- marca de tiempo;
- PID;
- ruta del ejecutable;
- llamada al sistema;
- resultado exitoso o fallido.

No hace falta que ambas salidas tengan exactamente el mismo formato. La
correlación consiste en justificar que los campos compatibles corresponden a
la misma ejecución.

## Caso realizado: PID 3180

Se esperaba que `tp2-event` agregara una línea a `eventos.log`, que `strace`
mostrara las llamadas al sistema y que auditd registrara la ejecución y la
apertura para escritura con las claves del TP.

### Evidencias disponibles

- [Evento 315 de ejecución](./evidencias/audit_tp2_datos_315.txt): aunque el
  nombre del archivo dice `datos`, el evento relevante tiene `key=tp2_exec`.
- [Evento 316 de apertura para escritura](./evidencias/audit_tp2_datos_316.txt):
  el evento relevante tiene `key=tp2_datos`.

El archivo `strace_tp2_event.txt` todavía no está incluido en
`docs/evidencias/`. Los fragmentos siguientes se transcriben de la salida
compartida durante la prueba; no reemplazan la conservación del archivo
original de la VM.

```text
3180  execve("/usr/local/bin/tp2-event", ["/usr/local/bin/tp2-event", "1000"], 0x7ffde5a2d5d0 /* 12 vars */) = 0
3180  openat(AT_FDCWD, "/srv/tp2/datos/eventos.log", O_WRONLY|O_CREAT|O_APPEND, 0666) = 3
3180  write(3, "2026-10-03T21:54:59+0000 pid=318"..., 53) = 53
3180  write(1, "Evento registrado en /srv/tp2/da"..., 48) = 48
3180  +++ exited with 0 +++
```

### Comparación de campos

| Campo | strace | auditd |
| --- | --- | --- |
| PID | `3180` al inicio de las líneas | `pid=3180` en los eventos 315 y 316 |
| Ejecutable | `/usr/local/bin/tp2-event` en `execve` | `exe=/usr/local/bin/tp2-event` |
| Argumento | `"1000"` | `a1=1000` en el registro `EXECVE` del evento 315 |
| Ejecución | `execve(...) = 0` | Evento 315: `syscall=execve success=yes exit=0` |
| Archivo abierto | `/srv/tp2/datos/eventos.log` en `openat` | La misma ruta en el registro `PATH` del evento 316 |
| Apertura | `O_WRONLY`, `O_CREAT` y `O_APPEND`; resultado `3` | Evento 316: `syscall=openat`, las mismas opciones, `success=yes exit=3` |
| Tiempo | El mensaje escrito contiene `2026-10-03T21:54:59+0000` | Evento 315: `10/03/2026 21:54:59.139`; evento 316: `10/03/2026 21:54:59.155` |

Las fechas de estas salidas de auditd están en formato mes/día/año. Ambos
eventos corresponden al 3 de octubre de 2026 y están separados por 16 ms.
El comando utilizado de `strace` no agrega timestamps a cada llamada: la
marca de tiempo visible pertenece al contenido que escribe el programa.
Permite relacionar la actividad al segundo, pero no comparar el instante
exacto de cada syscall. Para nuevas pruebas se puede agregar `-tt` a
`strace` para registrar la hora de cada llamada.

### Qué demuestra cada resultado

`execve(...) = 0` y `success=yes exit=0` confirman la ejecución exitosa del
mismo binario. El PID, la ruta y el argumento coinciden en ambas herramientas.

`openat(...) = 3` y `success=yes exit=3` confirman que el mismo proceso abrió
`eventos.log` y recibió el descriptor 3. Ese `3` es un descriptor, no un
código de error. `O_APPEND` indica que las escrituras se agregan al final;
`O_CREAT` permite crear el archivo si no existe, pero no demuestra que se
haya creado en esta ejecución.

Luego, `write(3, ..., 53) = 53` demuestra que se escribieron 53 bytes en el
archivo abierto. `write(1, ..., 48) = 48` corresponde al mensaje de
confirmación en la salida estándar, no a otra escritura en `eventos.log`.

En esta evidencia, auditd registró `openat` bajo `tp2_datos`, no `write`.
La regla de vigilancia no produce necesariamente un evento por cada
escritura. La apertura para escritura queda auditada; `strace` demuestra
la escritura efectiva. No se debe afirmar que ambas salidas contienen
una llamada `write` coincidente.

Los registros también muestran `auid=santiago` y `uid=root euid=root`.
El primero identifica al usuario de inicio de sesión; los otros indican
que el proceso se ejecutó como root mediante `sudo`.

### Cómo separar los eventos relevantes

Las consultas iniciales por clave también mostraron los eventos 298 y 299,
con `comm=auditctl` y `op=add_rule`. Esos eventos documentan la carga de
reglas a las 21:49:09, no la ejecución de `tp2-event` a las 21:54:59.

Los dos archivos guardados en el repositorio contienen además registros
de septiembre con los números 315 y 316. La búsqueda por número con
`ausearch -a` puede devolver eventos de distintas fechas porque los números
pueden repetirse entre arranques. Para identificar el evento, usá también
su timestamp, PID, ejecutable y clave, no solamente el número.

Durante el mismo día de la prueba, se podían guardar salidas más acotadas así:

```bash
sudo ausearch -k tp2_exec -p 3180 -a 315 -ts today -i \
  | sudo tee /srv/tp2/evidencias/audit_tp2_exec_315.txt > /dev/null
sudo ausearch -k tp2_datos -p 3180 -a 316 -ts today -i \
  | sudo tee /srv/tp2/evidencias/audit_tp2_datos_316.txt > /dev/null
```

Para repetir la consulta otro día, reemplazá `today` por el intervalo de
la prueba con `-ts` y `-te`. Ajustá también el PID y los números de evento
si realizás una nueva ejecución.

### Conclusión del punto 9.2

Las observaciones corresponden a la misma ejecución de `tp2-event` con
PID 3180 y mensaje `1000`. Coinciden el ejecutable, el argumento, las
llamadas `execve` y `openat` y sus resultados exitosos. El tiempo del
mensaje escrito coincide al segundo con los eventos de auditd.
`strace` muestra además la escritura efectiva de 53 bytes, mientras
auditd conserva los eventos seleccionados por las reglas cargadas.

Para completar el conjunto de evidencias del repositorio, falta incorporar
el archivo original `/srv/tp2/evidencias/strace_tp2_event.txt`.

## Leer a continuación

- [AIDE y cambios frente a la línea base](./43-integridad-con-aide.md)
- [Escenario integrador](./50-escenario-integrador.md)
