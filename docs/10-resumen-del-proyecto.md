# Resumen del proyecto

> **Alcance:** presenta el objetivo del TP2 de Seguridad en Sistemas Operativos, sus áreas técnicas y cómo se relacionan.
>
> **Cuándo leerlo:** primero, si todavía no conocés el proyecto; volvé acá para decidir qué área consultar.
>
> **Prerrequisitos:** ninguno. La [consigna oficial](./01-consigna-oficial.pdf) es la fuente de requisitos completa.

## Qué es el proyecto

El TP2 protege y observa una máquina GNU/Linux desde tres perspectivas complementarias: reducir configuraciones riesgosas, limitar las operaciones de una aplicación y conservar evidencia sobre actividad y cambios de archivos. El entorno oficial es una VM aislada con Ubuntu Server 24.04 LTS amd64; los programas `tp2-reader` y `tp2-event` son aplicaciones de laboratorio controladas.

## Áreas de conocimiento

- [Endurecimiento del sistema](./20-mapa-de-endurecimiento.md): controles para UID 0, OpenSSH, calidad de contraseñas, umask y protecciones del núcleo.
- [AppArmor](./30-mapa-de-apparmor.md): control de acceso obligatorio asociado al ejecutable `tp2-reader`.
- [Auditoría, llamadas al sistema e integridad](./40-mapa-de-auditoria-e-integridad.md): `strace` observa una ejecución, `auditd` conserva eventos seleccionados y AIDE compara archivos con una línea base.
- [Escenario integrador](./50-escenario-integrador.md): relaciona AppArmor, auditd y AIDE en una ejecución controlada.
- [Entorno y flujo de trabajo](./11-entorno-y-flujo-de-trabajo.md): preparación de la VM, instantánea, comprobaciones públicas y entrega.

## Cómo se relacionan las áreas

1. El endurecimiento configura políticas de seguridad a nivel del equipo anfitrión.
2. AppArmor aplica una política asociada a `tp2-reader`; la política puede permitir `publico.txt` y bloquear `confidencial.txt`.
3. `strace` muestra las llamadas al sistema de una ejecución concreta; `auditd` conserva los eventos seleccionados por reglas.
4. AIDE compara el estado observado con una línea base. No identifica por sí solo qué proceso hizo un cambio.
5. El escenario integrador combina estas perspectivas para reconstruir qué se permitió, qué se bloqueó, qué quedó auditado y qué cambió.

## Ruta de lectura sugerida

1. [Índice de la base](./00-indice.md).
2. [Este resumen](./10-resumen-del-proyecto.md) y [entorno/flujo](./11-entorno-y-flujo-de-trabajo.md).
3. Elegí el resumen del área que necesites: [endurecimiento](./20-mapa-de-endurecimiento.md), [AppArmor](./30-mapa-de-apparmor.md) o [auditoría e integridad](./40-mapa-de-auditoria-e-integridad.md).
4. Después, abrí las notas específicas enlazadas desde ese resumen.
5. Leé [el escenario integrador](./50-escenario-integrador.md) cuando las tres áreas estén configuradas.

## Documentos relacionados

- [Índice global](./00-indice.md)
- [Consigna oficial (PDF)](./01-consigna-oficial.pdf)
- [Preparación y entrega](./11-entorno-y-flujo-de-trabajo.md)
