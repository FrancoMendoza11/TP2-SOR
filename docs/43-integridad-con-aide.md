# Integridad de archivos con AIDE

> **Alcance:** configuración local de AIDE, procedimiento del punto 9.3 e interpretación de los cambios detectados en la prueba.
>
> **Cuándo leerlo:** al configurar la parte 3, interpretar el informe de AIDE o preparar el escenario integrador.
>
> **Prerrequisitos:** el [resumen de auditoría e integridad](./40-mapa-de-auditoria-e-integridad.md); distingue la detección de cambios de la atribución de eventos de auditd.

## Documentos relacionados

- [Resumen de auditoría e integridad](./40-mapa-de-auditoria-e-integridad.md)
- [Reglas auditd](./41-reglas-y-consultas-de-auditd.md)
- [Correlación de evidencia](./44-correlacion-de-evidencias.md)
- [Escenario integrador](./50-escenario-integrador.md)

## Papel de AIDE

AIDE no observa llamadas al sistema ni registra eventos en tiempo real. Primero recorre las
rutas configuradas y crea una base con el estado esperado de sus archivos.
Luego vuelve a recorrerlas y compara el estado actual con esa línea base.

En este TP la configuración local se limita a `/srv/tp2/datos` y debe comprobar
atributos como los siguientes:

- tipo y permisos;
- inode y cantidad de enlaces;
- propietario y grupo;
- tamaño y tiempos;
- huella SHA-256 del contenido.

El orden conceptual es:

```text
1. Configurar AIDE.
2. Crear la base inicial.
3. Crear o modificar archivos y cambiar permisos.
4. Ejecutar la comprobación.
5. Interpretar las diferencias informadas.
```

AIDE puede indicar que un archivo es nuevo, que cambió su contenido o que
cambiaron sus metadatos. No explica por sí solo qué proceso o usuario produjo
el cambio. Esa información se complementa con `auditd`.

Una limitación importante es que una base almacenada en la misma máquina puede
ser alterada junto con los archivos protegidos si un atacante obtiene
privilegios suficientes. Una base protegida externamente ofrece una referencia
más confiable.

AIDE se puede pensar como un comparador de estados, pero la base no es un
snapshot restaurable: guarda atributos y huellas, no una copia del contenido.
Cada `--check` compara contra la misma referencia y no la actualiza
automáticamente. Tampoco conserva un historial continuo de cambios.

## Configuración implementada

El archivo terminado es [codigo_base/aide/aide.conf](../codigo_base/aide/aide.conf).
La plantilla `aide.conf.base` se conserva sin modificar.

```conf
database_in=file:/srv/tp2/aide/aide.db
database_out=file:/srv/tp2/aide/aide.db.new
report_level=changed_attributes
report_url=stdout

TP2_NORMAL = p+ftype+i+n+u+g+s+m+c+sha256
/srv/tp2/datos TP2_NORMAL
```

| Directiva | Función |
| --- | --- |
| `database_in` | Base de referencia utilizada por `--check`. |
| `database_out` | Archivo donde `--init` escribe la base nueva. |
| `report_level=changed_attributes` | Muestra el detalle de los atributos que cambiaron. |
| `report_url=stdout` | Escribe el reporte en la salida estándar para poder verlo y guardarlo. |
| `TP2_NORMAL` | Agrupa los atributos que se comprueban. |
| `/srv/tp2/datos TP2_NORMAL` | Aplica el grupo al directorio de datos y a sus entradas. No recorre todo el sistema. |

Los atributos del grupo son:

| Atributo | Qué comprueba |
| --- | --- |
| `p` | Permisos. |
| `ftype` | Tipo de archivo. |
| `i` | Inode. |
| `n` | Cantidad de enlaces duros. |
| `u`, `g` | Propietario y grupo. |
| `s` | Tamaño. |
| `m`, `c` | Tiempo de modificación del contenido y de cambio de metadatos. |
| `sha256` | Huella SHA-256 del contenido. |

No se incluye el tiempo de último acceso (`atime`), porque las lecturas
pueden modificarlo sin cambiar el contenido del archivo. `ctime` no es
la fecha de creación del archivo.

### Advertencia sobre `TP2_NORMAL`

La plantilla de la cátedra pide explícitamente el nombre `TP2_NORMAL`.
AIDE 0.18.6 lo acepta, pero advierte que los caracteres no alfanuméricos
en los nombres de grupo están deprecados. La advertencia se debe al
guion bajo, no a los atributos seleccionados.

Se mantuvo el nombre para respetar la plantilla. No se debe confundir
esta advertencia con un error de validación; conviene verificar el código
de salida inmediatamente después de `--config-check` con `echo $?`.
Un resultado `0` indica éxito. En una configuración sin ese requisito,
se podría usar `TP2NORMAL` tanto en la definición como en la regla.

## Procedimiento del punto 9.3

Todos los comandos se ejecutan dentro de la VM Ubuntu del TP. AIDE no
necesita cargar esta configuración en un servicio: cada ejecución usa
el archivo indicado mediante `--config`.

### 1. Instalar y validar la configuración

Desde `codigo_base/`:

```bash
sudo install -m 0644 aide/aide.conf /srv/tp2/config/aide.conf
sudo aide --config=/srv/tp2/config/aide.conf --config-check
```

No se usa la configuración global de AIDE. Solo se continúa si la
configuración local es válida.

### 2. Crear la línea base y comprobarla

```bash
sudo aide --config=/srv/tp2/config/aide.conf --init
```

Si la inicialización termina correctamente, dejar la base nueva como
referencia activa:

```bash
sudo mv /srv/tp2/aide/aide.db.new /srv/tp2/aide/aide.db
sudo aide --config=/srv/tp2/config/aide.conf --check
```

Este movimiento corresponde a la primera inicialización. Si ya existe
una base activa, no se debe sobrescribir sin decidir antes qué referencia
se necesita conservar.

En la prueba, `--init` terminó correctamente el 3 de octubre de 2026 a
las 22:24:16 UTC y registró cuatro entradas. Las entradas incluyen el
directorio; no significa necesariamente que hubiera cuatro archivos.
A las 22:27:22 UTC, la comprobación inicial informó:

```text
AIDE found NO differences between database and filesystem. Looks okay!!
```

Estos datos provienen de las salidas compartidas durante la prueba. Los
reportes originales de inicialización y comprobación limpia todavía no
están incluidos en `docs/evidencias/`.

### 3. Aplicar los cambios controlados

Después de crear y comprobar la base, se creó un archivo nuevo:

```bash
printf 'Archivo nuevo para la prueba de AIDE\n' \
  | sudo tee /srv/tp2/datos/prueba_aide.txt > /dev/null
```

Se agregó contenido a un archivo existente, sin reemplazar lo anterior:

```bash
printf '\nCambio controlado para la prueba de AIDE\n' \
  | sudo tee -a /srv/tp2/datos/publico.txt > /dev/null
```

Se verificaron los permisos y se cambiaron de `0644` a `0640`:

```bash
stat -c '%a %n' /srv/tp2/datos/publico.txt
sudo chmod 0640 /srv/tp2/datos/publico.txt
```

En una nueva prueba, verificar que `prueba_aide.txt` no exista en la base
y que el cambio de permisos sea real. No repetir estos comandos sin
revisar el estado: `tee` puede reemplazar un archivo existente y `tee -a`
agrega otra línea cada vez que se ejecuta.

### 4. Comparar y guardar el reporte

Sin regenerar ni actualizar la base:

```bash
sudo aide --config=/srv/tp2/config/aide.conf --check \
  | sudo tee /srv/tp2/evidencias/aide_check_cambios.txt
```

Encontrar diferencias es el resultado esperado de esta prueba, no un
fallo de configuración. AIDE puede devolver un código distinto de cero
cuando detecta cambios. Si se usa una tubería con `tee`, `$?` por sí solo
refleja el último comando, no necesariamente el resultado de AIDE.

## Análisis de la evidencia guardada

El [reporte de cambios](./evidencias/aide_check_cambios.txt) corresponde a
AIDE 0.18.6 y a la comprobación del 3 de octubre de 2026, entre las
22:33:54 y las 22:33:55 UTC.

```text
Total number of entries: 5
Added entries:          1
Removed entries:        0
Changed entries:        2
```

| Cambio esperado | Resultado observado | Qué demuestra |
| --- | --- | --- |
| Archivo nuevo | `/srv/tp2/datos/prueba_aide.txt` aparece en `Added entries`. | Existe una entrada que no estaba en la línea base. |
| Contenido modificado | `publico.txt` pasó de 58 a 100 bytes y cambió su SHA-256. | El contenido es diferente del registrado inicialmente. |
| Permisos modificados | `publico.txt` pasó de `-rw-r--r--` a `-rw-r-----`, es decir, de `0644` a `0640`. | Se eliminó el permiso de lectura para otros usuarios. |

En las comparaciones del detalle, la columna izquierda corresponde a
la línea base y la derecha al estado actual.

### Por qué hay dos entradas modificadas

La entrada de `publico.txt` reúne los cambios de contenido y permisos.
Su `mtime` pasó a las 22:32:11 UTC, compatible con la modificación de
contenido, y su `ctime` pasó a las 22:32:54 UTC, compatible con el cambio
posterior de permisos. Esos tiempos no identifican por sí solos al autor.

La segunda entrada modificada es el directorio `/srv/tp2/datos`. Su
`mtime` y `ctime` cambiaron a las 22:31:56 UTC, como se esperaba al
crear una entrada dentro del directorio. No significa que se haya
modificado el contenido de otro archivo.

En el resumen compacto, `f` indica archivo y `d` directorio. En la línea
de `publico.txt`, `>` indica aumento de tamaño, `p` permisos cambiados,
`m` y `c` tiempos cambiados y `H` cambio de huella. El detalle permite
interpretar esas diferencias sin depender solo de los símbolos.

### Por qué aparecen varios algoritmos de hash

El bloque `The attributes of the (uncompressed) database(s)` muestra
huellas del propio archivo `/srv/tp2/aide/aide.db` usando varios
algoritmos. No indica que todos esos algoritmos se utilicen para vigilar
cada archivo de datos.

La configuración `TP2_NORMAL` pide SHA-256 para el contenido de los
archivos vigilados. Por eso el detalle de `publico.txt` muestra el
cambio de `SHA256`. La aparición de MD5 o SHA1 en el resumen de la base
no modifica esa política.

## Conclusión y estado antes del punto 10

La prueba detectó los tres cambios solicitados: un archivo agregado,
contenido modificado y permisos cambiados. También detectó el cambio
de tiempos del directorio producido al crear el archivo. La comprobación
limpia anterior permite distinguir estos resultados del estado inicial.

AIDE demuestra diferencias respecto de una referencia, pero no atribuye
los cambios a un usuario o proceso ni recupera el contenido anterior.
Una base local puede ser alterada junto con los archivos si un atacante
obtiene privilegios suficientes; proteger una referencia externa reduce
ese riesgo.

Antes del escenario integrador, conservar esta evidencia y decidir cómo
se distinguirán los cambios del 9.3 de los nuevos cambios del punto 10.
Con la base actual, un nuevo `--check` seguirá informando las diferencias
de esta prueba. No actualizar la base automáticamente ni antes de
comprobar los cambios del escenario.

## Leer a continuación

- [Correlación de evidencia](./44-correlacion-de-evidencias.md)
- [Escenario integrador](./50-escenario-integrador.md)
