# Umask de sesión

> **Alcance:** la máscara `umask 027`, su alcance sobre nuevas sesiones y el control del script.
>
> **Cuándo leerlo:** cuando necesites entender cuándo toma efecto la máscara y cómo demostrarlo.
>
> **Prerrequisitos:** el [resumen de endurecimiento](./20-mapa-de-endurecimiento.md).

## Documentos relacionados

- [Endurecimiento: requisitos y mapa local](./20-mapa-de-endurecimiento.md)
- [Arquitectura del script y funciones auxiliares](./25-script-de-endurecimiento.md)

## Implementación del control

Se implementó `umask 027` para sesiones nuevas mediante un script en
`/etc/profile.d`.

Con esta máscara, los archivos parten normalmente de permisos `640` y los
directorios de `750`: el propietario conserva acceso, el grupo pierde escritura
y otros usuarios no reciben permisos.

### Cuándo toma efecto la nueva máscara

El fragmento `/etc/profile.d/99-tp2-hardening.sh` toma efecto cuando una nueva
sesión del intérprete de comandos carga `/etc/profile` y este, a su vez, carga
los fragmentos de `/etc/profile.d/`. Esto suele ocurrir al iniciar sesión por
SSH o por consola, o al iniciar una `shell` de ingreso.

La máscara pertenece a cada proceso y es heredada por sus procesos hijos. No es
una configuración global que cambie inmediatamente todos los procesos del
sistema. Por eso:

- las sesiones que ya estaban abiertas conservan su umask anterior;
- los servicios de systemd y los procesos que no cargan `/etc/profile` pueden
  tener otra umask;
- una nueva sesión que cargue el fragmento usará `027` para sus creaciones
  posteriores.

### Alcance sobre archivos y directorios

La umask no modifica permisos existentes. Solamente limita los permisos
iniciales de archivos y directorios creados después de que el proceso adopta la
máscara.

La operación conceptual es:

```text
permisos finales = permisos solicitados Y (NO umask)
```

Un archivo creado normalmente a partir de `666` queda con `640` al aplicar
`027`:

```text
rw-r-----
```

Un directorio creado normalmente a partir de `777` queda con `750`:

```text
rwxr-x---
```

La máscara quita permisos, pero no agrega permisos que el programa no haya
solicitado. Tampoco impide cambiar posteriormente los permisos mediante
`chmod`.

### Contenido y función de `/etc/profile.d/`

`/etc/profile.d/` contiene fragmentos de configuración que se cargan en las
sesiones del intérprete de comandos.
Habitualmente `/etc/profile` recorre los archivos `*.sh` del directorio y los
carga dentro de la sesión. Pueden definir variables de entorno, modificar
`PATH`, establecer configuración regional, declarar funciones o configurar una
umask.

Estos archivos no son servicios y no se ejecutan automáticamente durante el
arranque. Se interpretan cuando una sesión compatible carga `/etc/profile`.

El fragmento agregado por el TP contiene:

```bash
# Configuración TP2 para nuevas sesiones.
umask 027
```

El prefijo `99-` busca que se procese cerca del final del orden alfabético. Sin
embargo, otro fragmento cargado posteriormente todavía podría cambiar la umask.

### Idempotencia y registro de `SKIPPED`

En este contexto, ser idempotente significa que ejecutar `--apply` varias veces
produce el mismo estado final y no acumula cambios repetidos.

En la primera ejecución, el control crea el fragmento si hace falta. En las
ejecuciones siguientes, `umask_fragment_matches` comprueba que el archivo
exista, tenga sintaxis válida, declare `umask 027` y produzca efectivamente esa
máscara. Si todo coincide, no vuelve a escribir el archivo ni crea otro
respaldo: llama a `mark_skipped`.

El resultado se muestra en la terminal y se agrega, mediante `tee -a`, al registro
predeterminado:

```text
/var/log/tp2-hardening.log
```

Una entrada esperable es:

```text
2026-09-21T23:10:00+00:00 [SKIPPED] [UMASK] El fragmento ya configura umask 027
```

Puede consultarse, por ejemplo, con:

```bash
sudo grep '\[SKIPPED\]' /var/log/tp2-hardening.log
```

En pruebas aisladas, la variable `TP2_LOG_FILE` permite utilizar otro archivo
de registro.

### Modo `--check`

Comprueba existencia, sintaxis, directiva declarada y resultado efectivo del
fragmento. Si cualquiera de esas validaciones falla, registra `ERROR`.

### Modo `--apply`

- Si el fragmento ya produce `umask 027`, registra `SKIPPED`.
- Si no coincide, respalda el estado anterior y escribe el fragmento.
- El cambio afecta a nuevas sesiones que carguen `/etc/profile.d`; no modifica
  retroactivamente la máscara de procesos ya iniciados.

### Modo `--restore`

Restaura o elimina el fragmento mediante `restore_file`.

## Leer a continuación

- [Arquitectura del script](./25-script-de-endurecimiento.md)
- [Flujo del proyecto](./11-entorno-y-flujo-de-trabajo.md)
