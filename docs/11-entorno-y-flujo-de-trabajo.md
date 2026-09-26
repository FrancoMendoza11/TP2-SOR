# Entorno y flujo de trabajo

> **Alcance:** las restricciones del entorno oficial, el orden de ejecución y las comprobaciones públicas del TP2.
>
> **Cuándo leerlo:** antes de modificar la VM y cada vez que necesites verificar el avance o preparar la entrega.
>
> **Prerrequisitos:** la [consigna oficial](./01-consigna-oficial.pdf) y el [resumen del proyecto](./10-resumen-del-proyecto.md).

## Documentos relacionados

- [Consigna oficial](./01-consigna-oficial.pdf)
- [Resumen del proyecto](./10-resumen-del-proyecto.md)
- [Endurecimiento](./20-mapa-de-endurecimiento.md)
- [AppArmor](./30-mapa-de-apparmor.md)
- [Auditoría e integridad](./40-mapa-de-auditoria-e-integridad.md)
- [Escenario integrador](./50-escenario-integrador.md)

Este paquete contiene la consigna y el código base del TP2 de Sistemas Operativos y Redes II.

## Entorno oficial

- Ubuntu Server 24.04 LTS amd64.
- Máquina virtual aislada.
- Instantánea obligatoria antes de aplicar cambios.
- Trabajo grupal con defensa oral individual.

## Orden recomendado

1. Leer la consigna completa.
2. Crear la VM y la instantánea inicial.
3. Ejecutar `sudo ./scripts/preparar_entorno.sh --install-packages` desde `codigo_base`.
4. Ejecutar `sudo ./tests/public_checks.sh --entorno` para confirmar que la VM quedó lista.
5. Completar el endurecimiento, el perfil AppArmor, las reglas auditd y la configuración AIDE.
6. Guardar evidencia después de cada etapa.
7. Ejecutar el escenario integrador.
8. Ejecutar `./tests/public_checks.sh --entrega` antes de armar el ZIP del grupo.
9. Preparar el informe y la defensa.

## Comprobaciones públicas

El script `tests/public_checks.sh` admite tres modos:

- `--estructura` (por defecto): verifica el material provisto y la compilación.
- `--entorno`: agrega la verificación de la VM preparada. Requiere `sudo`.
- `--entrega`: agrega la verificación de los cuatro entregables completos.

## Documentación complementaria

- [Punto 8: AppArmor](30-mapa-de-apparmor.md)
- [Punto 9: auditoría, llamadas al sistema e integridad](40-mapa-de-auditoria-e-integridad.md)

Los archivos terminados en `.base` y `hardening_base.sh` son plantillas de la
cátedra: conservan sus bloques `TODO` de forma intencional y no deben
modificarse ni eliminarse. Sus versiones completas se guardan con el nombre
definitivo indicado en la consigna.

## Importante

- No uses este TP en tu computadora personal ni en un servidor real.
- No modifiques archivos del sistema fuera de los indicados.
- Si algo falla, frená, guardá la evidencia y volvé a la instantánea si hace falta.
- Las guías y los apuntes de la cátedra contienen la teoría necesaria; la documentación oficial puede usarse para detalles operativos.

## Leer a continuación

- [Resumen del proyecto](./10-resumen-del-proyecto.md)
- [Índice global](./00-indice.md)
