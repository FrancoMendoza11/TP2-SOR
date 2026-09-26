# Correlación de evidencias

> **Alcance:** cómo generar una actividad controlada y correlacionar las observaciones de strace y auditd.
>
> **Cuándo leerlo:** al reunir la evidencia de la parte 3 o redactar qué demuestra cada salida.
>
> **Prerrequisitos:** las notas de [strace](./42-llamadas-al-sistema-y-strace.md) y [auditd](./41-reglas-y-consultas-de-auditd.md).

## Documentos relacionados

- [Resumen de auditoría e integridad](./40-mapa-de-auditoria-e-integridad.md)
- [Llamadas al sistema y strace](./42-llamadas-al-sistema-y-strace.md)
- [Reglas auditd](./41-reglas-y-consultas-de-auditd.md)
- [AIDE](./43-integridad-con-aide.md)
- [Escenario integrador](./50-escenario-integrador.md)

## Secuencia de trabajo y correlación

Esta nota reúne los pasos 2 y 4 de la secuencia de la parte 3. Para cargar reglas y consultar eventos, seguí [41 — reglas y consultas de auditd](./41-reglas-y-consultas-de-auditd.md).

### 2. Generar y observar el evento

Después, ejecutá `tp2-event` bajo `strace`. Una sola ejecución produce varios
efectos observables:

```text
tp2-event
  -> strace observa execve, openat y write
  -> auditd registra la ejecución con la clave tp2_exec
  -> auditd registra la modificación con la clave tp2_datos
  -> eventos.log queda modificado
```

### 4. Correlacionar ambas observaciones

La evidencia de `strace` y la de `ausearch` describen partes de la misma
actividad. La consigna pide relacionar al menos:

- marca de tiempo;
- PID;
- ruta del ejecutable;
- llamada al sistema;
- resultado exitoso o fallido.

No hace falta que ambas salidas tengan exactamente el mismo formato. La
correlación consiste en justificar que los campos compatibles corresponden a
la misma ejecución.

## Leer a continuación

- [AIDE y cambios frente a la línea base](./43-integridad-con-aide.md)
- [Escenario integrador](./50-escenario-integrador.md)
