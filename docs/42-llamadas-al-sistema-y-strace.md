# Llamadas al sistema y strace

> **Alcance:** qué llamadas al sistema realiza `tp2-event` y cómo observar una ejecución concreta con strace.
>
> **Cuándo leerlo:** cuando necesites interpretar `execve`, `openat` o `write` y preparar la evidencia de una ejecución.
>
> **Prerrequisitos:** el [resumen de auditoría e integridad](./40-mapa-de-auditoria-e-integridad.md); no hace falta conocer los detalles internos del núcleo.

## Documentos relacionados

- [Resumen de auditoría e integridad](./40-mapa-de-auditoria-e-integridad.md)
- [Reglas auditd](./41-reglas-y-consultas-de-auditd.md)
- [Correlación de evidencia](./44-correlacion-de-evidencias.md)

## Qué es `tp2-event`

`tp2-event` es un programa pequeño en C provisto por la cátedra. Su código está
en `codigo_base/src/tp2_event.c` y se instala como:

```text
/usr/local/bin/tp2-event
```

Al ejecutarlo con un mensaje:

```bash
/usr/local/bin/tp2-event "evento_grupo_N"
```

abre `/srv/tp2/datos/eventos.log` en modo agregar y escribe una línea que
incluye:

- fecha y hora;
- PID del proceso;
- UID del usuario;
- mensaje recibido como argumento.

No es una herramienta ofensiva ni una utilidad propia de Ubuntu. Es una
aplicación controlada que produce operaciones conocidas para poder observarlas
con `strace`, `auditd` y AIDE.

## Aplicación, biblioteca y núcleo

Un programa de usuario no accede directamente al disco. Solicita servicios al
núcleo mediante llamadas al sistema.

El código de `tp2-event` usa funciones de la biblioteca C como `fopen`,
`fprintf` y `fclose`. Internamente, la biblioteca termina realizando llamadas
al sistema como `openat`, `write` y `close`.

El flujo simplificado es:

```text
terminal
  -> execve("/usr/local/bin/tp2-event", ...)
       -> openat(..., "/srv/tp2/datos/eventos.log", ...)
            -> write(descriptor, "fecha pid uid mensaje...", ...)
                 -> close(descriptor)
```

Las tres llamadas al sistema destacadas en la consigna son:

| Llamada al sistema | Solicitud realizada al núcleo |
| --- | --- |
| `execve` | Cargar y ejecutar un programa. |
| `openat` | Abrir un archivo y devolver un descriptor. |
| `write` | Escribir bytes mediante un descriptor abierto. |

Un descriptor es un número que el núcleo entrega al proceso para representar
un recurso abierto. Por ejemplo, si `openat` devuelve `3`, las escrituras
posteriores sobre el archivo pueden aparecer como `write(3, ...)`.

## Qué observa `strace`

`strace` acompaña una ejecución concreta y muestra las llamadas al sistema que
realiza el proceso. En el punto 9.2 se usa al ejecutar `tp2-event`:

```bash
sudo strace -f -e trace=execve,openat,write \
  -o /srv/tp2/evidencias/strace_tp2_event.txt \
  /usr/local/bin/tp2-event "evento_grupo_N"
```

Las opciones cumplen estas funciones:

- `-f`: sigue también los procesos hijos.
- `-e trace=...`: limita la salida a las llamadas al sistema indicadas.
- `-o`: guarda el resultado en un archivo de evidencia.

La opción `-e` necesita una expresión; `strace -f -e` por sí solo queda
incompleto. En este caso, `trace=execve,openat,write` solicita observar
solamente esas tres llamadas al sistema. La opción `-f` sirve para seguir los
procesos hijos. También permite seguir los procesos que lance un script, aunque
`strace` muestra las llamadas al sistema del intérprete y de esos programas, no
la lógica del script (variables, `if` o bucles) como texto.

Una salida simplificada puede tener esta forma:

```text
execve("/usr/local/bin/tp2-event", [...], [...]) = 0
openat(AT_FDCWD, "/srv/tp2/datos/eventos.log", ...) = 3
write(3, "2026-09-21... mensaje=evento_grupo_N", ...) = 63
```

El valor ubicado después de `=` es el resultado de la llamada al sistema:

- `execve(...) = 0`: la ejecución fue exitosa.
- `openat(...) = 3`: el núcleo devolvió el descriptor `3`.
- `write(...) = 63`: se escribieron 63 bytes.
- un valor `-1` indica un error e incluye normalmente su código simbólico.

`strace` sirve para analizar esa ejecución mientras sucede. No funciona como un
registro histórico general del sistema.

## Leer a continuación

- [Reglas auditd](./41-reglas-y-consultas-de-auditd.md)
- [Correlación de evidencia](./44-correlacion-de-evidencias.md)
