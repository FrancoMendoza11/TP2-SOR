# Implementacion del script de hardening

## Alcance de la comparacion

Este documento explica que se implemento en
`codigo_base/hardening/hardening.sh` a partir de los TODO de la plantilla
original `codigo_base/hardening/hardening_base.sh`.

En el estado actual del repositorio ambos archivos tienen el mismo contenido,
porque la plantilla tambien fue modificada. Para identificar el trabajo
realizado se comparo `hardening.sh` con la version original de
`hardening_base.sh` guardada en el commit inicial `d2c4ef6`.

La plantilla original ya incluia:

- validacion del modo de ejecucion y del usuario efectivo;
- soporte de `TP2_ROOT` para pruebas sobre una raiz ficticia;
- registro de eventos y contadores;
- funciones para respaldar, restaurar y escribir archivos;
- el control de cuentas adicionales con UID 0;
- cuatro funciones pendientes: `control_ssh`, `control_pwquality`,
  `control_umask` y `control_sysctl`.

La implementacion completo esos cuatro controles y agrego los auxiliares
necesarios para validarlos y aplicarlos de forma segura e idempotente.

## Configuraciones agregadas

### Que es un fragmento de configuracion

Un fragmento es un archivo pequeno que contiene solamente una parte de la
configuracion total de un programa o del sistema. En lugar de modificar un
archivo principal grande, se agrega un archivo dentro de un directorio que el
programa sabe recorrer e incluir.

Por ejemplo, `/etc/profile.d/99-tp2-hardening.sh` es un fragmento. Contiene:

```bash
# Configuracion TP2 para nuevas sesiones.
umask 027
```

Cuando una sesion carga `/etc/profile`, este incorpora los archivos `*.sh` de
`/etc/profile.d/`. La configuracion resultante combina el archivo principal con
los fragmentos aplicables.

Separar la configuracion de esta manera permite:

- evitar modificaciones directas sobre archivos principales;
- identificar y auditar facilmente lo agregado por el TP;
- revertir un cambio restaurando o eliminando un solo archivo;
- reducir conflictos con archivos administrados por paquetes;
- comprobar si el estado deseado ya existe y mantener la idempotencia.

El prefijo `99-` hace que el archivo se ubique cerca del final cuando los
fragmentos se procesan en orden lexicografico. Esto no garantiza por si solo que
una opcion prevalezca: cada programa define sus propias reglas de precedencia.
Por ejemplo, OpenSSH puede conservar el primer valor encontrado para una
directiva, por lo que su resultado efectivo se comprueba con `sshd -T`.

Se definieron cuatro archivos de configuracion independientes:

| Control | Archivo | Contenido aplicado |
| --- | --- | --- |
| SSH | `/etc/ssh/sshd_config.d/99-tp2-hardening.conf` | `PermitRootLogin no` |
| Calidad de contrasenas | `/etc/security/pwquality.conf.d/99-tp2-hardening.conf` | `minlen = 12`, `minclass = 3`, `maxrepeat = 3` |
| Umask | `/etc/profile.d/99-tp2-hardening.sh` | `umask 027` |
| Enlaces protegidos | `/etc/sysctl.d/99-tp2-hardening.conf` | `fs.protected_hardlinks = 1` y `fs.protected_symlinks = 1` |

El uso de fragmentos separados evita editar directamente los archivos
principales de cada servicio y permite retirar solamente los cambios del TP.
Todos se escriben con permisos `0644` mediante la funcion `write_file` que ya
estaba en la plantilla.

## Funciones auxiliares implementadas

### `restore_file_silent`

Restaura un archivo desde el estado guardado por `backup_file`, pero no modifica
contadores ni genera entradas de log. Se utiliza como rollback interno cuando
una aplicacion falla antes de poder considerarse exitosa.

- Si el archivo existia, copia nuevamente su respaldo.
- Si no existia, elimina el archivo creado por el script.
- Si no hay estado registrado, devuelve error.

Esto evita informar un `RESTORE` solicitado por el usuario cuando en realidad
se esta deshaciendo automaticamente una operacion fallida.

### `backup_registered`

Comprueba si existe alguno de los marcadores `.existed` o `.absent` que crea
`backup_file`. Los controles SSH y SYSCTL lo usan durante `--restore` para saber
si realmente hubo un estado previo que restaurar antes de validar o recargar el
servicio correspondiente.

### `ssh_fragment_matches`

Verifica que el fragmento de SSH exista y contenga una directiva activa
`PermitRootLogin no`. Ignora comentarios y falla si no encuentra la directiva o
si encuentra alguna aparicion con otro valor.

Esta comprobacion analiza el archivo administrado por el script. No reemplaza
la consulta de la configuracion efectiva de OpenSSH.

### `sshd_effective_matches`

Ejecuta `sshd -T`, extrae el valor efectivo de `permitrootlogin` y confirma que
sea `no`. De esta manera detecta si otro fragmento, el orden de lectura o la
configuracion principal impiden que la politica tenga efecto.

En pruebas aisladas con `TP2_ROOT` no ejecuta el demonio del sistema anfitrion y
devuelve exito; en ese modo solamente se valida el archivo ficticio.

### `sshd_syntax_valid`

Comprueba primero que exista el comando `sshd` y luego ejecuta `sshd -t` para
validar la sintaxis completa antes de recargar el servicio. Al usar `TP2_ROOT`
omite esta operacion para no evaluar la configuracion real del equipo donde se
ejecutan las pruebas.

### `validate_sshd_configuration`

Agrupa las dos condiciones necesarias para aceptar la configuracion SSH:

1. `sshd -t` debe indicar que la sintaxis es valida.
2. `sshd -T` debe confirmar que `PermitRootLogin` vale efectivamente `no`.

### `reload_sshd`

Recarga OpenSSH mediante `systemctl`. Primero intenta la unidad
`ssh.service` y, como alternativa, `ssh`. No reinicia el servicio, por lo que
las conexiones existentes no se interrumpen de la misma forma que con un
reinicio completo.

La funcion tambien evita operar sobre el sistema anfitrion cuando esta definido
`TP2_ROOT`.

### `pam_pwquality_active`

Recorre los archivos regulares de `/etc/pam.d` y busca una referencia activa a
`pam_pwquality.so`, ignorando comentarios. La politica de `pwquality.conf.d`
solo se considera util si PAM carga ese modulo.

Si el directorio no existe o ningun archivo activa el modulo, devuelve error.

### `pwquality_setting_is`

Es un validador generico de asignaciones `clave = valor` en un archivo de
`pwquality`. Ignora lineas comentadas, espacios y comentarios al final del
valor. Devuelve exito solamente si encuentra la clave esperada y todas sus
apariciones tienen el valor pedido.

### `pwquality_fragment_matches`

Usa `pwquality_setting_is` para exigir simultaneamente:

- `minlen = 12`: longitud minima de doce caracteres;
- `minclass = 3`: al menos tres clases de caracteres;
- `maxrepeat = 3`: no mas de tres caracteres iguales consecutivos.

### `umask_fragment_matches`

Realiza tres niveles de validacion sobre el fragmento de `profile.d`:

1. Comprueba que el archivo exista.
2. Ejecuta `bash -n` y busca una instruccion activa `umask 027`.
3. Carga el archivo en un Bash aislado, partiendo de `umask 022`, y verifica que
   el resultado sea realmente `027` o su representacion `0027`.

La ultima prueba evita aceptar un archivo que contiene el texto esperado pero
que no produce la mascara final requerida.

### `sysctl_setting_is`

Valida una asignacion `clave = valor` dentro de un archivo de SYSCTL. Ignora
comentarios y espacios, y rechaza el archivo si la clave falta o aparece con un
valor distinto del esperado.

### `sysctl_fragment_matches`

Confirma que el fragmento persistente defina ambos controles con valor `1`:

- `fs.protected_hardlinks`;
- `fs.protected_symlinks`.

### `sysctl_effective_matches`

Consulta mediante `sysctl -n` los valores que estan activos en el kernel y
exige que ambos sean `1`. Esto diferencia entre tener una configuracion
persistente correcta y tenerla efectivamente cargada.

Con `TP2_ROOT` no consulta el kernel anfitrion y devuelve exito, porque la prueba
aislada solo representa un arbol de archivos.

### `apply_sysctl_fragment`

Carga exclusivamente el fragmento administrado por el TP mediante
`sysctl -p <archivo>`. Luego `control_sysctl` vuelve a consultar los valores
efectivos, por lo que el exito del comando no se toma como verificacion
suficiente.

## TODO 1: `control_ssh`

Se implemento el bloqueo del acceso remoto directo de `root` mediante
`PermitRootLogin no`.

### Modo `--check`

- Verifica el contenido del fragmento.
- En una ejecucion real valida la sintaxis global con `sshd -t`.
- Consulta con `sshd -T` que el valor efectivo sea `no`.
- En una prueba con `TP2_ROOT` limita la comprobacion al fragmento ficticio.

### Modo `--apply`

- Si el archivo y la configuracion efectiva ya son correctos, registra
  `SKIPPED`; esto hace que el control sea idempotente.
- Si hace falta un cambio, respalda el estado anterior y escribe el fragmento.
- Valida sintaxis y configuracion efectiva antes de recargar SSH.
- Recarga el servicio solamente despues de superar las validaciones.
- Si la validacion o la recarga falla, restaura silenciosamente el archivo
  anterior y registra `ERROR`.

### Modo `--restore`

- Restaura el respaldo original o elimina el fragmento si antes no existia.
- Si habia un respaldo registrado y se trabaja sobre el sistema real, valida la
  configuracion restaurada y recarga SSH.
- Informa un error si el archivo pudo restaurarse pero no pudo validarse o
  recargarse.

## TODO 2: `control_pwquality`

Se implemento una politica acotada de calidad de contrasenas y se comprobo que
el modulo que la aplica este integrado con PAM.

### Cuando se lee `pwquality.conf.d`

Los archivos de `/etc/security/pwquality.conf.d/` no se ejecutan durante el
arranque. Son archivos declarativos que `libpwquality` lee cuando debe evaluar
una contrasena, normalmente a traves de `pam_pwquality.so` durante un cambio de
contrasena.

El flujo habitual en Ubuntu es:

1. El usuario ejecuta `passwd`.
2. `passwd` solicita a PAM una operacion de cambio de contrasena.
3. PAM lee la configuracion del servicio en `/etc/pam.d/passwd`.
4. Esa configuracion incluye normalmente la pila definida en
   `/etc/pam.d/common-password`.
5. Si la pila carga `pam_pwquality.so`, el modulo obtiene la politica de
   `libpwquality`, incluyendo `/etc/security/pwquality.conf` y los fragmentos de
   `/etc/security/pwquality.conf.d/`.
6. La nueva contrasena se acepta o rechaza segun el resultado de la politica.

Por este motivo, modificar el fragmento no requiere reiniciar el sistema. La
politica se utiliza en el siguiente cambio de contrasena que pase por esa pila
PAM.

Los archivos de `/etc/pam.d/` tampoco son scripts. PAM los interpreta cuando
una aplicacion como `passwd`, `sudo`, `login` o `sshd` solicita un servicio de
autenticacion o administracion de credenciales. Cada aplicacion usa una pila
PAM determinada, por lo que encontrar `pam_pwquality.so` en cualquier archivo
de `/etc/pam.d` demuestra que esta referenciado, pero no garantiza por si solo
que intervenga en todos los cambios de contrasena. En Ubuntu, la referencia
relevante suele estar en la pila `password` de `common-password`.

### Significado de `minclass = 3`

Exige que la contrasena use caracteres de al menos tres de estas cuatro clases:

1. Letras minusculas.
2. Letras mayusculas.
3. Digitos.
4. Otros caracteres, como simbolos.

Por ejemplo, `ClaveSegura123` utiliza minusculas, mayusculas y digitos, por lo
que satisface esta condicion. Una contrasena formada solamente por letras
minusculas y mayusculas utiliza dos clases y no la satisface.

Esta opcion solo verifica la diversidad de clases. La contrasena tambien debe
cumplir `minlen` y las demas reglas activas de `libpwquality`.

### Significado de `maxrepeat = 3`

Permite como maximo tres apariciones consecutivas del mismo caracter. Por
ejemplo:

- `Claveaaa123` no supera el limite de repeticion;
- `Claveaaaa123` se rechaza por contener cuatro letras `a` consecutivas;
- `Clave1111Segura` se rechaza por contener cuatro digitos `1` consecutivos.

La opcion no limita la cantidad total de veces que un caracter puede aparecer.
Por ejemplo, `a1a2a3a4` no infringe `maxrepeat = 3`, porque las letras `a` no
estan consecutivas.

### Modo `--check`

- Verifica las tres opciones del fragmento.
- Confirma que algun archivo de `/etc/pam.d` cargue `pam_pwquality.so`.
- Marca error si la politica existe pero PAM no la utiliza.

### Modo `--apply`

- No escribe la politica si `pam_pwquality.so` no esta activo, porque quedaria
  una configuracion persistida pero inoperante.
- Si el fragmento ya coincide, registra `SKIPPED`.
- En caso contrario, respalda el estado previo y escribe la politica con
  permisos `0644`.

### Modo `--restore`

Usa la restauracion comun: recupera el archivo anterior o elimina el fragmento
si fue creado por primera vez durante el TP.

## TODO 3: `control_umask`

Se implemento `umask 027` para sesiones nuevas mediante un script en
`/etc/profile.d`.

Con esta mascara, los archivos parten normalmente de permisos `640` y los
directorios de `750`: el propietario conserva acceso, el grupo pierde escritura
y otros usuarios no reciben permisos.

### Cuando toma efecto la nueva mascara

El fragmento `/etc/profile.d/99-tp2-hardening.sh` toma efecto cuando una nueva
sesion de shell carga `/etc/profile` y este, a su vez, carga los fragmentos de
`/etc/profile.d/`. Esto ocurre normalmente en un nuevo inicio de sesion por SSH
o consola y en una shell iniciada explicitamente como shell de login.

La mascara pertenece a cada proceso y es heredada por sus procesos hijos. No es
una configuracion global que cambie inmediatamente todos los procesos del
sistema. Por eso:

- las sesiones que ya estaban abiertas conservan su umask anterior;
- los servicios de systemd y los procesos que no cargan `/etc/profile` pueden
  tener otra umask;
- una nueva sesion que cargue el fragmento usara `027` para sus creaciones
  posteriores.

### Alcance sobre archivos y directorios

La umask no modifica permisos existentes. Solamente limita los permisos
iniciales de archivos y directorios creados despues de que el proceso adopta la
mascara.

La operacion conceptual es:

```text
permisos finales = permisos solicitados AND NOT umask
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

La mascara quita permisos, pero no agrega permisos que el programa no haya
solicitado. Tampoco impide cambiar posteriormente los permisos mediante
`chmod`.

### Contenido y funcion de `/etc/profile.d/`

`/etc/profile.d/` contiene fragmentos de configuracion para sesiones de shell.
Habitualmente `/etc/profile` recorre los archivos `*.sh` del directorio y los
carga dentro de la sesion. Pueden definir variables de entorno, modificar
`PATH`, establecer configuracion regional, declarar funciones o configurar una
umask.

Estos archivos no son servicios y no se ejecutan automaticamente durante el
arranque. Se interpretan cuando una sesion compatible carga `/etc/profile`.

El fragmento agregado por el TP contiene:

```bash
# Configuracion TP2 para nuevas sesiones.
umask 027
```

El prefijo `99-` busca que se procese cerca del final del orden alfabetico. Sin
embargo, otro fragmento cargado posteriormente todavia podria cambiar la umask.

### Idempotencia y registro de `SKIPPED`

En este contexto, ser idempotente significa que ejecutar `--apply` varias veces
produce el mismo estado final y no acumula cambios repetidos.

En la primera ejecucion, el control crea el fragmento si hace falta. En las
ejecuciones siguientes, `umask_fragment_matches` comprueba que el archivo
exista, tenga sintaxis valida, declare `umask 027` y produzca efectivamente esa
mascara. Si todo coincide, no vuelve a escribir el archivo ni crea otro
respaldo: llama a `mark_skipped`.

El resultado se muestra en la terminal y se agrega, mediante `tee -a`, al log
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
de log.

### Modo `--check`

Comprueba existencia, sintaxis, directiva declarada y resultado efectivo del
fragmento. Si cualquiera de esas validaciones falla, registra `ERROR`.

### Modo `--apply`

- Si el fragmento ya produce `umask 027`, registra `SKIPPED`.
- Si no coincide, respalda el estado anterior y escribe el fragmento.
- El cambio afecta a nuevas sesiones que carguen `/etc/profile.d`; no modifica
  retroactivamente la mascara de procesos ya iniciados.

### Modo `--restore`

Restaura o elimina el fragmento mediante `restore_file`.

## TODO 4: `control_sysctl`

Se implementaron las protecciones del kernel contra ciertos abusos de enlaces
duros y simbolicos en directorios compartidos o escribibles por otros usuarios.

### Contenido y carga de `/etc/sysctl.d/`

`/etc/sysctl.d/` contiene fragmentos declarativos con parametros del kernel en
forma de asignaciones `clave = valor`. Es similar a `/etc/profile.d/` en que
permite separar la configuracion en archivos pequenos, pero sus archivos no son
scripts de shell.

Durante el arranque, herramientas como `systemd-sysctl` procesan normalmente
configuraciones ubicadas en varios directorios:

```text
/usr/lib/sysctl.d/
/usr/local/lib/sysctl.d/
/run/sysctl.d/
/etc/sysctl.d/
```

Tambien existe el archivo tradicional `/etc/sysctl.conf`. Las reglas exactas de
lectura y precedencia dependen de la herramienta utilizada, de los directorios
y del nombre de cada archivo. `/etc/sysctl.d/` se reserva normalmente para la
configuracion local del administrador y el prefijo `99-` ubica el fragmento
cerca del final del orden lexicografico.

Los fragmentos no se cargan "desde otro directorio". El servicio o la
herramienta recorre los directorios reconocidos, interpreta sus asignaciones y
las aplica al kernel.

### Significado del prefijo `fs`

En estas claves, `fs` significa *filesystem* o sistema de archivos. SYSCTL
organiza los parametros del kernel por categorias como `kernel.*`, `net.*`,
`vm.*` y `fs.*`.

### Proteccion de enlaces duros

`fs.protected_hardlinks = 1` restringe la creacion de enlaces duros hacia
archivos de otros usuarios. Un enlace duro es otro nombre que referencia el
mismo inode y contenido que un archivo existente.

Con la proteccion activa, el kernel impide determinados enlaces cuando el
usuario no es propietario del archivo original, no tiene los accesos requeridos
o no posee una capacidad privilegiada que permita omitir la restriccion. Esto
reduce ataques contra archivos sensibles y ciertas condiciones de carrera,
especialmente en directorios compartidos.

La opcion no deshabilita todos los enlaces duros: un usuario puede seguir
creandolos sobre sus propios archivos cuando los permisos y el sistema de
archivos lo permiten.

### Proteccion de enlaces simbolicos

`fs.protected_symlinks = 1` restringe el seguimiento inseguro de enlaces
simbolicos dentro de directorios compartidos con *sticky bit*, como `/tmp`.

Un atacante podria crear un enlace simbolico que apunte a un archivo sensible y
esperar que un proceso privilegiado lo abra creyendo que es un archivo normal.
La proteccion toma en cuenta los propietarios del proceso, del enlace y del
directorio para bloquear determinados seguimientos peligrosos.

La opcion no deshabilita los enlaces simbolicos. Solamente restringe escenarios
que podrian permitir que un proceso acceda o modifique un archivo ajeno a traves
de un enlace preparado por otro usuario.

### Aplicacion mediante `sysctl -p`

`sysctl -p` lee asignaciones desde un archivo y las aplica inmediatamente al
kernel en ejecucion. Sin una ruta explicita suele cargar `/etc/sysctl.conf`:

```bash
sudo sysctl -p
```

El control indica expresamente su fragmento:

```bash
sudo sysctl -p /etc/sysctl.d/99-tp2-hardening.conf
```

Esto permite activar los valores sin esperar al siguiente arranque. El comando
no proporciona persistencia por si mismo: la persistencia surge de conservar el
archivo en un directorio que se procesa nuevamente al arrancar.

### Archivo correcto y valores efectivos

Para el script, el archivo persistente esta correcto cuando existe
`/etc/sysctl.d/99-tp2-hardening.conf` y contiene activamente:

```text
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
```

`sysctl_fragment_matches` comprueba ambas asignaciones con
`sysctl_setting_is`. La validacion ignora comentarios y diferencias de espacios,
pero exige que las claves existan y no aparezcan con un valor distinto. Una
linea comentada no satisface la comprobacion.

Esto representa el estado persistente deseado, pero no demuestra que el kernel
ya lo este usando. Los valores efectivos son los que se encuentran activos en
la memoria del kernel en ese momento. El script los consulta mediante:

```bash
sysctl -n fs.protected_hardlinks
sysctl -n fs.protected_symlinks
```

Esos valores tambien estan expuestos en el sistema virtual `/proc`:

```text
/proc/sys/fs/protected_hardlinks
/proc/sys/fs/protected_symlinks
```

El archivo y los valores efectivos pueden diferir si el fragmento aun no se
cargo, otra configuracion o comando cambio posteriormente el kernel, o la
aplicacion fallo. Por eso el control comprueba por separado:

1. El estado persistente del fragmento.
2. El estado efectivo del kernel.

### Idempotencia del control

El estado final buscado es que el fragmento sea correcto y que los dos valores
efectivos sean `1`. Si el archivo ya coincide, el script no lo vuelve a escribir
ni genera otro respaldo. Aun asi ejecuta `sysctl -p` para asegurar que la
configuracion este cargada y despues consulta el kernel.

Cuando ambos estados ya son correctos, registra:

```text
[SKIPPED] [SYSCTL] El archivo y los valores efectivos ya son correctos
```

Volver a ejecutar `--apply` no acumula lineas, archivos ni respaldos y conserva
el mismo estado final. En ese sentido, el control es idempotente.

### Modo `--check`

- Verifica que el fragmento persistente contenga los dos valores requeridos.
- En el sistema real tambien consulta los valores activos del kernel.
- En modo aislado solo valida el archivo bajo `TP2_ROOT`.

### Modo `--apply`

- Escribe y respalda el fragmento solamente si su contenido no coincide.
- Ejecuta `sysctl -p` incluso cuando el archivo ya era correcto, para asegurar
  que los valores esten cargados.
- Comprueba despues los valores efectivos del kernel.
- Si se creo o reemplazo el fragmento y la aplicacion falla, restaura el archivo
  anterior.
- Registra `APPLIED` cuando cambio el archivo y `SKIPPED` cuando tanto el
  archivo como el estado efectivo ya eran correctos.

### Modo `--restore`

- Restaura el estado anterior del fragmento.
- Si habia un archivo previo y fue restaurado en el sistema real, ejecuta
  `sysctl -p` sobre ese archivo para volver a aplicar sus valores.
- Si antes no existia, elimina el fragmento. No intenta inventar valores de
  kernel anteriores que no hayan quedado representados en un archivo.

## Idempotencia y recuperacion ante errores

La segunda ejecucion de `--apply` no vuelve a escribir configuraciones que ya
coinciden. Cada control compara primero el estado deseado y registra `SKIPPED`
cuando no hay cambios pendientes.

Los respaldos se crean una sola vez. De esta manera, ejecuciones posteriores no
sobrescriben el estado original con una version ya endurecida. Los marcadores
del directorio de estado permiten distinguir entre dos casos:

- el archivo existia y debe recuperarse desde `.backup`;
- el archivo no existia y debe eliminarse al restaurar.

SSH y SYSCTL agregan rollback inmediato: si no pueden validar o activar una
configuracion que acaban de escribir, restauran el archivo original antes de
informar el error.

## Flujo final del script

El orden de ejecucion quedo definido asi:

1. `control_uid0`, que ya estaba implementado en la plantilla.
2. `control_ssh`.
3. `control_pwquality`.
4. `control_umask`.
5. `control_sysctl`.

Al finalizar se registra un resumen con acciones aplicadas, omitidas,
verificadas y errores. Si hubo al menos un error, el script termina con codigo
de salida `1`; de lo contrario termina correctamente.

## Observacion sobre la plantilla

La consigna indica que `hardening_base.sh` debe conservarse sin cambios y que
la solucion debe guardarse en `hardening.sh`. Actualmente la plantilla del
repositorio contiene la misma implementacion que el entregable. Esto no cambia
el funcionamiento de `hardening.sh`, pero elimina los TODO que debian quedar
como referencia en el archivo base.
