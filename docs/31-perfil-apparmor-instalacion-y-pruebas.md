# Perfil AppArmor: instalación y pruebas

> **Alcance:** cómo preparar, instalar, cargar y validar el perfil AppArmor de `tp2-reader`.
>
> **Cuándo leerlo:** al implementar la parte 2 o reunir evidencia de los modos `complain` y `enforce`.
>
> **Prerrequisitos:** el [resumen de AppArmor](./30-mapa-de-apparmor.md) y la [preparación del entorno](./11-entorno-y-flujo-de-trabajo.md).

## Documentos relacionados

- [Resumen de AppArmor](./30-mapa-de-apparmor.md)
- [Auditoría e integridad](./40-mapa-de-auditoria-e-integridad.md)
- [Escenario integrador](./50-escenario-integrador.md)

## Preparar e instalar el perfil

El archivo `codigo_base/apparmor/usr.local.bin.tp2-reader.base` es una plantilla
de la cátedra. Completá sus TODO y guardá el resultado como
`codigo_base/apparmor/usr.local.bin.tp2-reader`, sin modificar ni eliminar la
plantilla `.base`. El perfil definitivo debe permitir el acceso necesario al
ejecutable y la lectura de `publico.txt`, y no debe conceder acceso a
`confidencial.txt`. La ausencia de una regla de permiso basta para denegar ese
acceso; no hace falta agregar una regla `deny` explícita.

Podés crear el archivo de trabajo con:

```bash
cp codigo_base/apparmor/usr.local.bin.tp2-reader.base \
  codigo_base/apparmor/usr.local.bin.tp2-reader
```

Completá y revisá ese archivo definitivo, y eliminá los comentarios `TODO`.
Conservá las reglas que permiten ejecutar el binario y leer `publico.txt`; no
agregues una regla que permita leer `confidencial.txt`.

Desde la raíz del repositorio, verificá primero que AppArmor esté habilitado:

```bash
sudo aa-status
```

Instalá el perfil definitivo en el directorio que AppArmor procesa. El nombre
del archivo corresponde al ejecutable perfilado:

```bash
sudo install -o root -g root -m 0644 \
  codigo_base/apparmor/usr.local.bin.tp2-reader \
  /etc/apparmor.d/usr.local.bin.tp2-reader
```

Cargá o actualizá el perfil:

```bash
sudo apparmor_parser -r /etc/apparmor.d/usr.local.bin.tp2-reader
```

## Probar en modo permisivo (`complain`)

En modo `complain`, AppArmor registra las operaciones que el perfil no permite,
pero no las bloquea. Esto permite comprobar el perfil antes de activar la
restricción.

El modo no se asigna al usuario ni a la terminal. Se asigna al perfil de
`/usr/local/bin/tp2-reader`. El usuario ejecuta el programa de la forma
habitual y el núcleo aplica el modo del perfil a cada operación del proceso.

| Modo | Operación no permitida por el perfil |
| --- | --- |
| `complain` | Se permite, pero se registra como una violación. |
| `enforce` | Se bloquea y se registra como una denegación. |

En este TP, la regla de lectura de `publico.txt` permite el acceso en ambos
modos. Como no existe una regla para `confidencial.txt`, la lectura puede
completarse en `complain` y debe fallar con `Permission denied` en `enforce`.

```bash
sudo aa-complain /etc/apparmor.d/usr.local.bin.tp2-reader
sudo aa-status
```

Confirmá que `usr.local.bin.tp2-reader` aparezca en la lista de perfiles en modo
`complain`. Ejecutá el binario contra ambos archivos:

```bash
/usr/local/bin/tp2-reader /srv/tp2/datos/publico.txt
/usr/local/bin/tp2-reader /srv/tp2/datos/confidencial.txt
```

Los dos intentos pueden completarse en este modo. El acceso a
`confidencial.txt` debe quedar registrado como permitido, por ejemplo con
`apparmor="ALLOWED"`. Para buscar los eventos recientes del núcleo:

```bash
sudo journalctl -k --since "10 minutes ago" | grep -i apparmor | tail -n 5
```

También se puede consultar `dmesg`:

```bash
sudo dmesg | grep -i apparmor | tail -n 5
```

## Aplicar el modo estricto (`enforce`)

En modo `enforce`, AppArmor bloquea las operaciones que no permite el perfil y
registra la denegación:

```bash
sudo aa-enforce /etc/apparmor.d/usr.local.bin.tp2-reader
sudo aa-status
```

Confirmá que el perfil figure en la lista de perfiles en modo `enforce`. Volvé
a ejecutar las dos pruebas:

```bash
# Debe leer el archivo correctamente.
/usr/local/bin/tp2-reader /srv/tp2/datos/publico.txt

# Debe fallar con "Permission denied".
/usr/local/bin/tp2-reader /srv/tp2/datos/confidencial.txt
```

Consultá el evento del núcleo:

```bash
sudo journalctl -k --since "10 minutes ago" | grep -i apparmor | tail -n 5
```

La denegación debe incluir `apparmor="DENIED"`, el perfil
`/usr/local/bin/tp2-reader` y el archivo
`/srv/tp2/datos/confidencial.txt`. Si se consulta `dmesg`, la línea también
puede aparecer allí:

```bash
sudo dmesg | grep -i apparmor | tail -n 5
```

## Cómo documentar la evidencia

La evidencia debe indicar qué se esperaba, qué ocurrió y qué demuestra cada
prueba. Guardá, como mínimo:

- la salida de `aa-status` con el perfil cargado;
- las pruebas de lectura en modo `complain`;
- el evento `apparmor="ALLOWED"` o equivalente para el acceso no permitido;
- las pruebas de lectura en modo `enforce`;
- el error `Permission denied` para `confidencial.txt`;
- el evento `apparmor="DENIED"` correspondiente.

Estos resultados permiten demostrar que los permisos DAC no bastan para
autorizar la lectura y que AppArmor agrega una restricción basada en el
ejecutable. También permiten explicar la diferencia entre observar una
violación en `complain` y bloquearla en `enforce`.

## Ver los eventos con `auditd`

Cuando el sistema entregue esos eventos al registro de auditoría, podés
buscarlos con `ausearch` y comprobar el servicio con:

```bash
sudo systemctl is-active auditd
sudo ausearch -m ALL -ts recent | grep -i apparmor
```

La disponibilidad y el formato de los eventos pueden depender de la versión del
núcleo y de la configuración de auditoría. La comprobación de `journalctl -k`
permite observar los mensajes de AppArmor del núcleo aunque no se encuentren en
la salida de `ausearch`.
## Leer a continuación

- [Auditoría e integridad](./40-mapa-de-auditoria-e-integridad.md)
- [Escenario integrador](./50-escenario-integrador.md)
