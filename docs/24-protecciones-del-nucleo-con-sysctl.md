# Protecciones del núcleo con sysctl

> **Alcance:** las protecciones de enlaces duros y simbólicos configuradas mediante sysctl.
>
> **Cuándo leerlo:** cuando revises persistencia, carga o verificación de los valores efectivos del núcleo.
>
> **Prerrequisitos:** el [resumen de endurecimiento](./20-mapa-de-endurecimiento.md).

## Documentos relacionados

- [Endurecimiento: requisitos y mapa local](./20-mapa-de-endurecimiento.md)
- [Arquitectura del script y funciones auxiliares](./25-script-de-endurecimiento.md)

## Implementación del control

Se implementaron protecciones del núcleo frente a ciertos usos abusivos de enlaces
duros y simbólicos en directorios compartidos o escribibles por otros usuarios.

### Contenido y carga de `/etc/sysctl.d/`

`/etc/sysctl.d/` contiene fragmentos declarativos con parámetros del núcleo en
forma de asignaciones `clave = valor`. Es similar a `/etc/profile.d/` en que
permite separar la configuración en archivos pequeños, pero sus archivos no son
scripts de intérprete de comandos.

Durante el arranque, herramientas como `systemd-sysctl` procesan normalmente
configuraciones ubicadas en varios directorios:

```text
/usr/lib/sysctl.d/
/usr/local/lib/sysctl.d/
/run/sysctl.d/
/etc/sysctl.d/
```

También existe el archivo tradicional `/etc/sysctl.conf`. Las reglas exactas de
lectura y precedencia dependen de la herramienta utilizada, de los directorios
y del nombre de cada archivo. `/etc/sysctl.d/` se reserva normalmente para la
configuración local del administrador y el prefijo `99-` ubica el fragmento
cerca del final del orden lexicográfico.

Los fragmentos no se cargan "desde otro directorio". El servicio o la
herramienta recorre los directorios reconocidos, interpreta sus asignaciones y
las aplica al núcleo.

### Significado del prefijo `fs`

En estas claves, `fs` identifica los parámetros del sistema de archivos. sysctl
organiza los parámetros del núcleo por categorías como `kernel.*`, `net.*`,
`vm.*` y `fs.*`.

### Protección de enlaces duros

`fs.protected_hardlinks = 1` restringe la creación de enlaces duros hacia
archivos de otros usuarios. Un enlace duro es otro nombre que apunta al mismo
`inode` y al mismo contenido que un archivo existente.

Con la protección activa, el núcleo impide determinados enlaces cuando el
usuario no es propietario del archivo original, no tiene los accesos requeridos
o no posee una capacidad privilegiada que permita omitir la restricción. Esto
reduce ataques contra archivos sensibles y ciertas condiciones de carrera,
especialmente en directorios compartidos.

La opción no deshabilita todos los enlaces duros: un usuario puede seguir
creándolos sobre sus propios archivos cuando los permisos y el sistema de
archivos lo permiten.

### Protección de enlaces simbólicos

`fs.protected_symlinks = 1` restringe el seguimiento inseguro de enlaces
simbólicos dentro de directorios compartidos que tienen el bit `sticky`, como `/tmp`.

Un atacante podría crear un enlace simbólico que apunte a un archivo sensible y
esperar que un proceso privilegiado lo abra creyendo que es un archivo normal.
La protección toma en cuenta los propietarios del proceso, del enlace y del
directorio para bloquear determinados seguimientos peligrosos.

La opción no deshabilita los enlaces simbólicos. Solo restringe situaciones
que podrían permitir que un proceso acceda o modifique un archivo ajeno a través
de un enlace preparado por otro usuario.

### Aplicación mediante `sysctl -p`

`sysctl -p` lee asignaciones desde un archivo y las aplica inmediatamente al
núcleo en ejecución. Sin una ruta explícita suele cargar `/etc/sysctl.conf`:

```bash
sudo sysctl -p
```

El control indica expresamente su fragmento:

```bash
sudo sysctl -p /etc/sysctl.d/99-tp2-hardening.conf
```

Esto permite activar los valores sin esperar al siguiente arranque. El comando
no proporciona persistencia por sí mismo: la persistencia surge de conservar el
archivo en un directorio que se procesa nuevamente al arrancar.

### Archivo correcto y valores efectivos

Para el script, el archivo persistente es correcto cuando existe
`/etc/sysctl.d/99-tp2-hardening.conf` y contiene activamente:

```text
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
```

`sysctl_fragment_matches` comprueba ambas asignaciones con
`sysctl_setting_is`. La validación ignora comentarios y diferencias de espacios,
pero exige que las claves existan y no aparezcan con un valor distinto. Una
línea comentada no satisface la comprobación.

Esto representa el estado persistente deseado, pero no demuestra que el núcleo
ya lo esté usando. Los valores efectivos son los que se encuentran activos en
la memoria del núcleo en ese momento. El script los consulta mediante:

```bash
sysctl -n fs.protected_hardlinks
sysctl -n fs.protected_symlinks
```

Esos valores también están expuestos en el sistema virtual `/proc`:

```text
/proc/sys/fs/protected_hardlinks
/proc/sys/fs/protected_symlinks
```

El archivo y los valores efectivos pueden diferir si el fragmento aún no se
cargó, otra configuración o un comando cambió posteriormente el núcleo, o la
aplicación falló. Por eso el control comprueba por separado:

1. El estado persistente del fragmento.
2. El estado efectivo del núcleo.

### Idempotencia del control

El estado final buscado es que el fragmento sea correcto y que los dos valores
efectivos sean `1`. Si el archivo ya coincide, el script no lo vuelve a escribir
ni genera otro respaldo. Aun así, ejecuta `sysctl -p` para asegurar que la
configuración esté cargada y después consulta el núcleo.

Cuando ambos estados ya son correctos, registra:

```text
[SKIPPED] [SYSCTL] El archivo y los valores efectivos ya son correctos
```

Volver a ejecutar `--apply` no acumula líneas, archivos ni respaldos y conserva
el mismo estado final. En ese sentido, el control es idempotente.

### Modo `--check`

- Verifica que el fragmento persistente contenga los dos valores requeridos.
- En el sistema real también consulta los valores activos del núcleo.
- En modo aislado solo valida el archivo bajo `TP2_ROOT`.

### Modo `--apply`

- Escribe y respalda el fragmento solamente si su contenido no coincide.
- Ejecuta `sysctl -p` incluso cuando el archivo ya era correcto, para asegurar
  que los valores estén cargados.
- Comprueba después los valores efectivos del núcleo.
- Si se creó o reemplazó el fragmento y la aplicación falla, restaura el archivo
  anterior.
- Registra `APPLIED` cuando cambió el archivo y `SKIPPED` cuando tanto el
  archivo como el estado efectivo ya eran correctos.

### Modo `--restore`

- Restaura el estado anterior del fragmento.
- Si había un archivo previo y fue restaurado en el sistema real, ejecuta
  `sysctl -p` sobre ese archivo para volver a aplicar sus valores.
- Si antes no existía, elimina el fragmento. No intenta inventar valores de
  núcleo anteriores que no hayan quedado representados en un archivo.

## Leer a continuación

- [Arquitectura del script](./25-script-de-endurecimiento.md)
- [Auditoría e integridad](./40-mapa-de-auditoria-e-integridad.md)
