# Implementación del script de endurecimiento

> **Alcance:** la estructura, las funciones auxiliares y el comportamiento transversal del script de endurecimiento.
>
> **Cuándo leerlo:** cuando necesites entender respaldos, idempotencia, reversión, registro o el flujo completo de `hardening.sh`.
>
> **Prerrequisitos:** el [resumen de endurecimiento](./20-mapa-de-endurecimiento.md); para un control concreto, empezá por su nota específica.

## Documentos relacionados

- [Endurecimiento: requisitos y mapa local](./20-mapa-de-endurecimiento.md)
- [SSH](./21-endurecimiento-ssh.md)
- [Calidad de contraseñas](./22-calidad-de-contrasenas.md)
- [Umask de sesión](./23-umask-de-sesion.md)
- [Protecciones con sysctl](./24-protecciones-del-nucleo-con-sysctl.md)

## Alcance de la comparación

Este documento explica qué se implementó en
`codigo_base/hardening/hardening.sh` a partir de los TODO de la plantilla
original `codigo_base/hardening/hardening_base.sh`.

En el estado actual del repositorio ambos archivos tienen el mismo contenido,
porque la plantilla también fue modificada. Para identificar el trabajo
realizado se comparó `hardening.sh` con la versión original de
`hardening_base.sh`, guardada en la revisión inicial del repositorio (`d2c4ef6`).

La plantilla original ya incluía:

- validación del modo de ejecución y del usuario efectivo;
- soporte de `TP2_ROOT` para pruebas sobre una raíz ficticia;
- registro de eventos y contadores;
- funciones para respaldar, restaurar y escribir archivos;
- el control de cuentas adicionales con UID 0;
- cuatro funciones pendientes: `control_ssh`, `control_pwquality`,
  `control_umask` y `control_sysctl`.

La implementación completó esos cuatro controles y agregó los auxiliares
necesarios para validarlos y aplicarlos de forma segura e idempotente.

## Configuraciones agregadas

### Qué es un fragmento de configuración

Un fragmento es un archivo pequeño que contiene solamente una parte de la
configuración total de un programa o del sistema. En lugar de modificar un
archivo principal grande, se agrega un archivo dentro de un directorio que el
programa sabe recorrer e incluir.

Por ejemplo, `/etc/profile.d/99-tp2-hardening.sh` es un fragmento. Contiene:

```bash
# Configuración TP2 para nuevas sesiones.
umask 027
```

Cuando una sesión carga `/etc/profile`, este incorpora los archivos `*.sh` de
`/etc/profile.d/`. La configuración resultante combina el archivo principal con
los fragmentos aplicables.

Separar la configuración de esta manera permite:

- evitar modificaciones directas sobre archivos principales;
- identificar y auditar fácilmente lo agregado por el TP;
- revertir un cambio restaurando o eliminando un solo archivo;
- reducir conflictos con archivos administrados por paquetes;
- comprobar si el estado deseado ya existe y mantener la idempotencia.

El prefijo `99-` hace que el archivo se ubique cerca del final cuando los
fragmentos se procesan en orden lexicográfico. Esto no garantiza por sí solo que
una opción prevalezca: cada programa define sus propias reglas de precedencia.
Por ejemplo, OpenSSH puede conservar el primer valor encontrado para una
directiva, por lo que su resultado efectivo se comprueba con `sshd -T`.

Se definieron cuatro archivos de configuración independientes:

| Control | Archivo | Contenido aplicado |
| --- | --- | --- |
| SSH | `/etc/ssh/sshd_config.d/99-tp2-hardening.conf` | `PermitRootLogin no` |
| Calidad de contraseñas | `/etc/security/pwquality.conf.d/99-tp2-hardening.conf` | `minlen = 12`, `minclass = 3`, `maxrepeat = 3` |
| Umask | `/etc/profile.d/99-tp2-hardening.sh` | `umask 027` |
| Enlaces protegidos | `/etc/sysctl.d/99-tp2-hardening.conf` | `fs.protected_hardlinks = 1` y `fs.protected_symlinks = 1` |

El uso de fragmentos separados evita editar directamente los archivos
principales de cada servicio y permite retirar solamente los cambios del TP.
Todos se escriben con permisos `0644` mediante la función `write_file` que ya
estaba en la plantilla.

## Funciones auxiliares implementadas

### `restore_file_silent`

Restaura un archivo desde el estado guardado por `backup_file`, pero no modifica
contadores ni genera entradas de registro. Se utiliza como reversión interna cuando
una aplicación falla antes de poder considerarse exitosa.

- Si el archivo existía, copia nuevamente su respaldo.
- Si no existía, elimina el archivo creado por el script.
- Si no hay estado registrado, devuelve error.

Esto evita informar un `RESTORE` solicitado por el usuario cuando en realidad
se está deshaciendo automáticamente una operación fallida.

### `backup_registered`

Comprueba si existe alguno de los marcadores `.existed` o `.absent` que crea
`backup_file`. Los controles SSH y sysctl lo usan durante `--restore` para saber
si realmente hubo un estado previo que restaurar antes de validar o recargar el
servicio correspondiente.

### `ssh_fragment_matches`

Verifica que el fragmento de SSH exista y contenga una directiva activa
`PermitRootLogin no`. Ignora comentarios y falla si no encuentra la directiva o
si encuentra alguna aparición con otro valor.

Esta comprobación analiza el archivo administrado por el script. No reemplaza
la consulta de la configuración efectiva de OpenSSH.

### `sshd_effective_matches`

Ejecuta `sshd -T`, extrae el valor efectivo de `permitrootlogin` y confirma que
sea `no`. De esta manera detecta si otro fragmento, el orden de lectura o la
configuración principal impiden que la política tenga efecto.

En pruebas aisladas con `TP2_ROOT` no interactúa con los servicios del sistema anfitrión y
devuelve éxito; en ese modo solamente se valida el archivo ficticio.

### `sshd_syntax_valid`

Comprueba primero que exista el comando `sshd` y luego ejecuta `sshd -t` para
validar la sintaxis completa antes de recargar el servicio. Al usar `TP2_ROOT`
omite esta operación para no evaluar la configuración real del equipo donde se
ejecutan las pruebas.

### `validate_sshd_configuration`

Agrupa las dos condiciones necesarias para aceptar la configuración SSH:

1. `sshd -t` debe indicar que la sintaxis es válida.
2. `sshd -T` debe confirmar que `PermitRootLogin` vale efectivamente `no`.

### `reload_sshd`

Recarga OpenSSH mediante `systemctl`. Primero intenta la unidad
`ssh.service` y, como alternativa, `ssh`. No reinicia el servicio, por lo que
las conexiones existentes no se interrumpen de la misma forma que con un
reinicio completo.

La función también evita operar sobre el sistema anfitrión cuando está definido
`TP2_ROOT`.

### `pam_pwquality_active`

Recorre los archivos regulares de `/etc/pam.d` y busca una referencia activa a
`pam_pwquality.so`, ignorando comentarios. La política de `pwquality.conf.d`
solo se considera útil si PAM carga ese módulo.

Si el directorio no existe o ningún archivo activa el módulo, devuelve error.

### `pwquality_setting_is`

Es un validador genérico de asignaciones `clave = valor` en un archivo de
`pwquality`. Ignora líneas comentadas, espacios y comentarios al final del
valor. Devuelve éxito solamente si encuentra la clave esperada y todas sus
apariciones tienen el valor pedido.

### `pwquality_fragment_matches`

Usa `pwquality_setting_is` para exigir simultáneamente:

- `minlen = 12`: longitud mínima de doce caracteres;
- `minclass = 3`: al menos tres clases de caracteres;
- `maxrepeat = 3`: no más de tres caracteres iguales consecutivos.

### `umask_fragment_matches`

Realiza tres niveles de validación sobre el fragmento de `profile.d`:

1. Comprueba que el archivo exista.
2. Ejecuta `bash -n` y busca una instrucción activa `umask 027`.
3. Carga el archivo en un Bash aislado, partiendo de `umask 022`, y verifica que
   el resultado sea realmente `027` o su representación `0027`.

La última prueba evita aceptar un archivo que contiene el texto esperado pero
que no produce la máscara final requerida.

### `sysctl_setting_is`

Valida una asignación `clave = valor` dentro de un archivo de sysctl. Ignora
comentarios y espacios, y rechaza el archivo si la clave falta o aparece con un
valor distinto del esperado.

### `sysctl_fragment_matches`

Confirma que el fragmento persistente defina ambos controles con valor `1`:

- `fs.protected_hardlinks`;
- `fs.protected_symlinks`.

### `sysctl_effective_matches`

Consulta mediante `sysctl -n` los valores que están activos en el núcleo y
exige que ambos sean `1`. Esto diferencia entre tener una configuración
persistente correcta y tenerla efectivamente cargada.

Con `TP2_ROOT` no consulta el núcleo del equipo anfitrión y devuelve éxito, porque la prueba
aislada solo representa un árbol de archivos.

### `apply_sysctl_fragment`

Carga exclusivamente el fragmento administrado por el TP mediante
`sysctl -p <archivo>`. Luego `control_sysctl` vuelve a consultar los valores
efectivos, por lo que el éxito del comando no se toma como verificación
suficiente.

## Controles detallados

- [SSH](./21-endurecimiento-ssh.md)
- [Calidad de contraseñas y PAM](./22-calidad-de-contrasenas.md)
- [Umask de sesión](./23-umask-de-sesion.md)
- [Protecciones con sysctl](./24-protecciones-del-nucleo-con-sysctl.md)

## Idempotencia y recuperación ante errores

La segunda ejecución de `--apply` no vuelve a escribir configuraciones que ya
coinciden. Cada control compara primero el estado deseado y registra `SKIPPED`
cuando no hay cambios pendientes.

Los respaldos se crean una sola vez. De esta manera, las ejecuciones posteriores no
sobrescriben el estado original con una versión ya endurecida. Los marcadores
del directorio de estado permiten distinguir entre dos casos:

- el archivo existía y debe recuperarse desde `.backup`;
- el archivo no existía y debe eliminarse al restaurar.

SSH y sysctl agregan una reversión inmediata: si no pueden validar o activar una
configuración que acaban de escribir, restauran el archivo original antes de
informar el error.

## Flujo final del script

El orden de ejecución quedó definido así:

1. `control_uid0`, que ya estaba implementado en la plantilla.
2. `control_ssh`.
3. `control_pwquality`.
4. `control_umask`.
5. `control_sysctl`.

Al finalizar se registra un resumen con acciones aplicadas, omitidas,
verificadas y errores. Si hubo al menos un error, el script termina con código
de salida `1`; de lo contrario termina correctamente.

## Observación sobre la plantilla

La consigna indica que `hardening_base.sh` debe conservarse sin cambios y que
la solución debe guardarse en `hardening.sh`. Actualmente la plantilla del
repositorio contiene la misma implementación que el entregable. Esto no cambia
el funcionamiento de `hardening.sh`, pero elimina los TODO que debían quedar
como referencia en el archivo base.

## Leer a continuación

- [Endurecimiento: requisitos y mapa local](./20-mapa-de-endurecimiento.md)
- [Flujo y verificaciones del proyecto](./11-entorno-y-flujo-de-trabajo.md)
