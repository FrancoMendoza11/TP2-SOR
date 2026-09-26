# Punto 8: control de acceso con AppArmor

## Objetivo

AppArmor limita las operaciones que puede realizar un programa mediante un
perfil asociado a su ejecutable. En este TP, el perfil de
`/usr/local/bin/tp2-reader` permite leer `publico.txt` y no concede permiso para
leer `confidencial.txt`.

AppArmor es un mecanismo de control de acceso obligatorio (*Mandatory Access
Control*, MAC) integrado con el kernel de Linux. Se suma a los permisos Unix
tradicionales: para que una operacion tenga exito deben permitirla tanto los
permisos tradicionales como el perfil de AppArmor.

## AppArmor y los servicios en segundo plano

AppArmor no funciona como `sshd`, que permanece a la espera de conexiones. El
servicio de AppArmor suele cargar los perfiles durante el arranque; el kernel
mantiene las politicas cargadas y las consulta cuando los procesos intentan
acceder a archivos u otros recursos. No se inicia un daemon nuevo cada vez que
se ejecuta un programa.

Por lo tanto, su aplicacion ocurre durante las operaciones de los procesos,
pero no es un mecanismo que se active a demanda solo cuando alguien lo solicita:
los perfiles deben estar cargados y activos. Las herramientas `aa-status`,
`aa-complain` y `aa-enforce` permiten consultar y cambiar su estado.

AppArmor es una tecnologia nativa del ecosistema Linux, implementada mediante
el marco de *Linux Security Modules* (LSM). Que el kernel la soporte no implica
que este habilitada en toda distribucion o instalacion; se debe verificar en la
maquina de trabajo.

## Relacion con `auditd`

AppArmor y `auditd` se complementan, pero tienen responsabilidades diferentes:

| Componente | Funcion |
| --- | --- |
| AppArmor | Decide si una operacion esta permitida por el perfil y puede bloquearla. |
| Kernel | Aplica la politica y genera eventos de seguridad para accesos permitidos en modo `complain` o denegados en modo `enforce`. |
| `auditd` | Recibe y conserva eventos del subsistema de auditoria para consultarlos despues, segun la configuracion del sistema. |

AppArmor puede generar mensajes de auditoria visibles en el registro del kernel
y, segun la configuracion, en los registros de `auditd`. `auditd` no es
necesario para que AppArmor aplique los perfiles, y las reglas de `auditd` no
definen que archivos permite AppArmor. Para este ejercicio, primero se puede
verificar el evento en el registro del kernel; para una consulta persistente,
se puede revisar tambien el registro de auditoria.

## Preparar e instalar el perfil

El archivo `codigo_base/apparmor/usr.local.bin.tp2-reader.base` es una plantilla
de la catedra. Completa sus TODO y guarda el resultado como
`codigo_base/apparmor/usr.local.bin.tp2-reader`, sin modificar ni eliminar la
plantilla `.base`. El perfil definitivo debe permitir el acceso necesario al
ejecutable y la lectura de `publico.txt`, y no debe conceder acceso a
`confidencial.txt`. La ausencia de una regla de permiso basta para denegar ese
acceso; no hace falta agregar una regla `deny` explicita.

Puedes crear el archivo de trabajo con:

```bash
cp codigo_base/apparmor/usr.local.bin.tp2-reader.base \
  codigo_base/apparmor/usr.local.bin.tp2-reader
```

Completa y revisa ese archivo definitivo, y elimina de el los comentarios
`TODO`. Conserva las reglas que permiten ejecutar el binario y leer
`publico.txt`; no agregues una regla que permita leer `confidencial.txt`.

Desde la raiz del repositorio, verifica primero que AppArmor este habilitado:

```bash
sudo aa-status
```

Instala el perfil definitivo en el directorio que AppArmor procesa. El nombre
del archivo corresponde al ejecutable perfilado:

```bash
sudo install -o root -g root -m 0644 \
  codigo_base/apparmor/usr.local.bin.tp2-reader \
  /etc/apparmor.d/usr.local.bin.tp2-reader
```

Carga o actualiza el perfil:

```bash
sudo apparmor_parser -r /etc/apparmor.d/usr.local.bin.tp2-reader
```

## Probar en modo permisivo (`complain`)

En modo `complain`, AppArmor registra las operaciones que el perfil no permite,
pero no las bloquea. Esto permite comprobar el perfil antes de activar la
restriccion.

El modo no se asigna al usuario ni a la terminal. Se asigna al perfil de
`/usr/local/bin/tp2-reader`. El usuario ejecuta el programa de la forma
habitual y el kernel aplica el modo del perfil a cada operacion del proceso.

| Modo | Operacion no permitida por el perfil |
| --- | --- |
| `complain` | Se permite, pero se registra como una violacion. |
| `enforce` | Se bloquea y se registra como una denegacion. |

En este TP, la regla de lectura de `publico.txt` permite el acceso en ambos
modos. Como no existe una regla para `confidencial.txt`, la lectura puede
completarse en `complain` y debe fallar con `Permission denied` en `enforce`.

```bash
sudo aa-complain /etc/apparmor.d/usr.local.bin.tp2-reader
sudo aa-status
```

Confirma que `usr.local.bin.tp2-reader` aparezca en la lista de perfiles en modo
`complain`. Ejecuta el binario contra ambos archivos:

```bash
/usr/local/bin/tp2-reader /srv/tp2/datos/publico.txt
/usr/local/bin/tp2-reader /srv/tp2/datos/confidencial.txt
```

Los dos intentos pueden completarse en este modo. El acceso a
`confidencial.txt` debe quedar registrado como permitido, por ejemplo con
`apparmor="ALLOWED"`. Para buscar los eventos recientes del kernel:

```bash
sudo journalctl -k --since "10 minutes ago" | grep -i apparmor | tail -n 5
```

Tambien se puede consultar `dmesg`:

```bash
sudo dmesg | grep -i apparmor | tail -n 5
```

## Aplicar el modo estricto (`enforce`)

En modo `enforce`, AppArmor bloquea las operaciones que no permite el perfil y
registra la denegacion:

```bash
sudo aa-enforce /etc/apparmor.d/usr.local.bin.tp2-reader
sudo aa-status
```

Confirma que el perfil figure en la lista de perfiles en modo `enforce`. Vuelve
a ejecutar las dos pruebas:

```bash
# Debe leer el archivo correctamente.
/usr/local/bin/tp2-reader /srv/tp2/datos/publico.txt

# Debe fallar con "Permission denied".
/usr/local/bin/tp2-reader /srv/tp2/datos/confidencial.txt
```

Consulta el evento del kernel:

```bash
sudo journalctl -k --since "10 minutes ago" | grep -i apparmor | tail -n 5
```

La denegacion debe incluir `apparmor="DENIED"`, el perfil
`/usr/local/bin/tp2-reader` y el archivo
`/srv/tp2/datos/confidencial.txt`. Si se consulta `dmesg`, la linea tambien
puede aparecer alli:

```bash
sudo dmesg | grep -i apparmor | tail -n 5
```

## Como documentar la evidencia

La evidencia debe indicar que se esperaba, que ocurrio y que demuestra cada
prueba. Guarda, como minimo:

- la salida de `aa-status` con el perfil cargado;
- las pruebas de lectura en modo `complain`;
- el evento `apparmor="ALLOWED"` o equivalente para el acceso no permitido;
- las pruebas de lectura en modo `enforce`;
- el error `Permission denied` para `confidencial.txt`;
- el evento `apparmor="DENIED"` correspondiente.

Estos resultados permiten demostrar que los permisos DAC no bastan para
autorizar la lectura y que AppArmor agrega una restriccion basada en el
ejecutable. Tambien permiten explicar la diferencia entre observar una
violacion en `complain` y bloquearla en `enforce`.

## Ver los eventos con `auditd`

Cuando el sistema entregue esos eventos al registro de auditoria, se pueden
buscar con `ausearch` y comprobar el servicio con:

```bash
sudo systemctl is-active auditd
sudo ausearch -m ALL -ts recent | grep -i apparmor
```

La disponibilidad y el formato de los eventos pueden depender de la version del
kernel y de la configuracion de auditoria. La comprobacion de `journalctl -k`
permite observar los mensajes de AppArmor del kernel aunque no se encuentren en
la salida de `ausearch`.
