# Reglas y consultas de auditd

> **Alcance:** cómo auditd conserva eventos seleccionados, qué identifican las claves del TP y cómo cargar/consultar las reglas.
>
> **Cuándo leerlo:** al configurar auditoría persistente o buscar eventos producidos por `tp2-event`.
>
> **Prerrequisitos:** el [resumen de auditoría e integridad](./40-mapa-de-auditoria-e-integridad.md); para entender el proceso observado, consultá [llamadas al sistema y strace](./42-llamadas-al-sistema-y-strace.md).

## Documentos relacionados

- [Resumen de auditoría e integridad](./40-mapa-de-auditoria-e-integridad.md)
- [Llamadas al sistema y strace](./42-llamadas-al-sistema-y-strace.md)
- [Correlación de evidencia](./44-correlacion-de-evidencias.md)
- [Escenario integrador](./50-escenario-integrador.md)

## Cómo funciona `auditd`

`auditd` es un servicio del sistema que corre en segundo plano. Igual que
`sshd`, normalmente se inicia mediante
`systemd` al arrancar la máquina virtual. La diferencia es que `sshd` espera
conexiones de red, mientras que `auditd` recibe eventos del subsistema de
auditoría del núcleo y los conserva en `/var/log/audit/audit.log`.

Que `auditd` esté activo no significa que registre absolutamente todo. Las
reglas cargadas en el núcleo determinan qué operaciones se auditan. En este TP
se definieron dos reglas: una para modificaciones dentro de
`/srv/tp2/datos` y otra para la ejecución de `/usr/local/bin/tp2-event`.
Las claves `tp2_datos` y `tp2_exec` son etiquetas que permiten buscar después
los eventos con `ausearch`.

Las herramientas cumplen funciones diferentes:

- `auditd`: proceso en segundo plano que conserva los eventos de auditoría.
- `auditctl`: consulta o administra reglas; `auditctl -l` lista las reglas
  activas. La opción `-l` es la letra ele minúscula, no el número `1`.
- `augenrules`: reúne las reglas de `/etc/audit/rules.d/` y las carga en el
  subsistema de auditoría cuando se usa con `--load`.
- `ausearch`: busca eventos que ya fueron registrados por `auditd`.

Por ejemplo, si no existe una regla que coincida con `/usr/bin/batcat`, una
ejecución de `batcat` no aparece bajo la clave `tp2_exec`, porque esa clave
solo corresponde exactamente a `/usr/local/bin/tp2-event`. Podría aparecer
si existiera otra regla del sistema que la capturara. `strace`, en cambio,
puede observar `batcat` aunque no exista una regla de `auditd`, porque trabaja
de forma independiente durante esa ejecución puntual.

## Qué significan `tp2_exec` y `tp2_datos`

`tp2_exec` y `tp2_datos` no son comandos, programas ni llamadas al sistema. Son claves o
etiquetas asignadas a las dos reglas de `auditd` solicitadas por la consigna.
Permiten encontrar posteriormente los eventos producidos por cada regla.

### Clave `tp2_exec`

Identifica la regla que registra la llamada al sistema `execve` cuando se ejecuta:

```text
/usr/local/bin/tp2-event
```

Su objetivo es dejar evidencia de quién ejecutó el programa, cuándo lo hizo,
qué proceso intervino y cuál fue el resultado.

### Clave `tp2_datos`

Identifica la regla que vigila modificaciones y cambios de atributos dentro de:

```text
/srv/tp2/datos
```

Cuando `tp2-event` agrega una línea a `eventos.log`, esta regla permite localizar
la actividad relacionada con la modificación de los datos.

La secuencia completa se reparte entre esta nota y la [guía de correlación](./44-correlacion-de-evidencias.md). Acá se explican los pasos 1 (cargar reglas) y 3 (consultar eventos); los pasos 2 (generar la actividad) y 4 (correlacionar) están en la nota 44.

## Secuencia de trabajo

### 1. Completar y cargar las reglas

El archivo terminado que se entrega es `codigo_base/audit/99-tp2.rules`.
La plantilla `audit/99-tp2.rules.base` se conserva sin modificar. El archivo
terminado contiene exactamente estas dos reglas:

```text
-w /srv/tp2/datos -p wa -k tp2_datos
-a always,exit -F arch=b64 -S execve -F path=/usr/local/bin/tp2-event -k tp2_exec
```

La primera observa escrituras y cambios de atributos (`-p wa`) dentro de
`/srv/tp2/datos`. La segunda registra la llamada al sistema `execve` cuando se ejecuta el
binario `tp2-event`, usando las claves solicitadas por la consigna.

Desde `codigo_base/`, instalá el fragmento en el sistema operativo y cargá las
reglas:

```bash
sudo install -m 0640 audit/99-tp2.rules /etc/audit/rules.d/99-tp2.rules
sudo augenrules --load
sudo auditctl -l | grep tp2_
```

#### Qué hace cada comando

- `sudo install -m 0640 ...`: copia el archivo terminado desde el repositorio
  a `/etc/audit/rules.d/`, que es una ruta protegida del sistema. `sudo` otorga
  temporalmente permisos administrativos para poder escribir allí; no instala
  un paquete ni activa por sí solo las reglas. La opción `-m 0640` fija sus
  permisos.
- `sudo augenrules --load`: reúne los archivos `*.rules` de
  `/etc/audit/rules.d/`, genera la configuración consolidada de auditd y carga
  las reglas en el subsistema de auditoría del núcleo. Sin `--load`, no se
  solicita esa carga inmediata.
- `sudo auditctl -l`: consulta y lista las reglas actualmente activas en el
  núcleo. La opción `-l` es la letra ele minúscula, no el número `1`.
  `| grep tp2_` filtra la salida para mostrar solo las reglas que contienen las
  claves `tp2_datos` o `tp2_exec`. Este último comando consulta; no modifica
  ninguna regla.

El archivo dentro de `/etc/audit/rules.d/` permite conservar la configuración
para futuras cargas y reinicios, mientras que el archivo del repositorio es la
versión reproducible y entregable. `auditctl -l` permite comprobar que las
reglas están activas antes de generar el evento. Si se ejecuta el programa
antes de cargar las reglas, auditd no puede registrar retroactivamente esa
actividad.

### 3. Consultar auditd

Después de la ejecución se buscan los eventos por sus claves:

```bash
sudo ausearch -k tp2_exec -ts recent -i
sudo ausearch -k tp2_datos -ts recent -i
```

- `-k` filtra por la clave asignada a la regla.
- `-ts recent` limita la búsqueda a eventos recientes.
- `-i` interpreta valores numéricos para facilitar la lectura.

## Leer a continuación

- [Llamadas al sistema y strace](./42-llamadas-al-sistema-y-strace.md)
- [Correlación de evidencia](./44-correlacion-de-evidencias.md)
