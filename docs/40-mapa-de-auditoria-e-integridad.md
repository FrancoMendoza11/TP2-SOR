# Auditoría, llamadas al sistema e integridad

> **Alcance:** cómo `strace`, auditd y AIDE ofrecen observaciones complementarias y dónde encontrar sus detalles.
>
> **Cuándo leerlo:** al comenzar la parte 3 o para decidir qué herramienta responde una pregunta concreta.
>
> **Prerrequisitos:** el [resumen del proyecto](./10-resumen-del-proyecto.md); AppArmor es una política distinta, descrita en [30](./30-mapa-de-apparmor.md).

## Documentos relacionados

- [Reglas y consultas de auditd](./41-reglas-y-consultas-de-auditd.md)
- [Llamadas al sistema y strace](./42-llamadas-al-sistema-y-strace.md)
- [Línea base e integridad con AIDE](./43-integridad-con-aide.md)
- [Correlación de evidencia](./44-correlacion-de-evidencias.md)
- [Escenario integrador](./50-escenario-integrador.md)

## Contenido del área

- [Auditd](./41-reglas-y-consultas-de-auditd.md): reglas, carga y consulta de eventos.
- [Llamadas al sistema y strace](./42-llamadas-al-sistema-y-strace.md): operaciones de una ejecución puntual.
- [AIDE](./43-integridad-con-aide.md): diferencias frente a una línea base.
- [Correlación](./44-correlacion-de-evidencias.md): relaciona esas evidencias.

## Objetivo general

El punto 9 busca observar una misma actividad desde perspectivas diferentes:

- `strace` muestra las llamadas al sistema realizadas durante una ejecución.
- `auditd` conserva eventos de seguridad para consultarlos posteriormente.
- AIDE compara el estado actual de los archivos con una línea base anterior.

Estas herramientas no se reemplazan entre sí. `strace` explica cómo interactúa
un proceso con el núcleo, `auditd` deja evidencia persistente de operaciones
seleccionadas y AIDE detecta diferencias en el estado de los archivos.

## Diferencias entre las herramientas

| Herramienta | Pregunta que ayuda a responder |
| --- | --- |
| `strace` | ¿Qué llamadas al sistema realizó esta ejecución concreta? |
| `auditd` | ¿Qué actividad seleccionada quedó registrada para consultar después? |
| AIDE | ¿Qué archivos o atributos difieren de la línea base? |

Ejemplo de interpretación conjunta:

```text
strace muestra que tp2-event abrió y escribió eventos.log.
auditd conserva la ejecución y la modificación bajo sus claves.
AIDE detecta que eventos.log ya no coincide con la línea base.
```

## Relación con AppArmor

El punto 9 puede realizarse sin haber completado el punto 8. El perfil de
AppArmor del punto 8 se aplica a `tp2-reader`, mientras que la correlación del
punto 9 usa principalmente `tp2-event`.

La dependencia aparece en el escenario integrador del punto 10, que requiere
simultáneamente AppArmor en modo `enforce`, las reglas de auditd cargadas y la
base de AIDE activa.

## Leer a continuación

- [Reglas auditd](./41-reglas-y-consultas-de-auditd.md)
- [Llamadas al sistema y strace](./42-llamadas-al-sistema-y-strace.md)
- [AIDE](./43-integridad-con-aide.md)
