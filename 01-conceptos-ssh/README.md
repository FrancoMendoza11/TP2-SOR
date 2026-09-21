# Conceptos SSH — TODO 1

## `PermitRootLogin no`

Es una directiva del servidor OpenSSH (`sshd`) que impide iniciar sesión
directamente como el usuario `root` mediante SSH, incluso usando una clave
válida.

No deshabilita la cuenta `root` en todo el sistema, no impide el acceso por la
consola de la VM y no impide que un usuario autorizado inicie sesión y luego
use `sudo`.

## Prefijo `99-`

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
siempre hay que revisar el resultado efectivo con `sshd -T`.

## `sshd -t`

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
