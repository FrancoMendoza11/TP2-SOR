# Endurecimiento de SSH

> **Alcance:** bloqueo del acceso remoto directo de `root` y validación segura de OpenSSH.
>
> **Cuándo leerlo:** al revisar el control SSH del script de endurecimiento o sus comprobaciones.
>
> **Prerrequisitos:** el [resumen de endurecimiento](./20-mapa-de-endurecimiento.md); para el comportamiento compartido del script, consultá [su arquitectura](./25-script-de-endurecimiento.md).

## Documentos relacionados

- [Endurecimiento: requisitos y mapa local](./20-mapa-de-endurecimiento.md)
- [Arquitectura del script y funciones auxiliares](./25-script-de-endurecimiento.md)
- [Entorno y flujo de trabajo](./11-entorno-y-flujo-de-trabajo.md)

## Conceptos SSH

### `PermitRootLogin no`

Es una directiva del servidor OpenSSH (`sshd`) que impide iniciar sesión
directamente como el usuario `root` mediante SSH, incluso usando una clave
válida.

No deshabilita la cuenta `root` en todo el sistema, no impide el acceso por la
consola de la VM y no impide que un usuario autorizado inicie sesión y luego
use `sudo`.

### Prefijo `99-`

Los archivos dentro de `sshd_config.d` se incluyen siguiendo un orden
lexicográfico. El número `99` es una convención para ubicar una política local
cerca del final de los fragmentos, después de configuraciones con números más
bajos.

Por ejemplo:

```text
/etc/ssh/sshd_config.d/99-tp2-hardening.conf
```

El número no es obligatorio ni garantiza por sí solo que la directiva gane:
OpenSSH normalmente usa el primer valor encontrado para cada opción. Por eso
revisá siempre el resultado efectivo con `sshd -T`.

### `sshd -t`

Es una comprobación de sintaxis y validez de la configuración del servidor
SSH. No inicia ni recarga el servicio.

Se ejecuta antes de recargar SSH para evitar dejar el servicio con una
configuración inválida:

```bash
sudo sshd -t
```

Código de salida `0` significa que la configuración es válida. Si devuelve un
error, no se debe recargar el servicio.

Para consultar la configuración efectiva se utiliza:

```bash
sudo sshd -T | grep -i '^permitrootlogin'
```
## Implementación del control `control_ssh`

Se implementó el bloqueo del acceso remoto directo de `root` mediante
`PermitRootLogin no`.

### Modo `--check`

- Verifica el contenido del fragmento.
- En una ejecución real, el control valida la sintaxis global con `sshd -t`.
- Consulta con `sshd -T` que el valor efectivo sea `no`.
- En una prueba con `TP2_ROOT` limita la comprobación al fragmento ficticio.

### Modo `--apply`

- Si el archivo y la configuración efectiva ya son correctos, registra
  `SKIPPED`; esto hace que el control sea idempotente.
- Si hace falta un cambio, respalda el estado anterior y escribe el fragmento.
- Valida la sintaxis y la configuración efectiva antes de recargar SSH.
- Recarga el servicio solamente después de superar las validaciones.
- Si la validación o la recarga falla, restaura silenciosamente el archivo
  anterior y registra `ERROR`.

### Modo `--restore`

- Restaura el respaldo original o elimina el fragmento si antes no existía.
- Si había un respaldo registrado y se trabaja sobre el sistema real, valida la
  configuración restaurada y recarga SSH.
- Informa un error si el archivo pudo restaurarse pero no pudo validarse o
  recargarse.

## Leer a continuación

- [Implementación general del script](./25-script-de-endurecimiento.md)
- [Ejecución y comprobaciones del proyecto](./11-entorno-y-flujo-de-trabajo.md)
