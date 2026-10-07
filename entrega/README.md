# Trabajo Práctico 2 - Seguridad en Sistemas Operativos (TP2-Sor)

¡Hola! Este es el repositorio con la solución del **Trabajo Práctico 2** para la materia **Sistemas Operativos y Redes II (A0533)** de la UNGS.

Acá adentro vas a encontrar todo lo que armamos para la parte de Hardening, perfiles de AppArmor, reglas de auditoría con `auditd`, la base de integridad con `AIDE` y las pruebas de traza con `strace`.

## 👥 Integrantes

* **[Nombre y Apellido]**
* **[Nombre y Apellido]**
* **[Nombre y Apellido]**

## 💻 Entorno utilizado

Para probar y validar que todo funcionara como pide la cátedra, usamos:

* **SO:** Ubuntu Server 24.04 LTS (amd64).
* **Entorno:** Máquina virtual aislada (VirtualBox / VMware).
* **Snapshot de seguridad:** `TP2_BASE` (creado justo después de preparar el entorno inicial).
* **Herramientas:** `gcc`, `make`, `AppArmor`, `auditd`, `AIDE`, `strace`, `OpenSSH Server`.

## 🚀 Orden de ejecución (Paso a paso)

Para levantar la solución desde cero sin que falle nada, se corre en este orden:

### 1. Preparar el entorno inicial

Primero hay que instalar los paquetes necesarios, compilar los binarios (`tp2-reader` y `tp2-event`) y armar el directorio de trabajo `/srv/tp2`:

```bash
sudo ./scripts/preparar_entorno.sh --install-packages
```

> **Importante:** Una vez ejecutado este paso, sacá el **Snapshot `TP2_BASE`** en tu máquina virtual.

### 2. Verificar que el entorno esté listo

Corremos la verificación pública de la cátedra para estar seguros de que no falta nada:

```bash
sudo ./tests/public_checks.sh --entorno
```

### 3. Aplicar el Hardening del sistema

Aplicamos las políticas de hardening (SSH, umask 027, calidad de contraseñas con PAM y variables sysctl de enlaces protegidos):

```bash
# Para verificar qué falta aplicar:
sudo ./hardening/hardening.sh --check

# Para aplicar las configuraciones:
sudo ./hardening/hardening.sh --apply

# (Si volvés a correr --apply vas a ver que no duplica cambios y marca SKIPPED, demostrando idempotencia).
```

### 4. Cargar y probar AppArmor

Configuramos el perfil de `tp2-reader` para permitir leer el archivo público pero bloquear el confidencial:

```bash
# Copiamos el perfil
sudo cp apparmor/usr.local.bin.tp2-reader /etc/apparmor.d/usr.local.bin.tp2-reader

# Probamos primero en modo permisivo (complain) para ver el log de advertencia
sudo aa-complain /usr/local/bin/tp2-reader
/usr/local/bin/tp2-reader /srv/tp2/datos/confidencial.txt

# Pasamos a modo estricto (enforce) para bloquear el acceso
sudo aa-enforce /usr/local/bin/tp2-reader
/usr/local/bin/tp2-reader /srv/tp2/datos/confidencial.txt  # Debe dar error de permisos
```

### 5. Cargar reglas de auditd

Para auditar cambios en `/srv/tp2/datos` y las ejecuciones de `tp2-event`:

```bash
sudo cp audit/99-tp2.rules /etc/audit/rules.d/99-tp2.rules
sudo augenrules --load
sudo auditctl -l | grep tp2_
```

### 6. Inicializar AIDE (Monitoreo de integridad)

Generamos la base de datos local para detectar modificaciones en los archivos:

```bash
sudo install -m 0644 aide/aide.conf /srv/tp2/config/aide.conf
sudo aide --config=/srv/tp2/config/aide.conf --init
sudo mv /srv/tp2/aide/aide.db.new /srv/tp2/aide/aide.db

# Para verificar la integridad en cualquier momento:
sudo aide --config=/srv/tp2/config/aide.conf --check
```

### 7. Correr el escenario final de prueba

Una vez armado todo, ejecutamos la prueba integradora:

```bash
sudo ./scripts/escenario_final.sh
```

Y para comprobar que todo esté listo para la entrega final del grupo:

```bash
./tests/public_checks.sh --entrega
```

## ⚠️ Problemas relevantes y resoluciones

A lo largo del desarrollo nos topamos con un par de detalles a tener en cuenta:

1. **AppArmor no detectaba los eventos en `dmesg` / `journalctl`:**
   * **Causa:** Al tener `auditd` activo en la VM, los eventos de AppArmor son capturados directamente por la auditoría del kernel e iban a parar a `/var/log/audit/audit.log` o `ausearch`.
   * **Solución:** Buscamos los accesos usando `sudo ausearch -m avc -ts recent` o `sudo grep apparmor /var/log/audit/audit.log` en lugar de confiarnos solo de `dmesg`.

2. **Error al aplicar configuraciones de SSH en hardening:**
   * **Causa:** Si usás `sshd -t` para validar pero el servicio no estaba iniciado previamente o faltaban llaves del host, tiraba error.
   * **Solución:** Nos aseguramos de tener el paquete `openssh-server` habilitado e iniciado con `systemctl start ssh` antes de correr el script de hardening.

3. **Restaurar el estado del laboratorio:**
   * Si en algún momento queríamos volver atrás para repetir pruebas desde cero, usábamos el script auxiliar `./scripts/restaurar_entorno.sh` o directamente volvíamos al Snapshot `TP2_BASE` de la máquina virtual (que es la forma más limpia y recomendada).