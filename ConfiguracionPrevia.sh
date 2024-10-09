#!/usr/bin/env bash
#Autor: Francisco Javier Huete Mejías
#Descripción: Prepara el sistema para la instalación de Oracle EE 21c en SO basados en Debian

#Declaración de variables

#Color de texto
rojo="\e[1;31m"
verde="\e[1;32m"
amarillo="\e[1;33m"

#Formato
negrita="\e[1m"
parpadeo="\e[1;5m"

fin_formato="\e[0m"

#Variables del script
#Ruta al fichero de configuración que guarda los parámetros del kernel
fichero_kernel="/etc/sysctl.d/60-oracle.conf"

#Parámetros del kernel necesarios
parametros_kernel="# Oracle EE kernel parameters
fs.file-max=6815744
net.ipv4.ip_local_port_range=9000 65000
kernel.shmmax=536870912
kernel.sem=250 32000 100 128"

#Ruta al script de instalación de Oracle
fichero_arranque="/sbin/chkconfig"

#Contenido del script de instalación de Oracle
contenido_arranque="#!/bin/bash
# Oracle EE installer chkconfig hack
file=/etc/init.d/oracle-ee-21c
if [[ ! \`tail -n1 \$file | grep INIT\` ]]; then
echo >> \$file
echo '### BEGIN INIT INFO' >> \$file
echo '# Provides: OracleEE' >> \$file
echo '# Required-Start: \$remote_fs \$syslog' >> \$file
echo '# Required-Stop: \$remote_fs \$syslog' >> \$file
echo '# Default-Start: 2 3 4 5' >> \$file
echo '# Default-Stop: 0 1 6' >> \$file
echo '# Short-Description: Oracle Express Edition' >> \$file
echo '### END INIT INFO' >> \$file
fi
update-rc.d oracle-ee-21c defaults 80 01"

#Ruta al script que establece la configuración óptima de memoria para Oracle
fichero_memoria="/etc/rc2.d/S01shm_load"

#Script que establece la configuración de memoria óptima para
#el funcionamiento de Oracle
contenido_memoria="#!/bin/sh
case "\$1" in
  start)
    mkdir /var/lock/subsys 2>/dev/null
    touch /var/lock/subsys/listener
    rm /dev/shm 2>/dev/null
    mkdir /dev/shm 2>/dev/null
    ;;
  *)
    echo error
    exit 1
    ;;
esac"

#Declaración de funciones

#Utilidades

#Ayuda
mostrar_ayuda() {
echo "Uso: $0
Descripción: Este script configura el sistema para la instalación Oracle EE 21c en máquinas con sistemas operativos basados en Debian.
"$negrita"Este script se debe ejecutar con privilegios de root."$fin_formato"
Es imprescindible contar con espacio de almacenamiento suficiente en el equipo para la instalación del Sistema Gestor de Bases de Datos Oracle.
"$negrita"Se recomienda contar con, al menos, 15GB de espacio de almacenamiento disponible y 2GB de RAM."$fin_formato""
}

#Validar root
f_validar_root () {
	local uid="$UID"
	if [ "$uid" -eq 0 ]; then
		return 0
	else
		echo -e ""$rojo"E""$fin_formato"": Este script se debe ejecutar con privilegios de root."
		mostrar_ayuda
		return 1
	fi
}

#Validar conexión
f_validar_conexion () {
	if ping -c 1 -W 1 8.8.8.8 &> /dev/null; then
		return 0
	else
		return 1
	fi
}

#Validar si un paquete está instalado.
f_paquete_instalado () {
	local paquete="$1"
	if dpkg -l | grep -q "^ii\s*$paquete\s"; then
		return 0
	else
		return 1
	fi
}

#Validar si existe un fichero
f_validar_fichero() {
	if [ ! -f "$1" ]; then
		return 1
	else
		return 0
	fi
}

#Función que comprueba si un paquete está instalado
f_paquete_instalado () {
	local paquete="$1"
	if dpkg -l | grep -q "^ii\s*$paquete\s"; then
		return 0
	else
		return 1
	fi
}

#Funciones del script

#Función que lanza el script /etc/init.d/procps para reiniciar procesos
f_reiniciar_procs () {
	$(systemctl start procps)
}

#Función que valida si el script se ejecuta como root y, si hay conexión,
#comprueba si están instaladas las dependencias y, si no, las instala.
f_dependencias () {
	f_validar_root
	f_validar_conexion
	f_paquete_instalado libaio1 
	local libaio1=$?
	if [ $libaio1 -eq 1 ]; then
		$(apt-get install libaio1 -y) &> /dev/null
	fi
	f_paquete_instalado unixodbc
	local unixodbc=$?
	if [ $unixodbc -eq 1 ]; then
		$(apt-get install unixodbc -y) &> /dev/null
	fi
}

#Función que crea o modifica el fichero de configuración que establece
#los parámetros del kernel.
f_parametros_kernel () {
	f_validar_fichero $fichero_kernel
	local validar_fichero=$?
	if [ $validar_fichero -eq 0 ]; then
		$(echo $parametros_kernel > $fichero_kernel)
	else
		$(touch $fichero_kernel && echo $parametros_kernel > $fichero_kernel)
	fi
	f_reiniciar_procs
}

#Función que crea el script /sbin/chkconfig. Oracle EE usa este fichero
#para arrancar el servicio al iniciar el equipo
f_script_arranque () {
	f_validar_fichero $fichero_arranque
	if [ $? -eq 0 ]; then
		$(echo $contenido_arranque > $fichero_arranque)
	else
		$(touch $fichero_arranque && echo $contenido_arranque > $fichero_arranque)
	fi
}

#Función que crea el directorio y fichero necesario para la configuración
#de memoria óptima para el funcionamiento de Oracle
f_script_memoria () {
	f_validar_fichero $fichero_memoria
	if [ $? -eq 0 ]; then
		$(echo $contenido_memoria > $fichero_memoria)
	else
		$(touch $fichero_memoria && echo $contenido_memoria > $fichero_memoria)
	fi
	$(chmod 775 $fichero_memoria)
}

#Función que valida que se haya creado el enlace simbólico al directorio
#/bin/awk
f_validar_ls () {
	$(ln --symbolic /usr/bin/awk /bin/awk)
	if [ $? -eq 1 ]; then
		return 0
	else
		echo -e ""$amarillo"W"$fin_formato": Error en la creación del enlace simbólico al directorio /bin/awk"
		return 1
	fi
}

#Función que valida la correcta configuración del kernel
f_validar_conf_kernel () {
	filemax=$(sysctl fs.file-max)
	if [ "$filemax" = "fs.file-max = 6815744" ]; then
		return 0
	else
		echo -e ""$amarillo"W"$fin_formato": Error en la configuración del kernel"
		return 1
	fi
}

#Función que finaliza la configuración previa del equipo para la instalación
#de Oracle
f_validar_configuracion_previa () {
	$(mkdir /var/lock/subsys && touch /var/lock/subsys/listener)
	f_validar_ls
	f_validar_conf_kernel
}

#Script principal

if [ "$#" -eq 0 ]; then
	f_dependencias
	f_parametros_kernel
	f_script_arranque
	f_script_memoria
	f_validar_configuracion_previa
	exit 0
else
	while getopts "h" opcion; do
		case $opcion in
			h) mostrar_ayuda; exit 0;;
			?) mostrar_ayuda; exit 1 ;;
		esac
	done
fi
