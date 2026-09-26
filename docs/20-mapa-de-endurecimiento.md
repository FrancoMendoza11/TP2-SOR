# Endurecimiento: requisitos y alcance

> **Alcance:** los controles de endurecimiento exigidos por el TP y cómo se verifican.
>
> **Cuándo leerlo:** para obtener el mapa de la parte 1 antes de abrir detalles de implementación.
>
> **Prerrequisitos:** el [resumen del proyecto](./10-resumen-del-proyecto.md) y el [flujo de trabajo](./11-entorno-y-flujo-de-trabajo.md).

## Documentos relacionados

- [SSH y bloqueo de root](./21-endurecimiento-ssh.md)
- [Calidad de contraseñas y PAM](./22-calidad-de-contrasenas.md)
- [Umask de sesión](./23-umask-de-sesion.md)
- [Protecciones con sysctl](./24-protecciones-del-nucleo-con-sysctl.md)
- [Arquitectura del script](./25-script-de-endurecimiento.md)

## Leer a continuación

- [Implementación del script](./25-script-de-endurecimiento.md)
- [Entorno y flujo de trabajo](./11-entorno-y-flujo-de-trabajo.md)

## Parte 1: script de endurecimiento

### Objetivo

Completar una copia de `hardening/hardening_base.sh` y guardarla como
`hardening/hardening.sh`. La plantilla entregada por la cátedra no debe
modificarse.

El script debe reducir configuraciones riesgosas de Ubuntu, informar el estado
del sistema y permitir aplicar o revertir los cambios de forma segura.

### Controles requeridos

1. **UID 0**
   - Detectar cuentas distintas de `root` con UID 0.
   - Informar la desviación, pero no corregirla automáticamente.

2. **OpenSSH**
   - Crear un fragmento separado en `sshd_config.d`.
   - Establecer `PermitRootLogin no`.
   - Validar la configuración con `sshd -t` antes de recargar SSH.
   - Confirmar la configuración efectiva con `sshd -T`.

3. **Calidad de contraseñas**
   - Crear una política acotada en `pwquality.conf.d`.
   - Definir y justificar los valores elegidos.
   - Confirmar que `pam_pwquality.so` esté activo en PAM.

4. **Umask**
   - Crear un archivo en `profile.d` que configure `umask 027`.
   - Verificar el resultado en una sesión nueva creando un archivo.

5. **Enlaces protegidos**
   - Persistir en `sysctl.d` los valores:
     - `fs.protected_hardlinks = 1`
     - `fs.protected_symlinks = 1`
   - Comprobar tanto el archivo como los valores efectivos del núcleo.

### Modos de ejecución

El script debe aceptar:

```text
sudo ./hardening/hardening.sh --check
sudo ./hardening/hardening.sh --apply
sudo ./hardening/hardening.sh --restore
```

- `--check`: consulta el estado y no modifica nada.
- Primera ejecución de `--apply`: aplica únicamente los cambios necesarios.
- Segunda ejecución de `--apply`: no repite cambios y registra `SKIPPED`.
- `--restore`: recupera los respaldos o elimina los fragmentos que no existían
  antes.

### Comportamiento general

- Usar las funciones auxiliares provistas por la plantilla para respaldos,
  escritura, conteo y registro.
- Respaldar cada archivo antes de modificarlo.
- Mantener los contadores de acciones y errores.
- Registrar todas las acciones en:

```text
/var/log/tp2-hardening.log
```

El registro debe incluir fecha, control y estado (`APPLIED`, `SKIPPED`, `CHECK` o
`ERROR`).

### Evidencia que se debe conservar

- Resultado de `--check` antes de aplicar cambios.
- Primera ejecución de `--apply`.
- Segunda ejecución de `--apply`, mostrando la idempotencia.
- Fragmentos creados y comandos de validación.
- Prueba de `--restore` o explicación del uso de la instantánea para la restauración
  final.
- Análisis de un riesgo reducido por un control.
- Explicación de por qué dos ejecuciones de `--apply` no producen cambios
  adicionales.

### Restricciones importantes

- Trabajar únicamente en la VM Ubuntu Server 24.04 LTS del TP.
- Crear la instantánea `TP2_BASE` antes de aplicar cambios.
- Mantener acceso por consola antes de modificar SSH.
- No eliminar ni modificar `hardening_base.sh`.
