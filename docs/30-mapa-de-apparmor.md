# AppArmor

> **Alcance:** explica el papel de AppArmor en el TP, su relación con los permisos Unix y auditd, y el mapa de esta área.
>
> **Cuándo leerlo:** antes de crear/cargar el perfil o al necesitar distinguir AppArmor de auditoría.
>
> **Prerrequisitos:** el [resumen del proyecto](./10-resumen-del-proyecto.md); conviene conocer qué recursos usa `tp2-reader`.

## Documentos relacionados

- [Perfil AppArmor: instalación y pruebas](./31-perfil-apparmor-instalacion-y-pruebas.md)
- [Auditoría, llamadas al sistema e integridad](./40-mapa-de-auditoria-e-integridad.md)
- [Escenario integrador](./50-escenario-integrador.md)

## Contenido del área

- [Perfil, carga y pruebas `complain`/`enforce`](./31-perfil-apparmor-instalacion-y-pruebas.md)

## Objetivo

AppArmor limita las operaciones que puede realizar un programa mediante un
perfil asociado a su ejecutable. En este TP, el perfil de
`/usr/local/bin/tp2-reader` permite leer `publico.txt` y no concede permiso para
leer `confidencial.txt`.

AppArmor es un mecanismo de control de acceso obligatorio (MAC) integrado con
el núcleo de Linux. Se suma a los permisos Unix tradicionales: una operación
solo tiene éxito si la permiten tanto los permisos tradicionales como el perfil
de AppArmor.

## AppArmor y los servicios en segundo plano

AppArmor no funciona como `sshd`, que permanece a la espera de conexiones. El
servicio de AppArmor suele cargar los perfiles durante el arranque; el núcleo
mantiene las políticas cargadas y las consulta cuando los procesos intentan
acceder a archivos u otros recursos. No se inicia un servicio nuevo cada vez que
se ejecuta un programa.

Por lo tanto, AppArmor se aplica durante las operaciones de los procesos,
pero no es un mecanismo que se active a demanda solo cuando alguien lo solicita:
los perfiles deben estar cargados y activos. Las herramientas `aa-status`,
`aa-complain` y `aa-enforce` permiten consultar y cambiar su estado.

AppArmor es una tecnología nativa del ecosistema Linux, implementada mediante
el marco de módulos de seguridad de Linux (LSM). Que el núcleo la soporte no implica
que esté habilitada en toda distribución o instalación; verificá su estado en la
máquina de trabajo.

## Relación con `auditd`

AppArmor y `auditd` se complementan, pero tienen responsabilidades diferentes:

| Componente | Función |
| --- | --- |
| AppArmor | Decide si una operación está permitida por el perfil y puede bloquearla. |
| Núcleo | Aplica la política y genera eventos de seguridad para accesos permitidos en modo `complain` o denegados en modo `enforce`. |
| `auditd` | Recibe y conserva eventos del subsistema de auditoría para consultarlos después, según la configuración del sistema. |

AppArmor puede generar mensajes de auditoría visibles en el registro del núcleo
y, según la configuración, en los registros de `auditd`. `auditd` no es
necesario para que AppArmor aplique los perfiles, y las reglas de `auditd` no
definen qué archivos permite AppArmor. Para este ejercicio, primero verificá el
evento en el registro del núcleo; para una consulta persistente, también podés
revisar el registro de auditoría.
## Leer a continuación

- [Perfil AppArmor: instalación y pruebas](./31-perfil-apparmor-instalacion-y-pruebas.md)
