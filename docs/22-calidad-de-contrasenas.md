# Calidad de contraseñas y PAM

> **Alcance:** la política de contraseñas `pwquality` y su conexión con PAM.
>
> **Cuándo leerlo:** cuando revises el control de calidad de contraseñas o por qué una política necesita que PAM cargue el módulo.
>
> **Prerrequisitos:** el [resumen de endurecimiento](./20-mapa-de-endurecimiento.md).

## Documentos relacionados

- [Endurecimiento: requisitos y mapa local](./20-mapa-de-endurecimiento.md)
- [Arquitectura del script y funciones auxiliares](./25-script-de-endurecimiento.md)

## Implementación del control

Se implementó una política acotada de calidad de contraseñas y se comprobó que
el módulo que la aplica esté integrado con PAM.

### Cuándo se lee `pwquality.conf.d`

Los archivos de `/etc/security/pwquality.conf.d/` no se ejecutan durante el
arranque. Son archivos declarativos que `libpwquality` lee cuando debe evaluar
una contraseña, normalmente a través de `pam_pwquality.so` durante un cambio de
contraseña.

El flujo habitual en Ubuntu es:

1. El usuario ejecuta `passwd`.
2. `passwd` solicita a PAM una operación de cambio de contraseña.
3. PAM lee la configuración del servicio en `/etc/pam.d/passwd`.
4. Esa configuración incluye normalmente la pila definida en
   `/etc/pam.d/common-password`.
5. Si la pila carga `pam_pwquality.so`, el módulo obtiene la política de
   `libpwquality`, incluyendo `/etc/security/pwquality.conf` y los fragmentos de
   `/etc/security/pwquality.conf.d/`.
6. La nueva contraseña se acepta o rechaza según el resultado de la política.

Por este motivo, modificar el fragmento no requiere reiniciar el sistema. La
política se utiliza en el siguiente cambio de contraseña que pase por esa pila
PAM.

Los archivos de `/etc/pam.d/` tampoco son scripts. PAM los interpreta cuando
una aplicación como `passwd`, `sudo`, `login` o `sshd` solicita un servicio de
autenticación o administración de credenciales. Cada aplicación usa una pila
PAM determinada, por lo que encontrar `pam_pwquality.so` en cualquier archivo
de `/etc/pam.d` demuestra que está referenciado, pero no garantiza por sí solo
que intervenga en todos los cambios de contraseña. En Ubuntu, la referencia
relevante suele estar en la pila `password` de `common-password`.

### Significado de `minclass = 3`

Exige que la contraseña use caracteres de al menos tres de estas cuatro clases:

1. Letras minúsculas.
2. Letras mayúsculas.
3. Dígitos.
4. Otros caracteres, como símbolos.

Por ejemplo, `ClaveSegura123` utiliza minúsculas, mayúsculas y dígitos, por lo
que satisface esta condición. Una contraseña formada solamente por letras
minúsculas y mayúsculas utiliza dos clases y no la satisface.

Esta opción solo verifica la diversidad de clases. La contraseña también debe
cumplir `minlen` y las demás reglas activas de `libpwquality`.

### Significado de `maxrepeat = 3`

Permite como máximo tres apariciones consecutivas del mismo carácter. Por
ejemplo:

- `Claveaaa123` no supera el límite de repetición;
- `Claveaaaa123` se rechaza por contener cuatro letras `a` consecutivas;
- `Clave1111Segura` se rechaza por contener cuatro dígitos `1` consecutivos.

La opción no limita la cantidad total de veces que un carácter puede aparecer.
Por ejemplo, `a1a2a3a4` no infringe `maxrepeat = 3`, porque las letras `a` no
están consecutivas.

### Modo `--check`

- Verifica las tres opciones del fragmento.
- Confirmá que algún archivo de `/etc/pam.d` cargue `pam_pwquality.so`.
- Marca error si la política existe pero PAM no la utiliza.

### Modo `--apply`

- No escribe la política si `pam_pwquality.so` no está activo, porque quedaría
  una configuración persistida pero inoperante.
- Si el fragmento ya coincide, registra `SKIPPED`.
- En caso contrario, respalda el estado previo y escribe la política con
  permisos `0644`.

### Modo `--restore`

Usa la restauración común: recupera el archivo anterior o elimina el fragmento
si fue creado por primera vez durante el TP.

## Leer a continuación

- [Arquitectura del script](./25-script-de-endurecimiento.md)
- [Endurecimiento SSH](./21-endurecimiento-ssh.md)
