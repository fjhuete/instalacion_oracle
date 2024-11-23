#!/usr/bin/env bash
#Autor: Francisco Javier Huete Mejías
#Descripción: Ejecuta la configuración necesaria tras la instalación de Oracle EE 21c en SO basados en Debian

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
fichero_bashrc="/home/debian/.bashrc"

#Parámetros del kernel necesarios
variables_bashrc="
#Variables Oracle
export ORACLE_HOME=/opt/oracle/product/21c/dbhome_1
export ORACLE_SID=ORCLCDB
export ORACLE_BASE=/opt/oracle
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH
export PATH=$ORACLE_HOME/bin:$PATH
export NLS_LANG=SPANISH_SPAIN.UTF8"

#Declaración de funciones

#Utilidades

#Ayuda
mostrar_ayuda() {
echo -e "Uso: $0
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
		echo -e ""$rojo"[E]""$fin_formato"": Este script se debe ejecutar con privilegios de root."
		mostrar_ayuda
		exit 1
	fi
}

#Validar conexión
f_validar_conexion () {
	if ping -c 1 -W 1 8.8.8.8 &> /dev/null; then
		return 0
	else
		echo -e ""$rojo"[E]""$fin_formato"": No hay conexión a Internet para instalar las dependencias."
		exit 1
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

#Funciones del script

#Función que lanza el script /etc/init.d/procps para reiniciar procesos
f_reiniciar_bashrc () {
	$(source ~/.bashrc)
}

#Función añade al fichero .bashrc las variables de entorno necesarias para el funcionamiento de Oracle.
f_variables_bashrc () {
	echo "Configurando las variables de entorno..."
	f_validar_fichero $fichero_bashrc
	local validar_fichero=$?
	if [ $validar_fichero -eq 0 ]; then
		$(echo -e $variables_bashrc >> $fichero_bashrc)
	else
		$(touch $fichero_bashrc && echo $variables_bashrc > $fichero_bashrc)
	fi
	f_reiniciar_bashrc
	echo -e ""$verde"[OK]"$fin_formato": Configuradas las variables de entorno."
}

#Función que arranca el servicio de Oracle
f_arrancar_servicio () {
	echo "Arrancando el servico..."
	$(sudo /etc/init.d/oracledb_ORCLCDB-21c start)
	echo -e ""$verde"[OK]"$fin_formato": Servicio arrancado."
}

#Función principal
if [ "$#" -eq 0 ]; then
	f_variables_bashrc
	f_arrancar_servicio
	exit 0
else
	while getopts "h" opcion; do
		case $opcion in
			h) mostrar_ayuda; exit 0;;
			?) mostrar_ayuda; exit 1 ;;
		esac
	done
fi
