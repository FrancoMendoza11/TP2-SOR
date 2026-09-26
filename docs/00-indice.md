# Base de conocimiento del TP2

Arrancá por acá si todavía no conocés el proyecto. Esta base reúne notas de orientación, conceptos y procedimientos del Trabajo Práctico 2 de Seguridad en Sistemas Operativos.

## Cómo se organiza

Los números son direcciones dentro de la base: identifican el área temática de una nota, no su nivel de detalle. Los documentos de una misma decena pertenecen a un dominio relacionado. Los espacios libres quedan disponibles para futuras notas; evitá renumerar documentos existentes cuando se agregue contenido.

## Áreas

- **00–09 — Navegación y fuentes:** [consigna oficial](./01-consigna-oficial.pdf).
- **10–19 — Orientación y entorno:** [resumen del proyecto](./10-resumen-del-proyecto.md) y [preparación/flujo de trabajo](./11-entorno-y-flujo-de-trabajo.md).
- **20–29 — Endurecimiento del sistema:** [resumen de endurecimiento](./20-mapa-de-endurecimiento.md).
- **30–39 — Control de acceso obligatorio:** [resumen de AppArmor](./30-mapa-de-apparmor.md).
- **40–49 — Auditoría, llamadas al sistema e integridad:** [resumen de auditd, strace y AIDE](./40-mapa-de-auditoria-e-integridad.md).
- **50–59 — Integración entre dominios:** [escenario integrador](./50-escenario-integrador.md).

Cada resumen de área funciona como un mapa local y enlaza a las notas específicas. No hay por ahora un área 90: las instrucciones operativas existentes están junto al flujo del proyecto en el área 10.

## Por dónde empezar

Si recién llegás al proyecto:

1. Leé el [resumen del proyecto](./10-resumen-del-proyecto.md).
2. Revisá el [entorno, la secuencia de trabajo y las comprobaciones](./11-entorno-y-flujo-de-trabajo.md).
3. Abrí el resumen del dominio que necesites: [endurecimiento](./20-mapa-de-endurecimiento.md), [AppArmor](./30-mapa-de-apparmor.md) o [auditoría/integridad](./40-mapa-de-auditoria-e-integridad.md).
4. Desde ese resumen, seguí los enlaces a los detalles mínimos necesarios.
5. Cuando las partes estén completas, leé el [escenario integrador](./50-escenario-integrador.md).

## Ruta breve para agentes

1. Leer este índice.
2. Elegir un área por su resumen.
3. Seguir los enlaces explícitos a los detalles requeridos para la tarea.
4. Consultar otras áreas solo si el resumen o los enlaces relacionados muestran una dependencia.

## Fuente de requisitos

La [consigna oficial del curso (PDF)](./01-consigna-oficial.pdf) define el alcance y las evidencias requeridas. Estas notas complementan la consigna; no la sustituyen.
