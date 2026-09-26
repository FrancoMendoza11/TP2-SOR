# Integridad de archivos con AIDE

> **Alcance:** cómo AIDE compara los archivos con una línea base y qué tipos de cambios puede detectar.
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

## Leer a continuación

- [Correlación de evidencia](./44-correlacion-de-evidencias.md)
- [Escenario integrador](./50-escenario-integrador.md)
