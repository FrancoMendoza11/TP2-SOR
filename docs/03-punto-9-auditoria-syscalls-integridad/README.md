# Punto 9: auditoria, syscalls e integridad

## Objetivo general

El punto 9 busca observar una misma actividad desde perspectivas diferentes:

- `strace` muestra las llamadas al sistema realizadas durante una ejecucion.
- `auditd` conserva eventos de seguridad para consultarlos posteriormente.
- AIDE compara el estado actual de los archivos con una linea base anterior.

Estas herramientas no se reemplazan entre si. `strace` explica como interactua
un proceso con el kernel, `auditd` deja evidencia persistente de operaciones
seleccionadas y AIDE detecta diferencias en el estado de los archivos.

## Que es `tp2-event`

`tp2-event` es un programa pequeno en C provisto por la catedra. Su codigo esta
en `codigo_base/src/tp2_event.c` y se instala como:

```text
/usr/local/bin/tp2-event
```

Al ejecutarlo con un mensaje:

```bash
/usr/local/bin/tp2-event "evento_grupo_N"
```

abre `/srv/tp2/datos/eventos.log` en modo agregar y escribe una linea que
incluye:

- fecha y hora;
- PID del proceso;
- UID del usuario;
- mensaje recibido como argumento.

No es una herramienta ofensiva ni una utilidad propia de Ubuntu. Es una
aplicacion controlada que produce operaciones conocidas para poder observarlas
con `strace`, `auditd` y AIDE.

## Aplicacion, biblioteca y kernel

Un programa de usuario no accede directamente al disco. Solicita servicios al
kernel mediante llamadas al sistema o *syscalls*.

El codigo de `tp2-event` usa funciones de la biblioteca C como `fopen`,
`fprintf` y `fclose`. Internamente, la biblioteca termina realizando llamadas
al sistema como `openat`, `write` y `close`.

El flujo simplificado es:

```text
shell
  -> execve("/usr/local/bin/tp2-event", ...)
       -> openat(..., "/srv/tp2/datos/eventos.log", ...)
            -> write(descriptor, "fecha pid uid mensaje...", ...)
                 -> close(descriptor)
```

Las tres syscalls destacadas en la consigna son:

| Syscall | Solicitud realizada al kernel |
| --- | --- |
| `execve` | Cargar y ejecutar un programa. |
| `openat` | Abrir un archivo y devolver un descriptor. |
| `write` | Escribir bytes mediante un descriptor abierto. |

Un descriptor es un numero que el kernel entrega al proceso para representar
un recurso abierto. Por ejemplo, si `openat` devuelve `3`, las escrituras
posteriores sobre el archivo pueden aparecer como `write(3, ...)`.

## Que observa `strace`

`strace` acompana una ejecucion concreta y muestra las syscalls realizadas por
el proceso. En el punto 9.2 se usa al ejecutar `tp2-event`:

```bash
sudo strace -f -e trace=execve,openat,write \
  -o /srv/tp2/evidencias/strace_tp2_event.txt \
  /usr/local/bin/tp2-event "evento_grupo_N"
```

Las opciones cumplen estas funciones:

- `-f`: sigue tambien los procesos hijos.
- `-e trace=...`: limita la salida a las syscalls indicadas.
- `-o`: guarda el resultado en un archivo de evidencia.

Una salida simplificada puede tener esta forma:

```text
execve("/usr/local/bin/tp2-event", [...], [...]) = 0
openat(AT_FDCWD, "/srv/tp2/datos/eventos.log", ...) = 3
write(3, "2026-09-21... mensaje=evento_grupo_N", ...) = 63
```

El valor ubicado despues de `=` es el resultado de la syscall:

- `execve(...) = 0`: la ejecucion fue exitosa.
- `openat(...) = 3`: el kernel devolvio el descriptor `3`.
- `write(...) = 63`: se escribieron 63 bytes.
- un valor `-1` indica un error e incluye normalmente su codigo simbolico.

`strace` sirve para analizar esa ejecucion mientras sucede. No funciona como un
registro historico general del sistema.

## Que significan `tp2_exec` y `tp2_datos`

`tp2_exec` y `tp2_datos` no son comandos, programas ni syscalls. Son claves o
etiquetas asignadas a las dos reglas de `auditd` solicitadas por la consigna.
Permiten encontrar posteriormente los eventos producidos por cada regla.

### Clave `tp2_exec`

Identifica la regla que registra la syscall `execve` cuando se ejecuta:

```text
/usr/local/bin/tp2-event
```

Su objetivo es dejar evidencia de quien ejecuto el programa, cuando lo hizo,
que proceso intervino y cual fue el resultado.

### Clave `tp2_datos`

Identifica la regla que vigila modificaciones y cambios de atributos dentro de:

```text
/srv/tp2/datos
```

Cuando `tp2-event` agrega una linea a `eventos.log`, esta regla permite localizar
la actividad relacionada con la modificacion de los datos.

## Secuencia de trabajo

### 1. Completar y cargar las reglas

Primero se completa `audit/99-tp2.rules`, se instala en
`/etc/audit/rules.d/99-tp2.rules` y se cargan las reglas:

```bash
sudo augenrules --load
sudo auditctl -l | grep tp2_
```

`auditctl -l` permite comprobar que las reglas estan activas antes de generar
el evento. Si se ejecuta el programa antes de cargar las reglas, auditd no puede
registrar retroactivamente esa actividad.

### 2. Generar y observar el evento

Luego se ejecuta `tp2-event` bajo `strace`. Una sola ejecucion produce varios
efectos observables:

```text
tp2-event
  -> strace observa execve, openat y write
  -> auditd registra la ejecucion con la clave tp2_exec
  -> auditd registra la modificacion con la clave tp2_datos
  -> eventos.log queda modificado
```

### 3. Consultar auditd

Despues de la ejecucion se buscan los eventos por sus claves:

```bash
sudo ausearch -k tp2_exec -ts recent -i
sudo ausearch -k tp2_datos -ts recent -i
```

- `-k` filtra por la clave asignada a la regla.
- `-ts recent` limita la busqueda a eventos recientes.
- `-i` interpreta valores numericos para facilitar la lectura.

### 4. Correlacionar ambas observaciones

La evidencia de `strace` y la de `ausearch` describen partes de la misma
actividad. La consigna pide relacionar al menos:

- timestamp;
- PID;
- ruta del ejecutable;
- syscall;
- resultado exitoso o fallido.

No es necesario que ambas salidas tengan exactamente el mismo formato. La
correlacion consiste en justificar que los campos compatibles corresponden a
la misma ejecucion.

## Papel de AIDE

AIDE no observa syscalls ni registra eventos en tiempo real. Primero recorre las
rutas configuradas y crea una base con el estado esperado de sus archivos.
Luego vuelve a recorrerlas y compara el estado actual con esa linea base.

En este TP la configuracion local se limita a `/srv/tp2/datos` y debe comprobar
atributos como:

- tipo y permisos;
- inode y cantidad de enlaces;
- propietario y grupo;
- tamano y tiempos;
- hash SHA-256 del contenido.

El orden conceptual es:

```text
1. Configurar AIDE.
2. Crear la base inicial.
3. Crear o modificar archivos y cambiar permisos.
4. Ejecutar la comprobacion.
5. Interpretar las diferencias informadas.
```

AIDE puede indicar que un archivo es nuevo, que cambio su contenido o que
cambiaron sus metadatos. No explica por si solo que proceso o usuario produjo
el cambio. Esa informacion se complementa con `auditd`.

Una limitacion importante es que una base almacenada en la misma maquina puede
ser alterada junto con los archivos protegidos si un atacante obtiene
privilegios suficientes. Una base protegida externamente ofrece una referencia
mas confiable.

## Diferencias entre las herramientas

| Herramienta | Pregunta que ayuda a responder |
| --- | --- |
| `strace` | Que syscalls realizo esta ejecucion concreta? |
| `auditd` | Que actividad seleccionada quedo registrada para consultar despues? |
| AIDE | Que archivos o atributos difieren de la linea base? |

Ejemplo de interpretacion conjunta:

```text
strace muestra que tp2-event abrio y escribio eventos.log.
auditd conserva la ejecucion y la modificacion bajo sus claves.
AIDE detecta que eventos.log ya no coincide con la linea base.
```

## Relacion con AppArmor

El punto 9 puede realizarse sin haber completado el punto 8. El perfil de
AppArmor del punto 8 se aplica a `tp2-reader`, mientras que la correlacion del
punto 9 usa principalmente `tp2-event`.

La dependencia aparece en el escenario integrador del punto 10, que requiere
simultaneamente AppArmor en modo `enforce`, las reglas de auditd cargadas y la
base de AIDE activa.
