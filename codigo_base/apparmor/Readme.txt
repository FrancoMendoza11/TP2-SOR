1.Copiar el archivo de la carpeta apparmor al directorio del sistema
Copia el archivo en /etc/apparmor.d/, retirándole la extensión .base para que AppArmor reconozca el perfil con el nombre del binario:

sudo cp usr.local.bin.tp2-reader.base /etc/apparmor.d/usr.local.bin.tp2-reader

2.Cargar y probar en modo permisivo (complain)
Pon el perfil en modo aprendizaje para verificar que no impida la ejecución pero registre accesos indebidos en los logs:

sudo aa-complain /etc/apparmor.d/usr.local.bin.tp2-reader

Para verificar:

udo aa-status | grep tp2-reader. Debe figurar bajo ... profiles are in complain mode..


Ejecutar el binario contra ambos archivos:

/usr/local/bin/tp2-reader /srv/tp2/datos/publico.txt
/usr/local/bin/tp2-reader /srv/tp2/datos/confidencial.txt

Verificar auditoria:

udo dmesg | grep -i apparmor | tail -n 5. Debe mostrar una traza con apparmor="ALLOWED" para confidencial.txt, indicando que el acceso no autorizado fue detectado pero permitido por estar en modo complain.


3.Pasar a modo estricto (enforce) y validar el bloqueo
Aplica el perfil en modo de bloqueo definitivo:

sudo aa-enforce /etc/apparmor.d/usr.local.bin.tp2-reader


Verificar:

sudo aa-status | grep tp2-reader. Ahora debe aparecer bajo ... profiles are in enforce mode..


Volver a ejecutar el binario:

Acceso permitido (debe leer el archivo normalmente):
/usr/local/bin/tp2-reader /srv/tp2/datos/publico.txt

Acceso denegado (debe devolver Permission denied):
/usr/local/bin/tp2-reader /srv/tp2/datos/confidencial.txt


Verificar bloqueo:

sudo dmesg | grep -i apparmor | tail -n 5

Se deberia ver la línea con apparmor="DENIED", profile="/usr/local/bin/tp2-reader" y name="/srv/tp2/datos/confidencial.txt"


