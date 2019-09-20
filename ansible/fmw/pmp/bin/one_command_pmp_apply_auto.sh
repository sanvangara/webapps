#!/bin/bash
############################################################################################################################################
# * Filename            :       one_command_pmp_apply_auto.sh
# * Author              :       rtatinen
# * Original            :       16/11/2018
############################################################################################################################################
#	Version		Last Modified	Modified by		Description
#	#########	##############	############	################
# * v2.0  		26/07/2018    	rtatinen        Tech Stack PMP July 2018 Execution
#                                               + Applies JUL18 PSU patch for Weblogic version's starting from 10.3.3.6 to 12.2.1.3
#                                               + Applies JUL18 CPU patch for OHS version's starting from 11.1.1.6 to 12.2.1.3
#                                               + Applies JUL18 PSU patch for Java version's starting from 1.6 (JRockit) and 1.6, 1.7 & 1.8 (JDK)
#                                               + Includes Post Patch steps for OHS patches
# * v3.0  		30/08/2018    	rtatinen        Changed the way to capture the Arguments to fit for ATOM
# * v4.0  		06/09/2018    	rtatinen        Using the HOME/.<sid>_pmp.env file as source of required varialbes created by planning Script
# * v5.0  		06/09/2018    	rtatinen        Modified Script to Patch Mutilple Java , WLS and OHS HOMES on Single node
# * v6.0  		08/09/2018    	rtatinen        Modified Script to takecare of Weblogic Patches on DMZ nodes starting from 12c OHS
# * v7.0  		24/09/2018    	rtatinen        Included weblogic JDBC Drivers upgrade
# * v8.0  		25/09/2018    	rtatinen        Simplied the code for better usage for upcoming releases
# * v9.0  		16/11/2018    	rtatinen        Included Patches for October-2018 CPU
# * v10.0  		19/01/2019	 	rtatinen		Included January 2019 CPU Patch(s) OTM, Weblogic, OHS & Java 
# * v11.0  		19/01/2019	 	rtatinen		Included January 2019 CPU Patch(s) for SOA,OSB,Webcenter,OTD
# * v12.0  		19/01/2019	 	rtatinen		Included January 2019 CPU Patch(s) oracle_common [ opss,owsm,adf,fmw,oss,jrf,fmw_platform ]
# * v13.0  		18/04/2019	 	rtatinen		Included steps to clear cache and tmp for all admin and managed servers after patching
# * v14.0  		24/04/2019	 	rtatinen		Included January 2019 CPU Patch(s) OID,OVD,OUD, IDM 12c 
# * v15.0  		01/05/2019	 	rtatinen		Included April 2019 CPU Patch(s) OTM, Weblogic, OHS & Java 
# * v16.0  		02/05/2019	 	rtatinen		Included April 2019 CPU Patch(s) oracle_common [ opss,owsm,adf,fmw,oss,jrf,fmw_platform ]
# * v17.0  		03/05/2019	 	rtatinen		Included April 2019 CPU Patch(s) for SOA,OSB,Webcenter,OTD,OID,OVD,OUD, IDM 12c 
# * v18.0  		07/05/2019 		rtatinen		Included skip option for Java and JDBC
# * v19.0  		08/05/2019 		rtatinen		Included skip and include options for Java, Jdbc, Weblogic and OHS
###########################################################################################################################################
# Usage : Run ./one_command_pmp_apply_apr19.sh -m <cpu_release> -a <auto/manual> -i <jdbc,java/java/jdbc> -s <jdbc,java/java/jdbc>
#
############################################################################################################################################
RED='\033[01;31m'
GREEN='\033[01;32m'
YELLOW='\033[01;33m'
BLUE='\033[01;34m'
CYAN='\033[01;36m'
PUR='\033[01;35m'
BOLD='\033[1m'
ITA='\033[44m'
RESET='\033[0m'
if [ `whoami` = "root" ]; then
echo -e "${RED}**************************************************************"
echo -e "Current Login User is : root"
echo -e "You must login as application user to run this script."
echo -e "**************************************************************${RESET}"
fail_mail
fi

st=$(date +"%s")
echo " "
echo "$0 : Script Started at `date`"
echo " "
#operation_type=$( echo "$2" | tr  '[:upper:]' '[:lower:]' )
#release_month=$( echo "$1" | tr  '[:upper:]' '[:lower:]' )
#SKIP=$( echo "$3" | tr  '[:lower:]' '[:upper:]' )
TECHPMPPROPFILE="$HOME/.fmwpmp.env"
OTMPMPPROPFILE="$HOME/.otmpmp.env"
PMP_SCRIPT_TOP=/usr/local/MAS/fmw/pmp
CPU_PATCH_TOP=$HOME/cpu_patches

echo ""
now=$(date +"%m%d%Y")
LOG_DIR=$CPU_PATCH_TOP/logs/pmp/execution/${now}
#HOST=`hostname`
HOST=`cat /etc/passwd| grep compute|cut -f2 -d"@"`
if [[ -z $HOST ]]; then
HOST=`cat /etc/passwd| grep oracleoutsourcing|cut -f2 -d"@"`
if [[ -z $HOST ]]; then
HOST=`hostname`
fi
fi
DATE=`date +"%m-%d-%Y-%H%M-%S"`
excluded_certs=$PMP_SCRIPT_TOP/excluded_certs.txt
scriptname=`basename $0`
#scriptname=${scriptfullname%.*}

mkdir -p ${LOG_DIR}/${HOST}
if [[ -d ${LOG_DIR}/${HOST} ]]; then
   echo "Log File Location : $LOG_DIR"
else
   echo -e "${RED}Not able to create Log file Location, Make sure we have required privielges to creae files under $CPU_PATCH_TOP"${RESET}
   fail_mail
fi

service_active_check()
{
pid_list_wl=($(ps -eo pid,cmd|grep "Dweblogic.Name="|egrep -v 'grep|oem1|agent12c|emcadm|emagent|odhagent|jenkins'|awk -F" " '{print $1}'))
pid_list_ohs=($(ps -eo pid,cmd| grep httpd | egrep -v 'grep|oem1|agent12c|emcadm|emagent|odhagent|jenkins'|awk -F" " '{print $1}'))
pid_list_otd=($(ps -eo pid,cmd| grep trafficd | egrep -v 'grep|oem1|agent12c|emcadm|emagent|odhagent|jenkins'|awk -F" " '{print $1}'))
if [[ ${#pid_list_wl[@]} == 0 ]] && [[ ${#pid_list_ohs[@]} == 0 ]] && [[ ${#pid_list_otd[@]} == 0 ]]; then
        echo -e ${GREEN}"All Services are down on $HOST. Proceeding with Patching Activity"${RESET}
		echo -e ""
		apply_go_check
elif [[ ${#pid_list_wl[@]} != 0 ]] && [[ ${#pid_list_ohs[@]} != 0 ]] && [[ ${#pid_list_otd[@]} == 0 ]]; then
        echo -e ${RED}"Weblogic and OHS Services are still UP on $HOST. Can't Proceeding with Patching Activity"
		echo -e "Please Bringdown the services completely and rerun the Apply script"${RESET}
		fail_mail
elif [[ ${#pid_list_wl[@]} != 0 ]] && [[ ${#pid_list_ohs[@]} == 0 ]] && [[ ${#pid_list_otd[@]} != 0 ]]; then
        echo -e ${RED}"Weblogic and OTD Services are still UP on $HOST. Can't Proceeding with Patching Activity"
		echo -e "Please Bringdown the services completely and rerun the Apply script"${RESET}
		fail_mail
elif [[ ${#pid_list_wl[@]} != 0 ]] && [[ ${#pid_list_ohs[@]} == 0 ]] && [[ ${#pid_list_otd[@]} == 0 ]]; then
        echo -e ${RED}"Weblogic services are still UP on $HOST. Can't Proceeding with Patching Activity"
		echo -e "Please Bringdown the services completely and rerun the Apply script"${RESET}
		fail_mail
elif [[ ${#pid_list_wl[@]} == 0 && ${#pid_list_ohs[@]} != 0 && ${#pid_list_otd[@]} == 0 ]]; then
        echo -e ${RED}"OHS Services are still UP on $HOST. Can't Proceeding with Patching Activity"
		echo -e "Please Bringdown the services completely and rerun the Apply script"${RESET}
		fail_mail
fi
}

apply_go_check()
{
skip_check
apply_check
}

skip_check()
{
if [[ ! -z $skip ]]; then
for skip_prd in $(echo $skip | tr "," "\n")
do
if [[ $skip_prd == JAVA ]]; then
	java_skip=Y
elif [[ $skip_prd == JDBC ]]; then
	jdbc_skip=Y
elif [[ $skip_prd == WLS ]]; then
	wls_skip=Y
	jdbc_skip=Y
elif [[ $skip_prd == OHS ]]; then
	ohs_skip=Y
fi
done
fi
}

apply_check()
{
if [[ ( -z $include ) || ( $include == ALL ) ]]; then
psu_apply
else
	if [[ -f $TECHPMPPROPFILE ]]; then
	source $TECHPMPPROPFILE
	for apply_prd in $(echo $include | tr "," "\n")
	do
	if [[ $apply_prd == JAVA ]]; then
		if [[ ${java_skip} == Y ]]; then
		echo -e ${RED}"We can't use Java option in both Skip and Apply"${RESET}
		fail_mail
		else
		java_patch
		clear_cache_tmp
		success_mail
		fi
	elif [[ $apply_prd == WLS ]]; then
		if [[ ${wls_skip} == Y ]]; then
		echo -e ${RED}"We can't use Weblogic option in both Skip and Apply"${RESET}
		fail_mail
		else
		wls_patch
		clear_cache_tmp
		success_mail
		fi
	elif [[ $apply_prd == OHS ]]; then
		if [[ ${ohs_skip} == Y ]]; then
		echo -e ${RED}"We can't use OHS option in both Skip and Apply"${RESET}
		fail_mail
		else
		ohs_patch
		success_mail
		fi	
	fi
	done
	else
		echo -e ${RED}"Please Do the Planning as well using ATOM job, so it will create required source file for success Execution"${RESET}
		fail_mail
	fi
fi
}


psu_apply()
{
if [[ -f $TECHPMPPROPFILE && ! -f $OTMPMPPROPFILE ]]; then
	source $TECHPMPPROPFILE
	java_patch
	wls_patch
	ohs_patch
	fmw_components_patch
	fmw_products_patch
	clear_cache_tmp
	success_mail
elif [[ -f $TECHPMPPROPFILE && -f $OTMPMPPROPFILE ]]; then
	source $OTMPMPPROPFILE
	glog_prop=$GLOG_HOME/glog/config/glog.properties
	glog_patch_prop=$GLOG_HOME/glog/config/glog.patches.properties
	default_node=`grep defaultMachineURL $glog_prop | grep -v grep | grep -vE '^#'| awk -F"=" '{print $2}' |  awk -F"//" '{print $2}' | awk -F":" '{print $1}'`
	install_type=`grep ^glog.software.installtype= $glog_prop | awk -F'=' '{ print $2 }'`
	default_node_val=`echo $default_node | egrep '.com' | wc -l`
	if [[ $default_node_val == 0 ]]; then
		echo -e ${RED}"Make sure defaultMachineURL value is set to right value in glog.properties file and rerun this Job"${RESET}
		fail_mail
	elif [[ ( ${default_node} == `hostname -f` ) || ( ${default_node} == `hostname` ) ]] && [[ ( ${install_type} == AppServer ) || ( ${install_type} == WebAppServer ) ]] && [[ ${run_patch_sql} == Y ]] && [[ ${operation_type} == manual ]]; then
		apply_post=Y
	elif [[ ( ${default_node} == `hostname -f` ) || ( ${default_node} == `hostname` ) ]] && [[ ( ${install_type} == AppServer ) || ( ${install_type} == WebAppServer ) ]] && [[ ${run_patch_sql} == Y ]] && [[ ${operation_type} == auto ]]; then
		echo -e ${YELLOW}"==========================================="
		echo "Note:"
		echo ""
		echo "Since we are having some post patch scripts to run after applying few patches,"
		echo "On default Application Server '$default_node', make sure we run the below script manually and when the script goes for Pause apply the post-patch steps and press enter."
		echo ""
		echo "Make sure we execute below, when the database is up"
		echo ""	
		echo "PMP_SCRIPT_TOP=$PMP_SCRIPT_TOP"
		echo "'$'PMP_SCRIPT_TOP/one_command_pmp_apply.sh ${release_month} manual"
		echo ""
		echo "On rest of the servers ATOM will apply all the patches and ATOM Job goes to Pause status,"
		echo "Resume the ATOM job once the patching on Default Application node '$default_node' completes."
		echo ""
		echo -e "==========================================="${RESET}
		exit 0;
	elif [[ ${default_node} != `hostname -f` || ${default_node} != `hostname` ]]; then
		apply_post=N
	fi
	files_backup
	otm_cpu_patch_apply
	otm_mandatory_apply
	otm_bug_apply
	source $TECHPMPPROPFILE
	java_patch
	wls_patch
	ohs_patch
	fmw_components_patch
	fmw_products_patch
	clear_cache_tmp
	success_mail
else
	echo -e ${RED}"Please Do the Planning as well using ATOM job, so it will create required source file for success Execution"${RESET}
	fail_mail
fi
}

clear_cache_tmp()
{
source $TECHPMPPROPFILE
if [[ ! -z $wls_servers ]] && [[ ! -z $domain_homes ]]; then
echo " "
echo -e ${CYAN}"****************************************************"
echo " Clearing Cache and tmp folders for Weblogic Domains on ${HOST}"
echo -e "****************************************************"${RESET}
echo " "
	for domain_home in $(echo $domain_homes | tr "," "\n")
		do
		if [[ -d $domain_home ]]; then
			for wls_server in $(echo $wls_servers | tr "," "\n")
				do
				if [[ -d $domain_home/servers/$wls_server ]]; then
					now=`date +"%Y%m%d%H%M"`
					cd $domain_home/servers/$wls_server
					mv cache cache_`date +"%Y%m%d%H%M"`
					mv tmp tmp_`date +"%Y%m%d%H%M"`
					if [[ ( ! -d cache ) && ( ! -d tmp ) ]]; then
						echo "$domain_home/servers/$wls_server : cache and tmp folder cleanup done"
					else
						echo "$domain_home/servers/$wls_server : cache and tmp folder cleanup Failed. Please do manually before starting up the services"
					fi
				else
					echo "$domain_home/servers/$wls_server Not Found, Please make sure we are trying to use right domain_home"
				fi
			done
		else
			echo "$domain_home Not Found, Please make sure we are trying to use right domain_home"
			fail_mail
		fi
	done 
fi
}

files_backup()
{
echo
patch_prop_file="glog.patches.properties"
patch_prop_file_bkp="glog.patches.properties_`date +"%Y%m%d%H%M"`"
cp "$GLOG_HOME/glog/config/${patch_prop_file}" "$GLOG_HOME/glog/config/${patch_prop_file_bkp}"
glog_prop_file="glog.properties"
glog_prop_file_bkp="glog.properties_`date +"%Y%m%d%H%M"`"
cp "$GLOG_HOME/glog/config/${glog_prop_file}" "$GLOG_HOME/glog/config/${glog_prop_file_bkp}"
#ls -ltr "$GLOG_HOME/glog/config/${glog_prop_file}" "$GLOG_HOME/glog/config/${glog_prop_file_bkp}"
if [ -f $GLOG_HOME/glog/config/${patch_prop_file_bkp} ] && [ -f $GLOG_HOME/glog/config/${glog_prop_file_bkp} ]; then
	echo "Files Backup Completed:"
	echo "${patch_prop_file_bkp}"
	echo "${glog_prop_file_bkp}"
else
	echo -e ${RED}"Files Backup Failed"${RESET}
	fail_mail
fi
}

otm_cpu_patch_apply()
{
st=$(date +"%s")
echo " "
echo -e ${CYAN}"****************************************************"
echo "Applying ${release_month} CPU Patches on ${HOST}"
echo -e "****************************************************"${RESET}
echo " "
echo OTM Version = ${OTM_VERSION}
echo " "
install_type=`grep ^glog.software.installtype= $GLOG_HOME/glog/config/glog.properties | awk -F'=' '{ print $2 }'`
if [[ ! -z ${cpu_patch_id} ]] || [[ ${cpu_patch_id} != None ]]; then
IN="${cpu_patch_id}"
for SET in $(echo $IN | tr "," "\n")
do
psu_patch_id=`echo $SET|cut -d'!' -f 1`
post_patch=`echo $SET|cut -d'!' -f 2`
CPU_PATCH=`grep -i ${psu_patch_id} $glog_patch_prop| wc -l`
if [[ $CPU_PATCH == 1 ]]; then
echo -e "${psu_patch_id} ==> ${GREEN} Already Applied. Skipping ${RESET} "
else
if [[ ${post_patch} == YI ]]; then
mkdir -p $LOG_DIR
cd $CPU_PATCH_TOP/${psu_patch_id}
java -jar *${psu_patch_id}*.jar -d "$GLOG_HOME" > $LOG_DIR/${psu_patch_id}_apply_`date +"%Y%m%d"`_${HOST}.log
D=`grep "${psu_patch_id}" "$GLOG_HOME/glog/config/${patch_prop_file}" |wc -l`
	if [ $D == "1" ]; then
		echo -e "${psu_patch_id} ==> ${GREEN} Applied successfully! ${RESET}"
		if [ -d $GLOG_HOME/glog/gc3webapp/WEB-INF/lib/3rdparty/bpel ]; then
			rm -rf $GLOG_HOME/glog/gc3webapp/WEB-INF/lib/3rdparty/bpel > /dev/null
			echo "Removed directory $GLOG_HOME/glog/gc3webapp/WEB-INF/lib/3rdparty/bpel as part of post Patch Steps on ${HOST}"
		fi
		if [ -d $GLOG_HOME/glog/gc3webapp/WEB-INF/lib/3rdparty/bpel_10.1.3 ]; then
			rm -rf $GLOG_HOME/glog/gc3webapp/WEB-INF/lib/3rdparty/bpel_10.1.3 > /dev/null
			echo "Removed directory $GLOG_HOME/glog/gc3webapp/WEB-INF/lib/3rdparty/bpel_10.1.3 as part of post Patch Steps on ${HOST}"
		fi
		if [[ $apply_post == Y ]]; then
			echo "POST PATCHING INSTRUCTIONS FOR ${psu_patch_id}:"
			echo "cd $GLOG_HOME/glog/oracle/script8"
			echo "sqlplus /nolog @run_patch.sql"
			echo "Make sure you have followed above post patch instructions manually [only on single MT] before proceeding further.Once done, Press enter to continue"
			read var
			if [[ ${var} == "" ]]; then
				sleep 2
			else
				echo -e ${RED}"Your entry is not Enter, So assuming you don't want to continue further"
				echo -e "Run Special Instructions manually and Start the script again. Quitting...."${RESET}
				fail_exit
			fi
		fi
	else
		echo -e "${psu_patch_id} ==> ${RED} Installation Failed ${RESET}. Please review the log file $LOG_DIR/${psu_patch_id}_apply_`date +"%Y%m%d"`_${HOST}.log!!! "
		fail_exit
	fi
elif [[ ${post_patch} == YJ ]]; then
	mkdir -p $LOG_DIR
	cd $CPU_PATCH_TOP/${psu_patch_id}
	java -jar *${psu_patch_id}*.jar -d "$GLOG_HOME" > $LOG_DIR/${psu_patch_id}_apply_`date +"%Y%m%d"`_${HOST}.log
	D=`grep "${psu_patch_id}" "$GLOG_HOME/glog/config/${patch_prop_file}" |wc -l`
	if [ $D == "1" ]; then
		echo -e "${psu_patch_id} ==> ${GREEN} Applied successfully! ${RESET}"
		if [ -d $GLOG_HOME/glog/gc3webapp.ear/GC3.war/WEB-INF/lib/3rdparty/bpel ]; then
			rm -rf $GLOG_HOME/glog/gc3webapp.ear/GC3.war/WEB-INF/lib/3rdparty/bpel > /dev/null
			echo "Removed directory $GLOG_HOME/glog/gc3webapp.ear/GC3.war/WEB-INF/lib/3rdparty/bpel as part of post Patch Steps on ${HOST}"
		fi
		if [ -d $GLOG_HOME/glog/gc3webapp.ear/GC3.war/WEB-INF/lib/3rdparty/bpel_10.1.3 ]; then
			rm -rf $GLOG_HOME/glog/gc3webapp.ear/GC3.war/WEB-INF/lib/3rdparty/bpel_10.1.3 > /dev/null
			echo "Removed directory $GLOG_HOME/glog/gc3webapp.ear/GC3.war/WEB-INF/lib/3rdparty/bpel_10.1.3 as part of post Patch Steps on ${HOST}"
		fi
		if [[ $apply_post == Y ]]; then
			echo "POST PATCHING INSTRUCTIONS FOR ${psu_patch_id}:"
			echo "cd $GLOG_HOME/glog/oracle/script8"
			echo "sqlplus /nolog @run_patch.sql"
			echo "Make sure you have followed above post patch instructions manually [only on single MT] before proceeding further.Once done, Press enter to continue"
			read var
			if [[ ${var} == "" ]]; then
				sleep 2
			else
				echo -e ${RED}"Your entry is not Enter, So assuming you don't want to continue further"
				echo -e "Run Special Instructions manually and Start the script again. Quitting...."${RESET}
				fail_exit
			fi
		fi
	else
		echo -e "${psu_patch_id} ==> ${RED} Installation Failed ${RESET}. Please review the log file $LOG_DIR/${psu_patch_id}_apply_`date +"%Y%m%d"`_${HOST}.log!!! "
		fail_exit
	fi
elif [[ ${post_patch} == YB ]] && [[ $install_type == WebServer ]]; then
	mkdir -p $LOG_DIR
	cd $CPU_PATCH_TOP/${psu_patch_id}
	java -jar *${psu_patch_id}*.jar -d "$GLOG_HOME" > $LOG_DIR/${psu_patch_id}_apply_`date +"%Y%m%d"`_${HOST}.log
	D=`grep "${psu_patch_id}" "$GLOG_HOME/glog/config/${patch_prop_file}" |wc -l`
	if [ $D == "1" ]; then
		echo -e "${psu_patch_id} ==> ${GREEN} Applied successfully! ${RESET}"
		cd $GLOG_HOME/tomcat/lib
		if [ -f ecj-3.7.jar ] && [ -f ecj-4.2.2.jar ]; then
			rm ecj-3.7.jar ecj-4.2.2.jar > /dev/null
			echo "Post Patch Steps completed on ${HOST}"
			echo "Removed files ecj-3.7.jar & ecj-4.2.2.jar from $GLOG_HOME/tomcat/lib/"
		fi
	else
		echo -e "${psu_patch_id} ==> ${RED} Installation Failed ${RESET}. Please review the log file $LOG_DIR/${psu_patch_id}_apply_`date +"%Y%m%d"`_${HOST}.log!!! "
		fail_exit
	fi
elif [[ ${post_patch} == YC ]] && [[ $install_type == WebServer ]]; then
	mkdir -p $LOG_DIR
	cd $CPU_PATCH_TOP/${psu_patch_id}
	java -jar *${psu_patch_id}*.jar -d "$GLOG_HOME" > $LOG_DIR/${psu_patch_id}_apply_`date +"%Y%m%d"`_${HOST}.log
	D=`grep "${psu_patch_id}" "$GLOG_HOME/glog/config/${patch_prop_file}" |wc -l`
	if [ $D == "1" ]; then
		echo -e "${psu_patch_id} ==> ${GREEN} Applied successfully! ${RESET}"
		cd $GLOG_HOME/tomcat/lib
		if [ -f ecj-4.4.jar ]; then
			rm ecj-4.4.jar > /dev/null
			echo "Post Patch Steps completed on ${HOST}"
			echo "Removed file $GLOG_HOME/tomcat/lib/ecj-4.4.jar"
		fi
	else	
		echo -e "${psu_patch_id} ==> ${RED} Installation Failed ${RESET}. Please review the log file $LOG_DIR/${psu_patch_id}_apply_`date +"%Y%m%d"`_${HOST}.log!!! "
		fail_exit
	fi
elif [[ ${post_patch} == YD ]] && [[ $install_type == WebServer ]] && [[ $current_otm_version == OTMv6.4.1 ]]; then
	mkdir -p $LOG_DIR
	cd $CPU_PATCH_TOP/${psu_patch_id}
	java -jar *${psu_patch_id}*.jar -d "$GLOG_HOME" > $LOG_DIR/${psu_patch_id}_apply_`date +"%Y%m%d"`_${HOST}.log
	D=`grep "${psu_patch_id}" "$GLOG_HOME/glog/config/${patch_prop_file}" |wc -l`
	if [ $D == "1" ]; then
		echo -e "${psu_patch_id} ==> ${GREEN} Applied successfully! ${RESET}"
		echo "Post Patch Steps for ${psu_patch_id}:"
		echo "Edit the $GLOG_HOME/webserver/weblogic.conf file and add the following line before any other "classpath=" lines:"
		echo "classpath=%GLOG_HOME%/glog/gc3webapp.ear/GC3.war/WEB-INF/lib/3rdparty/commons-fileupload-1.3.3.jar"
		echo " "
		echo "Please peform above post patch steps before we startup the services"
		sleep 5
	else
		echo -e "${psu_patch_id} ==> ${RED} Installation Failed ${RESET}. Please review the log file $LOG_DIR/${psu_patch_id}_apply_`date +"%Y%m%d"`_${HOST}.log!!! "
		fail_exit
	fi
elif [[ ${post_patch} == YE ]] && [[ $install_type == WebServer ]] && [[ $current_otm_version == OTMv6.4.2 ]]; then
	mkdir -p $LOG_DIR
	cd $CPU_PATCH_TOP/${psu_patch_id}
	java -jar *${psu_patch_id}*.jar -d "$GLOG_HOME" > $LOG_DIR/${psu_patch_id}_apply_`date +"%Y%m%d"`_${HOST}.log
	D=`grep "${psu_patch_id}" "$GLOG_HOME/glog/config/${patch_prop_file}" |wc -l`
	if [ $D == "1" ]; then
		echo -e "${psu_patch_id} ==> ${GREEN} Applied successfully! ${RESET}"
		echo "Post Patch Steps for ${psu_patch_id}:"
		echo "Edit the $GLOG_HOME/webserver/weblogic.conf file and add the following line before any other "classpath=" lines:"
		echo "classpath=%GLOG_HOME%/glog/gc3webapp.ear/APP-INF/lib/3rdparty/commons-fileupload-1.3.3.jar"
		echo " "
		echo "Please peform above post patch steps before we startup the services"
		sleep 5
	else
		echo -e "${psu_patch_id} ==> ${RED} Installation Failed ${RESET}. Please review the log file $LOG_DIR/${psu_patch_id}_apply_`date +"%Y%m%d"`_${HOST}.log!!! "
		fail_exit
	fi
elif [[ ${post_patch} == YF ]]; then
	mkdir -p $LOG_DIR
	cd $CPU_PATCH_TOP/${psu_patch_id}
	java -jar *${psu_patch_id}*.jar -d "$GLOG_HOME" > $LOG_DIR/${psu_patch_id}_apply_`date +"%Y%m%d"`_${HOST}.log
	D=`grep "${psu_patch_id}" "$GLOG_HOME/glog/config/${patch_prop_file}" |wc -l`
	if [ $D == "1" ]; then
		echo -e "${psu_patch_id} ==> ${GREEN} Applied successfully! ${RESET}"
		if [ -f $GLOG_HOME/glog/gc3webapp.ear/GC3.war/WEB-INF/lib/3rdparty/ridc/log4j-1.2.17.jar ]; then
			rm $GLOG_HOME/glog/gc3webapp.ear/GC3.war/WEB-INF/lib/3rdparty/ridc/log4j-1.2.17.jar > /dev/null
			echo "Post Patch Steps completed on ${HOST}"
			echo "Removed file $GLOG_HOME/glog/gc3webapp.ear/GC3.war/WEB-INF/lib/3rdparty/ridc/log4j-1.2.17.jar"
		fi
	else
		echo -e "${psu_patch_id} ==> ${RED} Installation Failed ${RESET}. Please review the log file $LOG_DIR/${psu_patch_id}_apply_`date +"%Y%m%d"`_${HOST}.log!!! "
		fail_exit
	fi
elif [[ ${post_patch} == YG ]]; then
	mkdir -p $LOG_DIR
	cd $CPU_PATCH_TOP/${psu_patch_id}
	java -jar *${psu_patch_id}*.jar -d "$GLOG_HOME" > $LOG_DIR/${psu_patch_id}_apply_`date +"%Y%m%d"`_${HOST}.log
	D=`grep "${psu_patch_id}" "$GLOG_HOME/glog/config/${patch_prop_file}" |wc -l`
	if [ $D == "1" ]; then
		echo -e "${psu_patch_id} ==> ${GREEN} Applied successfully! ${RESET}"
		if [ -f $GLOG_HOME/glog/gc3webapp/WEB-INF/lib/3rdparty/ridc/log4j-1.2.17.jar ]; then
			rm $GLOG_HOME/glog/gc3webapp/WEB-INF/lib/3rdparty/ridc/log4j-1.2.17.jar
			if [ $? == 0 ]; then
				echo "Post Patch Steps completed on ${HOST}"
				echo "Removed file $GLOG_HOME/glog/gc3webapp/WEB-INF/lib/3rdparty/ridc/log4j-1.2.17.jar"
			else
				echo "Post Patch Steps Failed on ${HOST}"
				echo "Remove the file $GLOG_HOME/glog/gc3webapp/WEB-INF/lib/3rdparty/ridc/log4j-1.2.17.jar manully"
			fi
		fi
	else
		echo -e "${psu_patch_id} ==> ${RED} Installation Failed ${RESET}. Please review the log file $LOG_DIR/${psu_patch_id}_apply_`date +"%Y%m%d"`_${HOST}.log!!! "
		fail_exit
	fi
elif [[ ${post_patch} == YA ]]; then
	mkdir -p $LOG_DIR
	cd $CPU_PATCH_TOP/${psu_patch_id}
	java -jar *${psu_patch_id}*.jar -d "$GLOG_HOME" > $LOG_DIR/${psu_patch_id}_apply_`date +"%Y%m%d"`_${HOST}.log
	D=`grep "${psu_patch_id}" "$GLOG_HOME/glog/config/${patch_prop_file}" |wc -l`
	if [ $D == "1" ]; then
		echo -e "${psu_patch_id} ==> ${GREEN} Applied successfully! ${RESET}"
		if [ -f $GLOG_HOME/glog/gc3webapp/WEB-INF/lib/3rdparty/struts.jar ]; then
			rm $GLOG_HOME/glog/gc3webapp/WEB-INF/lib/3rdparty/struts.jar
			if [ $? == 0 ]; then
				echo "Post Patch Steps completed on ${HOST}"
				echo "Removed file $GLOG_HOME/glog/gc3webapp/WEB-INF/lib/3rdparty/struts.jar"
			else
				echo "Post Patch Steps Failed on ${HOST}"
				echo "Remove the file $GLOG_HOME/glog/gc3webapp/WEB-INF/lib/3rdparty/struts.jar manully"
			fi
		fi
	else
		echo -e "${psu_patch_id} ==> ${RED} Installation Failed ${RESET}. Please review the log file $LOG_DIR/${psu_patch_id}_apply_`date +"%Y%m%d"`_${HOST}.log!!! "
		fail_exit
	fi
elif [[ ${post_patch} == YH ]]; then
	mkdir -p $LOG_DIR
	cd $CPU_PATCH_TOP/${psu_patch_id}
	java -jar *${psu_patch_id}*.jar -d "$GLOG_HOME" > $LOG_DIR/${psu_patch_id}_apply_`date +"%Y%m%d"`_${HOST}.log
	D=`grep "${psu_patch_id}" "$GLOG_HOME/glog/config/${patch_prop_file}" |wc -l`
	if [ $D == "1" ]; then
		echo -e "${psu_patch_id} ==> ${GREEN} Applied successfully! ${RESET}"
		if [ -f $GLOG_HOME/glog/gc3webapp.ear/GC3.war/WEB-INF/lib/3rdparty/ridc/log4j-1.2.17.jar ]; then
			rm $GLOG_HOME/glog/gc3webapp.ear/GC3.war/WEB-INF/lib/3rdparty/ridc/log4j-1.2.17.jar > /dev/null
			echo "Post Patch Steps completed on ${HOST}"
			echo "Removed file $GLOG_HOME/glog/gc3webapp.ear/GC3.war/WEB-INF/lib/3rdparty/ridc/log4j-1.2.17.jar"
		fi
	else
		echo -e "${psu_patch_id} ==> ${RED} Installation Failed ${RESET}. Please review the log file $LOG_DIR/${psu_patch_id}_apply_`date +"%Y%m%d"`_${HOST}.log!!! "
		fail_exit
	fi
elif [[ ${post_patch} == Y ]] && [[ ${apply_post} == Y ]]; then
	mkdir -p $LOG_DIR
	cd $CPU_PATCH_TOP/${psu_patch_id}
	java -jar *${psu_patch_id}*.jar -d "$GLOG_HOME" > $LOG_DIR/${psu_patch_id}_apply_`date +"%Y%m%d"`_${HOST}.log
	D=`grep "${psu_patch_id}" "$GLOG_HOME/glog/config/${patch_prop_file}" |wc -l`
	if [ $D == "1" ]; then
		echo -e "${psu_patch_id} ==> ${GREEN} Applied successfully! ${RESET}"
		echo "POST PATCHING INSTRUCTIONS FOR ${psu_patch_id}:"
		echo "cd $GLOG_HOME/glog/oracle/script8"
		echo "sqlplus /nolog @run_patch.sql"
		echo "Make sure you have followed above post patch instructions manually [only on single MT] before proceeding further.Once done, Press enter to continue"
		read var
		if [[ ${var} == "" ]]; then
			sleep 2
		else
			echo "Your entry is not Enter, So assuming you don't want to continue further"
			echo "Run Special Instructions manually and Start the script again. Quitting...."
			fail_exit
		fi
	else
		echo -e "${psu_patch_id} ==> ${RED} Installation Failed ${RESET}. Please review the log file $LOG_DIR/${psu_patch_id}_apply_`date +"%Y%m%d"`_${HOST}.log!!! "
		fail_exit
	fi
else
	mkdir -p $LOG_DIR
	cd $CPU_PATCH_TOP/${psu_patch_id}
	java -jar *${psu_patch_id}*.jar -d "$GLOG_HOME" > $LOG_DIR/${psu_patch_id}_apply_`date +"%Y%m%d"`_${HOST}.log
	D=`grep "${psu_patch_id}" "$GLOG_HOME/glog/config/${patch_prop_file}" |wc -l`
	if [ $D == "1" ]; then
		echo -e "${psu_patch_id} ==> ${GREEN} Applied successfully! ${RESET}"
	else
		echo -e "${psu_patch_id} ==> ${RED} Installation Failed ${RESET}. Please review the log file $LOG_DIR/${psu_patch_id}_apply_`date +"%Y%m%d"`_${HOST}.log!!! "
		fail_exit
	fi
fi
fi
done
fi
et=$(date +"%s")
diff=$(($et-$st))
echo " "
echo -e ${PUR}"Total Time Taken for Applying OTM CPU Patches : $(($diff / 60)) minutes and $(($diff % 60)) seconds elapsed."${RESET}
}

otm_mandatory_apply()
{
st=$(date +"%s")
echo " "
echo -e ${CYAN}"****************************************************"
echo "Applying Recommended Patches on ${HOST}"
echo -e "****************************************************"${RESET}
echo " "
echo OTM Version = ${OTM_VERSION}
echo " "
if [[ -z $mand_patch_id ]] || [[ $mand_patch_id == None ]]; then
echo "| No Recommended Patches for this version"
else
IN="${mand_patch_id}"
for SET in $(echo $IN | tr "," "\n")
do
psu_patch_id=`echo $SET|cut -d'!' -f 1`
post_patch=`echo $SET|cut -d'!' -f 2`
CPU_PATCH=`grep -i ${psu_patch_id} $glog_patch_prop| wc -l`
if [[ $CPU_PATCH == 1 ]]; then
	echo -e "${psu_patch_id} ==> ${GREEN} Already Applied. Skipping ${RESET} "
else
	if [[ ${post_patch} == Y ]] && [[ $apply_post == Y ]]; then
		mkdir -p $LOG_DIR
		cd $CPU_PATCH_TOP/${psu_patch_id}
		java -jar *${psu_patch_id}*.jar -d "$GLOG_HOME" > $LOG_DIR/${psu_patch_id}_apply_`date +"%Y%m%d"`_${HOST}.log
		D=`grep "${psu_patch_id}" "$GLOG_HOME/glog/config/${patch_prop_file}" |wc -l`
		if [ $D == "1" ]; then
			echo -e "${psu_patch_id} ==> ${GREEN} Applied successfully! ${RESET}"
			echo "POST PATCHING INSTRUCTIONS FOR ${psu_patch_id}:"
			echo "cd $GLOG_HOME/glog/oracle/script8"
			echo "sqlplus /nolog @run_patch.sql"
			echo "Make sure you have followed above post patch instructions manually [only on single MT] before proceeding further... Once done Press enter to continue..."
			read var
			if [[ ${var} == ""  ]]; then
				sleep 2
			else
				echo "Your input is not "Enter", So assuming you don't want to continue further"
				echo "Run Special Instructions manually and Start the script again. Quitting...."
				fail_exit
			fi
		else
			echo -e "${psu_patch_id} ==> ${RED} Installation Failed ${RESET}. Please review the log file $LOG_DIR/${psu_patch_id}_apply_`date +"%Y%m%d"`_${HOST}.log!!! "
			fail_exit
		fi
	elif [[ ${post_patch} == YA ]] && [[ $apply_post == Y ]]; then
		mkdir -p $LOG_DIR
		cd $CPU_PATCH_TOP/${psu_patch_id}
		java -jar *${psu_patch_id}*.jar -d "$GLOG_HOME" > $LOG_DIR/${psu_patch_id}_apply_`date +"%Y%m%d"`_${HOST}.log
		D=`grep "${psu_patch_id}" "$GLOG_HOME/glog/config/${patch_prop_file}" |wc -l`
		if [ $D == "1" ]; then
			echo -e "${psu_patch_id} ==> ${GREEN} Applied successfully! ${RESET}"
			echo "POST PATCHING INSTRUCTIONS FOR ${psu_patch_id}:"
			echo "cd $GLOG_HOME/glog/oracle/script8"
			echo "./run_patch.sh"
			echo "Make sure you have followed above post patch instructions manually [only on single MT] before proceeding further.Once done, Press enter to continue"
			read var
			if [[ ${var} == "" ]]; then
				sleep 2
			else
				echo "Your Input is not "Enter", So assuming you don't want to continue further"
				echo "Run Special Instructions manually and Start the script again. Quitting...."
				fail_exit
			fi
		else
			echo -e "${psu_patch_id} ==> ${RED} Installation Failed ${RESET}. Please review the log file $LOG_DIR/${psu_patch_id}_apply_`date +"%Y%m%d"`_${HOST}.log!!! "
			fail_exit
		fi
	else
		mkdir -p $LOG_DIR
		cd $CPU_PATCH_TOP/${psu_patch_id}
		java -jar *${psu_patch_id}*.jar -d "$GLOG_HOME" > $LOG_DIR/${psu_patch_id}_apply_`date +"%Y%m%d"`_${HOST}.log
		D=`grep "${psu_patch_id}" "$GLOG_HOME/glog/config/${patch_prop_file}" |wc -l`
		if [ $D == "1" ]; then
			echo -e "${psu_patch_id} ==> ${GREEN} Applied successfully! ${RESET}"
		else
			echo -e "${psu_patch_id} ==> ${RED}Installation Failed.${RESET} Please review the log file $LOG_DIR/${psu_patch_id}_apply_`date +"%Y%m%d"`_${HOST}.log!!! "
			fail_exit
		fi
	fi
fi
done
fi
et=$(date +"%s")
diff=$(($et-$st))
echo " "
echo -e ${YELLOW}"Total Time Taken for Applying OTM Recommended Patches : $(($diff / 60)) minutes and $(($diff % 60)) seconds elapsed."${RESET}
}

otm_bug_apply()
{
st=$(date +"%s")
echo " "
echo -e ${CYAN}"****************************************************"
echo "Applying CPU Post BUG Patches on ${HOST}"
echo -e "****************************************************"${RESET}
echo " "
echo OTM Version = ${OTM_VERSION}
echo " "
if [[ -z $bug_patch_id ]] || [[ $bug_patch_id == None ]]; then
	echo "No Bugs Reported so far for this version after CPU Patching. If Yes Apply Manually before releasing the Instance."
else
	IN="${bug_patch_id}"
	for SET in $(echo $IN | tr "," "\n")
	do
	psu_patch_id=`echo $SET|cut -d'!' -f 1`
	post_patch=`echo $SET|cut -d'!' -f 2`
	CPU_PATCH=`grep -i ${psu_patch_id} $glog_patch_prop| wc -l`
	if [[ $CPU_PATCH == 1 ]]; then
		echo -e "${psu_patch_id} ==> ${GREEN} Already Applied. Skipping ${RESET} "
	else
	if [[ ${post_patch} == Y ]] && [[ $apply_post == Y ]]; then
		mkdir -p $LOG_DIR
		cd $CPU_PATCH_TOP/${psu_patch_id}
		java -jar *${psu_patch_id}*.jar -d "$GLOG_HOME" > $LOG_DIR/${psu_patch_id}_apply_`date +"%Y%m%d"`_${HOST}.log
		D=`grep "${psu_patch_id}" "$GLOG_HOME/glog/config/${patch_prop_file}" |wc -l`
		if [ $D == "1" ]; then
			echo "${psu_patch_id} ==> ${GREEN} Applied successfully! ${RESET}"
			echo "POST PATCHING INSTRUCTIONS FOR ${psu_patch_id}:"
			echo "cd $GLOG_HOME/glog/oracle/script8"
			echo "sqlplus /nolog @run_patch.sql"
			echo "Make sure you have followed above post patch instructions manually [only on single MT] before proceeding further... Once Done.Press enter to continue..."
			read var
			if [[ ${var} == ""  ]]; then
				sleep 2
			else
				echo "Your input is not "Enter", So assuming you don't want to continue further"
				echo "Run Special Instructions manually and Start the script again. Quitting...."
				fail_exit
			fi
		else
			echo -e "${psu_patch_id} ==> ${RED} Installation Failed ${RESET}. Please review the log file $LOG_DIR/${psu_patch_id}_apply_`date +"%Y%m%d"`_${HOST}.log!!! "
			fail_exit
		fi
	else
		mkdir -p $LOG_DIR
		cd $CPU_PATCH_TOP/${psu_patch_id}
		java -jar *${psu_patch_id}*.jar -d "$GLOG_HOME" > $LOG_DIR/${psu_patch_id}_apply_`date +"%Y%m%d"`_${HOST}.log
		D=`grep "${psu_patch_id}" "$GLOG_HOME/glog/config/${patch_prop_file}" |wc -l`
		if [ $D == "1" ]; then
			echo -e "${psu_patch_id} ==> ${GREEN} Applied successfully! ${RESET}"
		else
			echo -e "${psu_patch_id} ==> ${RED} Installation Failed ${RESET}. Please review the log file $LOG_DIR/${psu_patch_id}_apply_`date +"%Y%m%d"`_${HOST}.log!!! "
			fail_exit
		fi
	fi
fi
done
fi
et=$(date +"%s")
diff=$(($et-$st))
echo " "
echo -e ${YELLOW}"Total Time Taken for Applying OTM Bug Fix Patches : $(($diff / 60)) minutes and $(($diff % 60)) seconds elapsed."${RESET}
}

######################################################
# To Apply Patches for default FMW Components
######################################################
fmw_components_patch()
{
source $TECHPMPPROPFILE
if [[ ! -z ${fmw_components} ]] && [[ ${fmw_components} != None ]]; then
echo -e ${CYAN}"******************************************************************"
echo -e " Applying Patches for default FMW techstack Components"
echo -e "******************************************************************"${RESET}
for fmw_component in $(echo ${fmw_components} | tr "," "\n")
do
fmw_component_versions=`cat $TECHPMPPROPFILE | grep ${fmw_component}_version | awk -F"=" '{print$2}'`
for fmw_component_version in $fmw_component_versions
do
product=$fmw_component
product_version=`echo $fmw_component_version`
product_short_ver=`echo ${product_version//[-._]/}`
ORACLE_HOME=`cat $TECHPMPPROPFILE | grep ${product}_${product_short_ver}_home | awk -F"=" '{print$2}'`
psu_patch_id=`cat $TECHPMPPROPFILE | grep ${product}_${product_short_ver}_psu_patch_id | awk -F"=" '{print$2}'`
prereq_patch_ids=`cat $TECHPMPPROPFILE | grep ${product}_${product_short_ver}_prereq_patch_id | awk -F"=" '{print$2}'`
mand_patches=`cat $TECHPMPPROPFILE | grep ${product}_${product_short_ver}_mand_patch_id | awk -F"=" '{print$2}'`
conflict_ids=`cat $TECHPMPPROPFILE | grep ${product}_${product_short_ver}_conflict_id | awk -F"=" '{print$2}'`
psu_patch_release=`cat $TECHPMPPROPFILE | grep ${product}_${product_short_ver}_psu_patch_release | awk -F"=" '{print$2}'`
latest_release=`cat $TECHPMPPROPFILE | grep ${product}_${product_short_ver}_latest_release | awk -F"=" '{print$2}'`
opatch_list pre
echo "current ${product} version=${product_version}"
echo "ORACLE_HOME Requested to Patch : $ORACLE_HOME"
export PATH=$ORACLE_HOME/OPatch:$PATH
psu_patch_apply
echo " "
done
done
fi
if [[ ! -z ${fmw_components} ]] && [[ ${fmw_components} != None ]]; then
opatch_list post
fi
}

######################################################
# To Apply Patches for default FMW Products
######################################################
fmw_products_patch()
{
source $TECHPMPPROPFILE
if [[ ! -z ${fmw_products} ]] && [[ ${fmw_products} != None ]]; then
echo -e ${CYAN}"******************************************************************************"
echo -e " Applying Patches for default FMW Products installed on ${HOST}"
echo -e "******************************************************************************"${RESET}
for fmw_product in $(echo ${fmw_products} | tr "," "\n")
do
fmw_product_versions=`cat $TECHPMPPROPFILE | grep ${fmw_product}_version | awk -F"=" '{print$2}'`
for fmw_product_version in $fmw_product_versions
do
product=$fmw_product
product_version=`echo $fmw_product_version`
product_short_ver=`echo ${product_version//[-._]/}`
ORACLE_HOME=`cat $TECHPMPPROPFILE | grep ${product}_${product_short_ver}_home | awk -F"=" '{print$2}'`
psu_patch_id=`cat $TECHPMPPROPFILE | grep ${product}_${product_short_ver}_psu_patch_id | awk -F"=" '{print$2}'`
prereq_patch_ids=`cat $TECHPMPPROPFILE | grep ${product}_${product_short_ver}_prereq_patch_id | awk -F"=" '{print$2}'`
mand_patches=`cat $TECHPMPPROPFILE | grep ${product}_${product_short_ver}_mand_patch_id | awk -F"=" '{print$2}'`
conflict_ids=`cat $TECHPMPPROPFILE | grep ${product}_${product_short_ver}_conflict_id | awk -F"=" '{print$2}'`
psu_patch_release=`cat $TECHPMPPROPFILE | grep ${product}_${product_short_ver}_psu_patch_release | awk -F"=" '{print$2}'`
latest_release=`cat $TECHPMPPROPFILE | grep ${product}_${product_short_ver}_latest_release | awk -F"=" '{print$2}'`
opatch_list pre
export patch_oracle_common=''
if [[ $fmw_product == SOA || $fmw_product == WC_Portal ]] && [[ $product_version == 11.1.1.* ]]; then
patch_oracle_common=Y
fi
echo "current ${product} version=${product_version}"
echo "ORACLE_HOME Requested to Patch : $ORACLE_HOME"
export PATH=$ORACLE_HOME/OPatch:$PATH
psu_patch_apply
opatch_list post
echo " "
done
done
fi
if [[ ! -z ${fmw_products} ]] && [[ ${fmw_products} != None ]]; then
opatch_list_12c_final
fi
}

#####################################
# OPATCH LIST BEFORE
#####################################
opatch_list()
{
stage=$1
if [[ ( ! -z $weblogic_version ) || ( ! -z $ohs_version ) ]] && [[ ( $weblogic_version == 12.* ) || ( $ohs_version == 12.* ) ]];then
if [[ ! -f $LOG_DIR/opatch_12c_${stage}_execution.lst ]] && [[ $stage == pre ]]; then
echo " "
echo "************************************************************************************************"
echo -e "${CYAN} ${BOLD}List of Patches Installed for ${YELLOW} [${ORACLE_HOME}] on ${HOST}:" ${RESET}
echo "************************************************************************************************"
#$ORACLE_HOME/OPatch/opatch lspatches > $LOG_DIR/opatch_12c_pre_execution.lst
$PMP_SCRIPT_TOP/bin/opatch_format.sh $ORACLE_HOME > $LOG_DIR/opatch_12c_${stage}_execution.lst
echo " "
cat $LOG_DIR/opatch_12c_${stage}_execution.lst
#$PMP_SCRIPT_TOP/bin/opatch_format.sh $ORACLE_HOME
fi
else
opatch_list_11g
fi
}

opatch_list_12c_final()
{
if [[ ( ! -z $weblogic_version ) || ( ! -z $ohs_version ) ]] && [[ ( $weblogic_version == 12.* ) || ( $ohs_version == 12.* ) ]] &&  [[ ! -f $LOG_DIR/opatch_12c_post_execution.lst ]];then
echo " "
# echo "************************************************************************************************"
echo -e "${CYAN} ${BOLD}List of Patches Installed for ${YELLOW} [${ORACLE_HOME}] on ${HOST}:" ${RESET}
echo "************************************************************************************************"
#$ORACLE_HOME/OPatch/opatch lspatches > $LOG_DIR/opatch_12c_pre_execution.lst
$PMP_SCRIPT_TOP/bin/opatch_format.sh $ORACLE_HOME > $LOG_DIR/opatch_12c_post_execution.lst
echo " "
cat $LOG_DIR/opatch_12c_post_execution.lst
#$PMP_SCRIPT_TOP/bin/opatch_format.sh $ORACLE_HOME
fi
}

opatch_list_11g()
{
if [[ `basename $ORACLE_HOME` == oracle_common ]]; then
local product=oracle_common
fi
if [[ ! -f $LOG_DIR/opatch_${product}_${stage}_execution.lst ]]; then
echo "************************************************************************************************"
echo -e "${CYAN} ${BOLD}List of Patches Installed for ${YELLOW} [${ORACLE_HOME}] on ${HOST}:" ${RESET}
echo "************************************************************************************************"
$ORACLE_HOME/OPatch/opatch lsinventory -invPtrLoc $ORACLE_HOME/oraInst.loc > $LOG_DIR/opatch_${product}_${stage}_execution.lst
echo " "
cat $LOG_DIR/opatch_${product}_${stage}_execution.lst
echo ""
#echo "*************************************************************************"
fi
}

#****************************************
# For Applying Weblogic PSU Patches
#****************************************
wls_patch()
{
if [[ $wls_skip -ne Y ]] || [[ -z $wls_skip ]]; then
source $TECHPMPPROPFILE
weblogic_go=`cat $TECHPMPPROPFILE | grep 'weblogic_version'| wc -l`
if [[ ${weblogic_go} -ge 1 ]]; then
st=$(date +"%s")
weblogic_versions=`cat $TECHPMPPROPFILE | grep 'weblogic_version' | awk -F"=" '{print$2}'`
for weblogic_version in $weblogic_versions
do
product=weblogic
product_version=`echo $weblogic_version`
product_short_ver=`echo ${product_version//[-._]/}`
wl_home=`cat $TECHPMPPROPFILE | grep ${product}_${product_short_ver}_wl_home | awk -F"=" '{print$2}'`
ORACLE_HOME=`cat $TECHPMPPROPFILE | grep ${product}_${product_short_ver}_home | awk -F"=" '{print$2}'`
psu_patch_id=`cat $TECHPMPPROPFILE | grep ${product}_${product_short_ver}_psu_patch_id | awk -F"=" '{print$2}'`
prereq_patch_ids=`cat $TECHPMPPROPFILE | grep ${product}_${product_short_ver}_prereq_patch_id | awk -F"=" '{print$2}'`
mand_patches=`cat $TECHPMPPROPFILE | grep ${product}_${product_short_ver}_mand_patch_id | awk -F"=" '{print$2}'`
conflict_ids=`cat $TECHPMPPROPFILE | grep ${product}_${product_short_ver}_conflict_id | awk -F"=" '{print$2}'`
psu_patch_release=`cat $TECHPMPPROPFILE | grep ${product}_${product_short_ver}_psu_patch_release | awk -F"=" '{print$2}'`
latest_release=`cat $TECHPMPPROPFILE | grep ${product}_${product_short_ver}_latest_release | awk -F"=" '{print$2}'`
weblogic_cpu_patch_apply
wls_jdbc_driver_apply
done
fi
fi
}

weblogic_cpu_patch_apply()
{
if [[ ( ! -z $wl_home ) && ( ! -d $wl_home ) ]]; then
	echo -e ${RED}"wl_home given "$wl_home" doesn't exists. Please Verify and make sure right WL_HOME is captured during planning."${RESET}
	fail_exit
else
	echo " "
	if [[ ${product_version} == 10.3.6.0 ]]; then
		echo -e ${CYAN}"***************************************************************"
		echo "Applying $product ${release_month} PSU Patches on ${HOST}"
		echo -e "***************************************************************"${RESET}
		echo " "
		#source $TECHPMPPROPFILE
		echo "Weblogic HOME Requested to Patch : $wl_home"
		echo ""
		for psu_patch_set in $(echo $psu_patch_id | tr "," "\n")
		do
		psu_patch_id=`echo $psu_patch_set|cut -d'!' -f 1`
		psu_post_patch=`echo $psu_patch_set|cut -d'!' -f 2`
		wls_psu_check_11g
		done
	else
		export ORACLE_HOME=`cd $wl_home/..;pwd`
		export PATH=$ORACLE_HOME/OPatch:$PATH
		opatch_list pre
		echo " "
		echo -e ${CYAN}"***************************************************************"
		echo "Applying $product ${release_month} PSU Patches on ${HOST}"
		echo -e "***************************************************************"${RESET}
		echo " "
		#source $TECHPMPPROPFILE
		echo "Weblogic HOME Requested to Patch : $wl_home"
		echo ""
		psu_patch=`$ORACLE_HOME/OPatch/opatch lsinventory -invPtrLoc $ORACLE_HOME/oraInst.loc | grep -i 'WLS PATCH SET UPDATE' | awk '{ $1=""; $2=""; print}'`
		echo "current weblogic version=${weblogic_version}"
		echo "current psu patch=${psu_patch}"
		psu_patch_apply
	fi
fi
}

wls_psu_check_11g()
{
bsu_dir=${wl_home}/../utils/bsu
cache_dir=${wl_home}/../utils/bsu/cache_dir
#product_version=`$JAVA_HOME/bin/java -cp weblogic.jar weblogic.version 2>&1 | head -n 2`
. $wl_home/server/bin/setWLSEnv.sh > /dev/null
PSU_PATCH=`$JAVA_HOME/bin/java weblogic.version|grep PSU`
cd $bsu_dir
FAIL=`./bsu.sh -view -prod_dir=${wl_home} -status=applied|egrep 'The patch target could not be located' |wc -l`
echo current_weblogic_version=$product_version
echo current_psu_patch=$PSU_PATCH
echo " "
if [[ $PSU_PATCH == *${product_version}.${psu_patch_release}* ]]; then
	echo -e "Weblogic Patch for ${latest_release} : PSU ${product_version}.${psu_patch_release} Patch ${psu_patch_id} ==> ${GREEN} Already Applied. Skipping ${RESET}"
#	et=$(date +"%s")
#	diff=$(($et-$st))
#	echo " "
#	echo -e ${YELLOW}"Total Time Taken for Applying Weblogic PSU Patches : $(($diff / 60)) minutes and $(($diff % 60)) seconds elapsed."${RESET}
elif [[ $FAIL == 1 ]]; then
	echo "bsu not able to identifiy right wl_home. Weblogic re-installation required."
	#wls_install_1036
	#wls_psu_patch_apply_11g
	fail_exit
elif [[ $FAIL != 1 ]] && [[ -z $PSU_PATCH ]]; then
	wls_psu_patch_apply_11g
elif [[ $FAIL != 1 ]] && [[ ! -z $PSU_PATCH ]]; then
#elif [[ $FAIL != 1 ]]; then
	flag=0
	echo "Validation of the Known Conflict Patch(s) in progress...."
	for conflict_id in $(echo $conflict_ids | tr "," "\n")
	do
	bsu_dir=${wl_home}/../utils/bsu
	l=`./bsu.sh -view -prod_dir=${wl_home} -status=applied|grep ${conflict_id} |wc -l`
	if [ "$l" == 1 ]; then
		echo "Rolling back the conflict Patch : ${conflict_id} started..."
		GO=`./bsu.sh -remove -prod_dir=${wl_home} -patchlist=${conflict_id}|grep 'Success'|wc -l`
		if [ ${GO} == 1 ]; then
			echo -e "Conflict Patch ${conflict_id} rolled back Successfully."
		else
			echo -e ${RED}"Error encountered while rolloing back :${conflict_id}, please review"${RESET}
			fail_exit
		fi
		flag=1
	fi
	done
	wls_psu_patch_apply_11g
	if [ ${go} == 1 ]; then
	echo -e "Weblogic Patch for ${latest_release} : PSU ${weblogic_version}.${psu_patch_release} Patch ${psu_patch_id} ==> ${GREEN} Applied successfully. ${RESET}"
	echo ""
	else
	echo -e "Patch ${psu_patch_id} ${RED} Installation Failed ${RESET}. Please review the $OUT_FILE and Fix it"
	fail_exit
	fi
fi
echo ""
if [[ ( ! -z $mand_patches ) && ( $mand_patches != None ) ]]; then
#st=$(date +"%s")
for mand_patch_set in $(echo $mand_patches | tr "," "\n")
do
psu_patch_id=`echo $mand_patch_set|cut -d'!' -f 1`
patch_id=`echo $mand_patch_set|cut -d'!' -f 2`
if [[ ( $patch_id != IS48 ) && ( ! -z $include ) ]] || [[ -z $include ]]; then
mand_go=`./bsu.sh -view -status=applied -prod_dir=${wl_home} | grep ${patch_id} | wc -l`
if [[ ${mand_go} -ge 1 ]]; then
echo -e "Weblogic Recommended Patch on top of PSU ${weblogic_version}.${psu_patch_release} Patch ${psu_patch_id} ==> ${GREEN} Already Applied. ${RESET}"
else
echo "Applying Recommended Patch : ${psu_patch_id}"
wls_psu_patch_apply_11g
if [ ${go} == 1 ]; then
	echo -e "Weblogic Recommended Patch on top of PSU ${weblogic_version}.${psu_patch_release} Patch ${psu_patch_id} ==> ${GREEN} Applied successfully. ${RESET}"
	echo ""
else
	echo -e "Weblogic Recommended Patch on top of PSU ${weblogic_version}.${psu_patch_release} Patch ${psu_patch_id} ==> ${RED} Failed. ${RESET}"
	fail_exit
fi
fi
fi
done	
fi
echo ""
echo "Complete List of Patch(s) Applied to $wl_home:"
./bsu.sh -view -status=applied -prod_dir=${wl_home} | grep 'Patch ID' | awk -F":" '{print$2}'
et=$(date +"%s")
diff=$(($et-$st))
echo " "
echo -e ${YELLOW}"Total Time Taken for Applying Weblogic PSU Patches : $(($diff / 60)) minutes and $(($diff % 60)) seconds elapsed."${RESET}
}

wls_psu_patch_apply_11g()
{
echo "Started Applying PSU Patch ${psu_patch_id}....."
OUT_FILE=$LOG_DIR/${psu_patch_id}_apply_`date +"%Y%m%d"`_${HOST}.log
cache_dir=${wl_home}/../utils/bsu/cache_dir
bsu_dir=${wl_home}/../utils/bsu
mkdir -p ${cache_dir}
cd $CPU_PATCH_TOP/${psu_patch_id}
patch_jar_file="$(find $CPU_PATCH_TOP/${psu_patch_id} -type f -iname *.jar -execdir basename {} ';')"
patch_xml_file="$(find $CPU_PATCH_TOP/${psu_patch_id} -type f -iname *.xml -execdir basename {} ';')"
patch_jar_id=`echo $patch_jar_file | awk -F"." '{print$1'}`
cp $CPU_PATCH_TOP/${psu_patch_id}/${patch_jar_file} $cache_dir
cp $CPU_PATCH_TOP/${psu_patch_id}/${patch_xml_file} $cache_dir
cd $cache_dir
cp ${patch_xml_file} patch-catalog.xml
cd $bsu_dir
MEMVAL=`cat bsu.sh | grep -i mem_args=`
oldvalue="$MEMVAL"
CHECKMEM=`cat bsu.sh | grep -i "MEM_ARGS=" | cut -d"=" -f2 | cut -d" " -f1 | sed "s/[^0-9]//g"`
if [ "$CHECKMEM" -le 2048 ]; then
	pattern="MEM_ARGS="
	replacement="MEM_ARGS=\"-Xms3072m -Xmx3072m\""
	cp -pr bsu.sh bsu.sh_psupatch
	sed -i "/${pattern}/c ${replacement}" bsu.sh
fi
./bsu.sh -install -patch_download_dir=${cache_dir} -patchlist=${patch_jar_id} -prod_dir=${wl_home} -verbose -log=$OUT_FILE > /dev/null
go=`./bsu.sh -view -prod_dir=${wl_home} -status=applied| grep ${patch_jar_id} | wc -l`
}

##########################################
# For Applying WLS JDBC Driver Patches
##########################################
wls_jdbc_driver_apply()
{
#skip_check
if [[ $jdbc_skip -ne Y ]] || [[ -z $jdbc_skip ]]; then
st=$(date +"%s")
echo " "
product=weblogic_jdbc
product_version=`echo $weblogic_version`
product_short_ver=`echo ${product_version//[-._]/}`
jdbc_patch_ids=`cat $TECHPMPPROPFILE | grep ${product}_${product_short_ver}_psu_patch_id | awk -F"=" '{print$2}'`
echo -e ${CYAN}"**********************************************************"
echo "Applying Weblogic JDBC Driver upgrade Patches on ${HOST}"
echo -e "**********************************************************"${RESET}
if [[ ( $product_version == *10.3.6.0* ) || ( $product_version == *12.1.1.0* ) ]]; then
	current_jdk_version=`java -jar $wl_home/server/lib/ojdbc6.jar -getversion | head -n 1`
	recommeneded_driver=12.1.2.1.0
	go=`echo $current_jdk_version | grep -i $recommeneded_driver | wc -l`
	if [[ $go == 1 ]]; then
		echo "Current JDBC driver version : $current_jdk_version"
		echo "Weblogic server is on recommeneded jdbc drivers version : $recommeneded_driver"
		echo -e "JDBC Drives Patch ${jdbc_patch_ids} : ${GREEN} Already Applied. Skipping ${RESET}"
	else
		echo "Current JDBC driver version : $current_jdk_version"
		echo "Applying JDBC driver Patch : ${jdbc_patch_ids}"
		wls_jdbc_files="$wl_home/server/lib,ojdbc6.jar|$wl_home/server/ext/jdbc/oracle/11g,ojdbc6_g.jar|$wl_home/server/ext/jdbc/oracle/11g,ojdbc6dms.jar|$wl_home/server/ext/jdbc/oracle/11g,ojdbc6dms_g.jar"
		for jdbc_file in $(echo ${wls_jdbc_files} | tr "|" "\n")
		do
		file_target_loc=`echo $jdbc_file | awk -F',' '{print $1}'`
		file_name=`echo $jdbc_file | awk -F',' '{print $2}'`
		cd $file_target_loc
		if [[ -f ${file_name} ]]; then
			mv ${file_name} ${file_name}_{$now}
			cp $CPU_PATCH_TOP/${jdbc_patch_ids}/${file_name} ${file_target_loc}
		else
			cp $CPU_PATCH_TOP/${jdbc_patch_ids}/${file_name} ${file_target_loc}
		fi
		done
		upgraded_jdk_version=`java -jar $wl_home/server/lib/ojdbc6.jar -getversion | head -n 1`
		upgrade_go=`echo $upgraded_jdk_version | grep -i $recommeneded_driver | wc -l`
		if [[ $upgrade_go == 1 ]]; then
			echo -e "JDBC Drives Patch ${jdbc_patch_ids} : ${GREEN} Applied successfully. ${RESET}"
			echo "Current JDBC driver version : $upgraded_jdk_version"		
		else
			echo -e "JDBC Drives Patch ${jdbc_patch_ids} : ${RED}Failed"${RESET}
			echo "Please Fix and Continue"
			fail_exit
		fi
	fi
elif [[ ( $product_version == *8.1* ) || ( $product_version == *10.3.5* ) || ( $product_version == *10.3.4* ) || ( $product_version == *10.3.3* ) || ( $product_version == *10.3.2* ) ]]; then
	echo -e ${RED}"De-Supported Version of Weblogic, No JDBC drivers upgrade required for this version"${RESET}
else
	echo "Patches required to meet the JDBC requirement : ${jdbc_patch_ids}"
	for jdbc_patch_id in $(echo $jdbc_patch_ids | tr "," "\n")
	do
	go=`$ORACLE_HOME/OPatch/opatch lsinventory -invPtrLoc $ORACLE_HOME/oraInst.loc | grep -i $jdbc_patch_id | wc -l`
	if [[ ${go} -ge 1 ]]; then
		echo -e "$jdbc_patch_id: ${GREEN} Already Applied. Skipping ${RESET}"
	else
		echo "Applying the missing Patch $jdbc_patch_id is in progress.."
		jdbc_patch_apply
	fi
	done
	et=$(date +"%s")
	diff=$(($et-$st))
	echo " "
	echo -e ${YELLOW}"Total Time Taken for Applying Weblogic PSU Patches : $(($diff / 60)) minutes and $(($diff % 60)) seconds elapsed."${RESET}
fi
fi
}

jdbc_patch_apply()
{
OUT_FILE=$LOG_DIR/${jdbc_patch_id}_apply_`date +"%Y%m%d"`_${HOST}.log
cd $CPU_PATCH_TOP/${jdbc_patch_id}
$ORACLE_HOME/OPatch/opatch apply -invPtrLoc $ORACLE_HOME/oraInst.loc -silent > $OUT_FILE
bug_apply_go=`$ORACLE_HOME/OPatch/opatch lspatches -invPtrLoc $ORACLE_HOME/oraInst.loc  | grep -i ${jdbc_patch_id} | wc -l`
opatch_succ=`egrep -i 'warning|error|OPatch failed' $OUT_FILE | wc -l`
if [[ $opatch_succ -gt 0 ]] && [[ $bug_apply_go -eq 0 ]]; then
	echo -e "Patch ${jdbc_patch_id} ${RED} Installation Failed ${RESET}. Please review the $OUT_FILE and Fix it"
	rm -rf $LOG_DIR/$HOST/${jdbc_patch_id}
	fail_exit
elif [[ $bug_apply_go -ge 1 ]]; then
	echo -e "Patch ${jdbc_patch_id} ==> ${GREEN} Applied successfully. ${RESET}"
	rm -rf $LOG_DIR/$HOST/${jdbc_patch_id}
fi
}

wl_special_post()
{
echo "Connect to Database as Sys User"
echo ""
echo "For All Weblogic Schemas ends with %_WLS, Revoke and Grant below privileges"
echo "eg: Schemas BIPUB_WLS,OTMWEBAPP_WLS, we need to run for both schemas in this case"
echo ""
echo "REVOKE create any index FROM %_WLS;"
echo "REVOKE create any trigger FROM %_WLS;"
echo "REVOKE create any table FROM %_WLS;"
echo "REVOKE create any view FROM %_WLS;"
echo "GRANT create trigger to %_WLS;"
echo "GRANT create table to %_WLS;"
echo "GRANT create view to %_WLS;"
echo ""
echo "For All Weblogic Schemas ends with %_WLS_RUNTIME, Revoke and Grant below privileges"
echo "eg: Schemas BIPUB_WLS_RUNTIME"
echo ""
echo "REVOKE create any index FROM %_WLS_RUNTIME;"
echo "REVOKE create any trigger FROM %_WLS_RUNTIME;"
echo "GRANT create trigger to %_WLS_RUNTIME;"
echo ""
echo "Make sure you have followed above post patch instructions manually before proceeding further... Once done Press enter to continue..."
read var
if [[ ${var} == ""  ]]; then
	sleep 2
else
	echo -e ${RED}"Your entry is not Enter, So assuming you don't want to continue further"
	echo -e "Run Special Instructions manually and Start the script again. Quitting...."${RESET}
	fail_exit
fi
}

#####################################
# For Applying OHS CPU Patches
#####################################
ohs_patch()
{
if [[ $ohs_skip -ne Y ]] || [[ -z $ohs_skip ]]; then
source $TECHPMPPROPFILE
ohs_go=`cat $TECHPMPPROPFILE | grep 'OHS_version'| wc -l`
if [[ ${ohs_go} -ge 1 ]]; then
ohs_versions=`cat $TECHPMPPROPFILE | grep 'OHS_version' | awk -F"=" '{print$2}'`
for ohs_version in $ohs_versions
do
product=OHS
product_version=`echo $ohs_version`
product_short_ver=`echo ${product_version//[-._]/}`
ohs_home=`cat $TECHPMPPROPFILE | grep ${product}_${product_short_ver}_home | awk -F"=" '{print$2}'`
psu_patch_id=`cat $TECHPMPPROPFILE | grep ${product}_${product_short_ver}_psu_patch_id | awk -F"=" '{print$2}'`
prereq_patch_ids=`cat $TECHPMPPROPFILE | grep ${product}_${product_short_ver}_prereq_patch_id | awk -F"=" '{print$2}'`
mand_patches=`cat $TECHPMPPROPFILE | grep ${product}_${product_short_ver}_mand_patch | awk -F"=" '{print$2}'`
conflict_ids=`cat $TECHPMPPROPFILE | grep ${product}_${product_short_ver}_conflict_id | awk -F"=" '{print$2}'`
psu_patch_release=`cat $TECHPMPPROPFILE | grep ${product}_${product_short_ver}_psu_patch_release | awk -F"=" '{print$2}'`
latest_release=`cat $TECHPMPPROPFILE | grep ${product}_${product_short_ver}_latest_release | awk -F"=" '{print$2}'`
ohs_domain_home=`cat $TECHPMPPROPFILE | grep ${product}_${product_short_ver}_domain_home | awk -F"=" '{print$2}'`
echo -e "${CYAN}****************************************************"
echo -e "Applying $product $release_month Patches on ${HOST}"
echo -e "****************************************************"${RESET}
echo " "
echo " $product HOME Requested to Patch : $ohs_home"
echo " $product Domain HOME Requested to Patch : $ohs_domain_home"
#echo ""
export ORACLE_HOME=$ohs_home
export PATH=$ORACLE_HOME/bin:$ORACLE_HOME/OPatch:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/ohs/lib:$ORACLE_HOME/opmn/lib:$ORACLE_HOME/lib:$ORACLE_HOME/oracle_common/lib:$LD_LIBRARY_PATH
ohs_cpu_patch_apply
done
fi
fi
}

ohs_cpu_patch_apply()
{
st=$(date +"%s")
#export ORACLE_HOME=$OHS_ORACLE_HOME
ohs_opatch_cmd_chk=`$ORACLE_HOME/OPatch/opatch lsinventory -invPtrLoc $ORACLE_HOME/oraInst.loc | grep -i 'error code' | wc -l`
if [[ $ohs_opatch_cmd_chk -gt 0 ]]; then
	echo "OPatch Command Failed. Please Fix it and Rerun the script. "
	fail_exit
else
	if [[ $ohs_version == 11.1.1.6.0 ]];then
		#replacement_sslcipher_string='SSL_RSA_WITH_3DES_EDE_CBC_SHA,SSL_RSA_WITH_DES_CBC_SHA,TLS_RSA_WITH_AES_128_CBC_SHA,TLS_RSA_WITH_AES_256_CBC_SHA'
		#replacement_sslprotocol_string='SSLProtocol nzos_Version_1_0'
		#search_string=SSL_RSA_WITH_AES_256_CBC_SHA
		opatch_list pre
		psu_patch_apply
	elif [[ $ohs_version == 11.1.1.7.0 ]]; then
		replacement_sslcipher_string='SSLCipherSuite SSL_RSA_WITH_AES_128_CBC_SHA,SSL_RSA_WITH_AES_256_CBC_SHA'
		replacement_sslprotocol_string='SSLProtocol nzos_Version_1_0'
		search_string=SSL_RSA_WITH_AES_256_CBC_SHA
		opatch_list pre
		psu_patch_apply
	elif [[ $ohs_version == 11.1.1.9.0 ]]; then
		replacement_sslcipher_string='SSLCipherSuite SSL_RSA_WITH_AES_128_CBC_SHA,SSL_RSA_WITH_AES_256_CBC_SHA,TLS_RSA_WITH_AES_128_CBC_SHA256,TLS_RSA_WITH_AES_256_CBC_SHA256,TLS_RSA_WITH_AES_128_GCM_SHA256,TLS_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA,TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA,TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256,TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384,TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384'
		search_string=ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
		opatch_list pre
		psu_patch_apply
	elif [[ $ohs_version == 12.1.3.0.0 ]]; then
		replacement_sslcipher_string='SSLCipherSuite SSL_RSA_WITH_AES_128_CBC_SHA,SSL_RSA_WITH_AES_256_CBC_SHA,RSA_WITH_AES_128_CBC_SHA256,RSA_WITH_AES_256_CBC_SHA256,RSA_WITH_AES_128_GCM_SHA256,RSA_WITH_AES_256_GCM_SHA384,ECDHE_ECDSA_WITH_AES_128_CBC_SHA,ECDHE_ECDSA_WITH_AES_256_CBC_SHA,ECDHE_ECDSA_WITH_AES_128_CBC_SHA256,ECDHE_ECDSA_WITH_AES_256_CBC_SHA384,ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,ECDHE_ECDSA_WITH_AES_256_GCM_SHA384'
		search_string=ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
		opatch_list pre
		psu_patch_apply
	elif [[ $ohs_version == 12.2.1.1.0 ]];then
		replacement_sslcipher_string='SSLCipherSuite TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384,TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256,TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA,TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384,TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256,TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA,TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA,TLS_RSA_WITH_AES_256_GCM_SHA384,TLS_RSA_WITH_AES_128_GCM_SHA256,TLS_RSA_WITH_AES_256_CBC_SHA256,TLS_RSA_WITH_AES_128_CBC_SHA256,SSL_RSA_WITH_AES_256_CBC_SHA,SSL_RSA_WITH_AES_128_CBC_SHA'
		search_string=ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
		opatch_list pre
		psu_patch_apply
	elif [[ $ohs_version == 12.2.1.2.0 ]]; then
		replacement_sslcipher_string='SSLCipherSuite TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384,TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256,TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA,TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384,TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256,TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA,TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA,TLS_RSA_WITH_AES_256_GCM_SHA384,TLS_RSA_WITH_AES_128_GCM_SHA256,TLS_RSA_WITH_AES_256_CBC_SHA256,TLS_RSA_WITH_AES_128_CBC_SHA256,SSL_RSA_WITH_AES_256_CBC_SHA,SSL_RSA_WITH_AES_128_CBC_SHA'
		search_string=ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
		opatch_list pre
		psu_patch_apply
	elif [[ $ohs_version == 12.2.1.3.0 ]]; then
		opatch_list pre
		psu_patch_apply
	fi
fi
}

ohs_post_patch()
{
echo "Performing Post-Patching Steps for ${pre_patch_id}:"
if [[ ( -d $ohs_domain_home ) && ( $product_version == 12.* ) ]]; then	
	ohs_comp_name=`basename $ohs_domain_home`
	cd $ohs_domain_home/../../$ohs_comp_name
elif [[ ( -d $ohs_domain_home ) && ( $product_version == 11.1.1.* ) ]]; then
	cd $ohs_domain_home
fi
mod_files='httpd.conf,ssl.conf,admin.conf'
for modfile in $(echo $mod_files | tr "," "\n")
do
file_mod=`grep SSLCipherSuite ${modfile} | wc -l`
if [[ $file_mod != 0 ]] ; then
	cp ${modfile} ${modfile}.`date +"%Y%m%d"`
	if [[ ( ! -z ${replacement_sslcipher_string} ) && ( ! -z ${replacement_sslprotocol_string} ) ]]; then
		sed -i "/SSLCipherSuite/c $replacement_sslcipher_string" ${modfile}
		sed -i "/SSLProtocol/c $replacement_sslprotocol_string" ${modfile}
		GO=`grep -i ${search_string} ${modfile} | wc -l`
		GO_2=`grep -i nzos_Version_3_0 ${modfile} | wc -l`
		if [[ $GO != 0 ]] && [[ $GO_2 == 0 ]]; then
			echo "New SSLCipherSuite changes successfully done to ${modfile}"
		else
			echo "New SSLCipherSuite changes failed to ${modfile}, Please review the post-patch steps and perform manually before starting up the services."
		fi
	elif [[ ( ! -z ${replacement_sslcipher_string} ) && ( ! -z ${replacement_sslprotocol_string} ) ]]; then
		sed -i "/SSLCipherSuite/c $replacement_sslcipher_string" ${modfile}
		GO=`grep -i ${search_string} ${modfile} | wc -l`
		if [[ $GO != 0 ]]; then
			echo "New SSLCipherSuite changes successfully done to ${modfile}"
		else
			echo "New SSLCipherSuite changes failed to ${modfile}, Please review the post-patch steps and perform manually before starting up the services."
		fi
	fi 
fi
done
}

#*************************************************************
# Generic OPatch Patching Steps for 12c and 11g Products
#*************************************************************

psu_patch_apply()
{
st=$(date +"%s")
psu_patch=
psu_post_patch=
pre_patch_id=
for psu_patch_set in $(echo ${psu_patch_id} | tr "," "\n")
do
psu_patch=`echo ${psu_patch_set}|cut -d'!' -f 1`
psu_post_patch=`echo ${psu_patch_set}|cut -d'!' -f 2` 
apply_patch=`cat $TECHPMPPROPFILE | grep ${product}_${psu_patch}_apply | awk -F"=" '{print$2}'`
if [[ ${apply_patch} == Y ]]; then
	psu_check=`$ORACLE_HOME/OPatch/opatch lsinventory -invPtrLoc $ORACLE_HOME/oraInst.loc -jre $JAVA_HOME | grep -i ${psu_patch} | wc -l`
	if [[ $psu_check -ge 1 ]]; then
		echo -e "${product} Patch for ${latest_release} : CPU ${product_version}.${psu_patch_release} Patch ${psu_patch} ==> ${GREEN} Already Applied. Skipping ${RESET}"
		et=$(date +"%s")
		diff=$(($et-$st))
		echo " "
		echo -e ${YELLOW}"Total Time Taken for Applying ${product} CPU Patches : $(($diff / 60)) minutes and $(($diff % 60)) seconds elapsed." ${RESET}
	else
		if [[ $product_version == 12.2.1.2.0 || $product_version == 12.2.1.3.0 ]];then
		opatch_version_check
		fi
		if [[ ( ! -z ${conflict_ids} ) && ( ${conflict_ids} != None ) ]]; then
		for conflict_id in $(echo $conflict_ids | tr "," "\n")
		do
		conflict_rollback=`$ORACLE_HOME/OPatch/opatch lsinventory -invPtrLoc $ORACLE_HOME/oraInst.loc -jre $JAVA_HOME | grep -i ${conflict_id} | wc -l`
		if [[ $conflict_rollback -ge 1 ]];then
			echo "Rolling Back the Conflict Patches:"
			OUT_FILE=$LOG_DIR/${conflict_id}_uninstall_`date +"%Y%m%d"`_${HOST}.log
			$ORACLE_HOME/OPatch/opatch rollback -id ${conflict_id} -invPtrLoc $ORACLE_HOME/oraInst.loc -jre $JAVA_HOME -silent > $OUT_FILE
			conflict_rollback=`$ORACLE_HOME/OPatch/opatch lsinventory -invPtrLoc $ORACLE_HOME/oraInst.loc -jre $JAVA_HOME | grep -i ${conflict_id} | wc -l`
			opatch_succ=`egrep -i 'warning|error|OPatch failed' $OUT_FILE | wc -l`
			if [[ $opatch_succ == 0 ]] && [[ $conflict_rollback == 0 ]]; then
				echo -e "Conflict Patch ${conflict_id} Uninstalled Successfully"
			elif [[ $conflict_rollback -ge 1 ]]; then
				echo -e "Conflict Patch ${conflict_id} Uninstall ${RED}Failed.....${RESET} Please review the $OUT_FILE and Fix it"
				fail_exit
				et=$(date +"%s")
				diff=$(($et-$st))
				echo " "
				echo -e ${YELLOW}"Total Time Taken for Applying ${product} CPU Patches : $(($diff / 60)) minutes and $(($diff % 60)) seconds elapsed."${RESET}
				echo " "
			fi
		fi
		done
		fi
		if [[ ( ! -z ${prereq_patch_ids} ) && ( ${prereq_patch_ids} != None ) ]]; then
			st=$(date +"%s")
			for pre_patch_set in $(echo ${prereq_patch_ids} | tr "," "\n")
			do
			pre_patch_id=`echo $pre_patch_set|cut -d'!' -f 1`
			post_patch=`echo $pre_patch_set|cut -d'!' -f 2`
			#check_mask_id
			apply_patch=`cat $TECHPMPPROPFILE | grep ${product}_${pre_patch_id}_apply | awk -F"=" '{print$2}'`
			if [[ ${apply_patch} == Y ]]; then
			echo "Applying Pre-requisite Patch : ${pre_patch_id}"
			text=Pre-requisite
			psu_opatch_apply
			fi
			done
			echo " "
			echo -e ${YELLOW}"Total Time Taken for Applying ${product} Pre-requisite Patch(s) : $(($diff / 60)) minutes and $(($diff % 60)) seconds elapsed."${RESET}
			echo " "
		fi
	echo "Applying CPU Patch : ${psu_patch}"
	st=$(date +"%s")
	pre_patch_id=${psu_patch}
	post_patch=${psu_post_patch}
	#check_mask_id
	text=CPU
	psu_opatch_apply
	echo " "
	echo -e ${YELLOW}"Total Time Taken for Applying ${product} CPU Patches : $(($diff / 60)) minutes and $(($diff % 60)) seconds elapsed."${RESET}
	echo " "
	fi
	if [[ ( ! -z $mand_patches ) && ( $mand_patches != None ) ]]; then
		st=$(date +"%s")
		for mand_patch_set in $(echo $mand_patches | tr "," "\n")
		do
		pre_patch_id=`echo $mand_patch_set|cut -d'!' -f 1`
		post_patch=`echo $mand_patch_set|cut -d'!' -f 2`
		#check_mask_id
		apply_patch=`cat $TECHPMPPROPFILE | grep ${product}_${pre_patch_id}_apply | awk -F"=" '{print$2}'`
		if [[ ${apply_patch} == Y ]]; then
			echo "Applying Recommended Patch : ${pre_patch_id}"
			text=Recommended
			psu_opatch_apply
		fi
		done
		echo " "
		echo -e ${YELLOW}"Total Time Taken for Applying ${product} Recommended Patch(s) : $(($diff / 60)) minutes and $(($diff % 60)) seconds elapsed."${RESET}
		echo " "
	fi
elif [[ ${apply_patch} == N ]]; then
	echo -e "${product} Patch for ${latest_release} : CPU ${product_version}.${psu_patch_release} Patch ${psu_patch} ==> ${GREEN} Not Applicable For this Instance. Skipping ${RESET}"
else
	psu_check=`$ORACLE_HOME/OPatch/opatch lsinventory -invPtrLoc $ORACLE_HOME/oraInst.loc -jre $JAVA_HOME | grep -i ${psu_patch} | wc -l`
	if [[ $psu_check -ge 1 ]]; then
		echo -e "${product} Patch for ${latest_release} : CPU ${product_version}.${psu_patch_release} Patch ${psu_patch} ==> ${GREEN} Already Applied. Skipping ${RESET}"
		et=$(date +"%s")
		diff=$(($et-$st))
		echo " "
		echo -e ${YELLOW}"Total Time Taken for Applying ${product} CPU Patches : $(($diff / 60)) minutes and $(($diff % 60)) seconds elapsed." ${RESET}
	else
		echo -e ${RED}"Planning Not done Properly. Make sure we did the planning properly using latest code by keeping all services up"${RESET}
		fail_mail
	fi
fi
done
}			

psu_opatch_apply()
{
install_check=`$ORACLE_HOME/OPatch/opatch lsinventory -invPtrLoc $ORACLE_HOME/oraInst.loc -jre $JAVA_HOME | grep -i ${pre_patch_id} | wc -l`
if [[ $install_check -ge 1 ]]; then
	echo -e "${product} ${text} Patch ${pre_patch_id} for ${product_version}.${psu_patch_release} ==> ${GREEN} Already Applied. Skipping ${RESET}"
	et=$(date +"%s")
	diff=$(($et-$st))
	echo " "
else
	OUT_FILE=$LOG_DIR/${pre_patch_id}_apply_`date +"%Y%m%d"`_${HOST}.log
	if [[ -d $CPU_PATCH_TOP/${pre_patch_id}/etc ]]; then
	cd $CPU_PATCH_TOP/${pre_patch_id}
	elif [[ $CPU_PATCH_TOP/${pre_patch_id}/oui/etc ]]; then
	cd $CPU_PATCH_TOP/${pre_patch_id}/oui
	fi
	if [[ ( $product_version == 11.1.1.* ) && ( ! -f $ORACLE_HOME/../ocm.rsp ) ]]; then
		echo "OCM Response File $ORACLE_HOME/../ocm.rsp is Missing, Creating it..."
		$PMP_SCRIPT_TOP/bin/.response_crt.sh $ORACLE_HOME > /dev/null
		if [[ -f $ORACLE_HOME/../ocm.rsp ]]; then
			echo -e "Response File Creation : ${GREEN}Success${RESET}"
		else
			echo -e "Response File Creation : ${RED}Failed${RESET}"
			fail_exit
		fi
		$ORACLE_HOME/OPatch/opatch apply -invPtrLoc $ORACLE_HOME/oraInst.loc -jre $JAVA_HOME -silent -ocmrf $ORACLE_HOME/../ocm.rsp> $OUT_FILE
	elif [[ ( $product_version == 11.1.1.* ) && ( -f $ORACLE_HOME/../ocm.rsp ) ]]; then
		$ORACLE_HOME/OPatch/opatch apply -invPtrLoc $ORACLE_HOME/oraInst.loc -jre $JAVA_HOME -silent -ocmrf $ORACLE_HOME/../ocm.rsp> $OUT_FILE
	#elif [[ ${ocr_file} == N ]]; then
	else
		$ORACLE_HOME/OPatch/opatch apply -invPtrLoc $ORACLE_HOME/oraInst.loc -jre $JAVA_HOME -silent > $OUT_FILE
	fi
	install_check=`$ORACLE_HOME/OPatch/opatch lsinventory -invPtrLoc $ORACLE_HOME/oraInst.loc -jre $JAVA_HOME | grep -i ${pre_patch_id} | wc -l`
	opatch_succ=`egrep -i 'warning|error|OPatch failed' $OUT_FILE | wc -l`
	opatch_notreq=`egrep -i 'This patch is not needed|not needed since it has no fixes|component(s) that are not installed in OracleHome' $OUT_FILE | wc -l`
	if [[ $opatch_succ -ne 0 ]] && [[ $install_check -eq 0 ]] && [[ $opatch_notreq -ge 1 ]]; then
		echo -e "Patch ${pre_patch_id} is no more Required to apply for $ORACLE_HOME"
	elif [[ $opatch_succ -ne 0 ]] && [[ $install_check -eq 0 ]] && [[ $opatch_notreq -eq 0 ]]; then
		echo -e "Patch ${pre_patch_id} ${RED} Installation Failed ${RESET}..... Please review the $OUT_FILE and Fix it"
		fail_exit
	elif [[ $install_check -ge 1 ]]; then
		echo -e "${product} ${text} Patch ${pre_patch_id} for ${product_version}.${psu_patch_release} ==> ${GREEN} Applied successfully. ${RESET}"
		check_oracle_common_patch
		if [[ ( $post_patch == Y ) && ( ! -z $replacement_sslcipher_string ) ]]; then
		ohs_post_patch
		elif [[ ( $post_patch == Y ) && ( -z $replacement_sslcipher_string ) ]]; then
		echo -e ${YELLOW}"###############################################"
		echo "Post Patch Steps for ${pre_patch_id}:"
		echo "###############################################"
		awk  '/Post-Installation/,/Deinstallation/' $CPU_PATCH_TOP/${pre_patch_id}/README.txt | grep -v Section | egrep -v 'Deinstallation|Post-Installation' | sed 's/^/| /'
		echo -e "---------------------------------"${RESET}
		elif [[ $post_patch == S ]]; then
		echo -e " ${YELLOW}#########################################################"
		echo -e " Special Instructions to be followed for ${pre_patch_id}:"
		echo -e " #########################################################"
		awk  "/${pre_patch_id}:Start/,/${pre_patch_id}:End/" $PMP_SCRIPT_TOP/bin/special_instructions.txt | egrep -v ${pre_patch_id}
		echo -e " ---------------------------------${RESET}"
		elif [[ $post_patch == Z ]]; then
		echo -e ${YELLOW}"###############################################"
		echo "Post Patch Steps for ${pre_patch_id}:"
		echo "###############################################"
		echo "This Patch is having many steps to be performed as part of Post Patch, \n please review the Readme of this patch and Apply the before starting the services"
		echo -e "---------------------------------"${RESET}
		fi
		et=$(date +"%s")
		diff=$(($et-$st))
	fi
fi
}

check_oracle_common_patch()
{
if [[ $patch_oracle_common == Y ]]; then
export patch_oracle_common=''
echo "This Patch is even applicable for oracle_common home. Applying..."
dummy_oracle_home=`cd $ORACLE_HOME/../oracle_common;pwd`
if [[ -d ${dummy_oracle_home} ]]; then
ORACLE_HOME_MAIN=`echo $ORACLE_HOME`;ORACLE_HOME=
export ORACLE_HOME=$dummy_oracle_home
psu_opatch_apply
fi
ORACLE_HOME=`echo ${ORACLE_HOME_MAIN}`
fi
}

opatch_version_check()
{
now=$(date +"%m%d%Y")
HOST=${HOST}
oui_ver=`$ORACLE_HOME/OPatch/opatch lsinventory -invPtrLoc $ORACLE_HOME/oraInst.loc -jdk $JAVA_HOME| grep -i 'OUI Version' | awk -F':' '{ print $2 }'`
opatch_ver=`$ORACLE_HOME/OPatch/opatch version -invPtrLoc $ORACLE_HOME/oraInst.loc -jdk $JAVA_HOME| grep -i 'OPatch Version' | awk -F':' '{ print $2 }'`
if [[ $opatch_ver == *13.9.4.2.0* ]] ; then
        echo "We are on Supported version of OPacth : 13.9.4.2.0"
else
        echo "Applying Pre-requisite OPatch:"
        cp -r $ORACLE_HOME/OPatch $ORACLE_HOME/OPatch_${now}
        cd $CPU_PATCH_TOP/6880880
        OUT_FILE=$LOG_DIR/28186730_apply_${now}_${HOST}.log
        $JAVA_HOME/bin/java -jar opatch_generic.jar -silent oracle_home=$ORACLE_HOME > $OUT_FILE
        GO=`grep -i 'install operation completed successfully' $OUT_FILE| wc -l`
        if [[ $GO == 1 ]]; then
                opatch_ver_2=`$ORACLE_HOME/OPatch/opatch version -invPtrLoc $ORACLE_HOME/oraInst.loc -jdk $JAVA_HOME| grep -i 'OPatch Version' | awk -F':' '{ print $2 }'`
                if [[ $opatch_ver_2 == *13.9.4.2.0* ]]; then
                        echo -e "OPatch version 13.9.4.2.0 Installation ==> ${GREEN}Success."${RESET}
                else
                        echo -e "OPatch version 13.9.4.2.0 Installation ==> ${RED}Failed."${RESET}
                        fail_exit
                fi
        else
                echo -e "OPatch version 13.9.4.2.0 Installation ==> ${RED}Failed."${RESET}
                fail_exit
        fi
fi
}

check_mask_id()
{
if [[ -f ${CPU_PATCH_TOP}/${psu_patch}/etc/config/patchdeploy.xml ]]; then
mask_id=`grep patch-id $CPU_PATCH_TOP/${psu_patch}/etc/config/patchdeploy.xml | grep 26318200 | wc -l`
if [[ ${mask_id} == 1 ]]; then
pre_patch_id=26318200
if [[ ( ! -L ${CPU_PATCH_TOP}/${pre_patch_id} ) && ( ! -d ${CPU_PATCH_TOP}/${pre_patch_id} ) ]]; then
ln -s ${CPU_PATCH_TOP}/${psu_patch} ${CPU_PATCH_TOP}/${pre_patch_id}
fi
mask_id=
fi
fi
}

#********************************************
# Java CPU Patching Steps 
#********************************************
java_patch()
{
#skip_check
source $TECHPMPPROPFILE
if [[ $java_skip -ne Y ]] || [[ -z $java_skip ]]; then
source $TECHPMPPROPFILE
JVS=${java_homes}
for JV in $(echo $JVS | tr "," "\n")
do
JAVA_HOME=${JV}
java_cpu_apply
done
fi
}

java_cpu_apply()
{
st=$(date +"%s")
if [[ $JAVA_HOME == '' ]] || [[ $JAVA_HOME == NULL ]]; then
	echo "No JAVA_HOME Configured on this host ${HOST}"
elif [[ ! -d $JAVA_HOME ]]; then
	echo "JAVA_HOME given "$JAVA_HOME" doesn't exists. Please provide right JAVA_HOME"
	fail_exit
else
	source $TECHPMPPROPFILE
	java_jrockit=`$JAVA_HOME/bin/java -version 2>&1 | grep JRockit | wc -l`
	java_jdk=`$JAVA_HOME/bin/java -version 2>&1 | grep HotSpot | wc -l`
	if [[ $java_jrockit == 1 ]]; then
		current_java_version=`$JAVA_HOME/bin/java -version 2>&1 | head -n 1 | awk -F '"' '{print $2}'`
		product=Jrockit_1_6_0
	elif [[ $java_jdk == 1 ]]; then
		 unset _JAVA_OPTIONS
		current_java_version=`$JAVA_HOME/bin/java -version 2>&1 | head -n 1 | awk -F '"' '{print $2}'`
		if [[ $current_java_version == 1.6.* ]];then
			product=Hotspot_1_6_0
		elif [[ $current_java_version == 1.7.* ]];then
			product=Hotspot_1_7_0
		elif [[ $current_java_version == 1.8.* ]];then
			product=Hotspot_1_8_0
		fi
	fi
	java_go=`cat $TECHPMPPROPFILE | grep ${product}_version| wc -l`
	if [[ ${java_go} -ge 1 ]]; then
		java_versions=`cat $TECHPMPPROPFILE | grep ${product}_version | awk -F"=" '{print$2}'`
		for java_version in $java_versions
		do
		product_version=`echo $java_version`
		product_short_ver=`echo ${java_version//[-._]/}`
		pmp_java_home=`cat $TECHPMPPROPFILE | grep ${product}_${product_short_ver}_home | awk -F"=" '{print$2}'`
		psu_patch_id=`cat $TECHPMPPROPFILE | grep ${product}_${product_short_ver}_psu_patch_id | awk -F"=" '{print$2}'`
		java_patch_file=`cat $TECHPMPPROPFILE | grep ${product}_${product_short_ver}_patch_file | awk -F"=" '{print$2}'`
		java_patch_install_file=`cat $TECHPMPPROPFILE | grep ${product}_${product_short_ver}_patch_install_file | awk -F"=" '{print$2}'`
		psu_patch_release=`cat $TECHPMPPROPFILE | grep ${product}_${product_short_ver}_psu_patch_release | awk -F"=" '{print$2}'`
		latest_release=`cat $TECHPMPPROPFILE | grep ${product}_${product_short_ver}_latest_release | awk -F"=" '{print$2}'`
		if [[ ${pmp_java_home} == ${JAVA_HOME} ]]; then
			echo -e "${CYAN}****************************************************"
			echo -e "Applying $product $latest_release Patches on ${HOST}"
			echo -e "****************************************************"${RESET}
			echo " "
			echo " $product HOME Requested to Patch : $JAVA_HOME"
			JAVA_DIR=`basename $JAVA_HOME`
			current_java_version=`$JAVA_HOME/bin/java -version 2>&1 | head -n 1 | awk -F '"' '{print $2}'`
			if [[ $current_java_version == ${java_version} ]]; then
				echo -e " ${product} Patch for ${latest_release} : ${psu_patch_id} - ${java_version} ==> ${GREEN} Already Applied ${RESET}"
			else
				cd `dirname $JAVA_HOME`
				file_ext=`echo ${java_patch_install_file##*.}`
				unzip $CPU_PATCH_TOP/${java_patch_file} ${java_patch_install_file} > /dev/null
				if [[ $file_ext == zip ]] || [[ $file_ext == bin ]]; then
					unzip $CPU_PATCH_TOP/${java_patch_install_file} > /dev/null
					java_fld_name=`unzip -qql ${java_patch_install_file} | sed -r '1 {s/([ ]+[^ ]+){3}\s+//;q}'`
				elif [[ $file_ext == gz ]]; then
					java_fld_name=jdk_${psu_patch_id}
					mkdir $java_fld_name
                    tar xvzf ${java_patch_install_file} -C ${java_fld_name} --strip-components=1> /dev/null
					#gunzip -1 ${java_patch_install_file}.gz;tar -xvf ${java_patch_install_file}
					#java_fld_name=`unzip -qql ${java_patch_install_file} | sed -r '1 {s/([ ]+[^ ]+){3}\s+//;q}'`
					#unzip $CPU_PATCH_TOP/${java_patch_install_file} > /dev/null
				fi
				if [[ -d ${JAVA_DIR}_${now} ]]; then
					rm -rf ${JAVA_DIR}_${now}
				fi
				mkdir ${JAVA_DIR}_${now};mv $JAVA_HOME/* ${JAVA_DIR}_${now}/;rm -rf $JAVA_HOME/*
				cd $JAVA_HOME/../${java_fld_name};mv * $JAVA_HOME/;
				if [[ $? == 0 ]]; then
					cd ../;rm -rf ${java_fld_name};rm ${java_patch_install_file}
				else
					echo -e "${RED}Moving files from ${java_fld_name} to $JAVA_HOME failed."${RESET}
					fail_exit
				fi
				current_java_version=
				current_java_version=`$JAVA_HOME/bin/java -version 2>&1 | head -n 1 | awk -F '"' '{print $2}'`
				if [[ $current_java_version == ${java_version} ]]; then
					echo -e "${product} Patch for ${latest_release} : ${psu_patch_id} - ${java_version} ==> ${GREEN} Applied successfully. ${RESET}"
					java_post
					cert_verifier
					java_file_remove
				else
					echo -e "${product} Patch for ${latest_release} : ${psu_patch_id} - ${java_version} ==> ${RED} Install Failed. ${RESET}"
					java_file_remove
					fail_exit
				fi
			fi
		fi
		#echo ""
		done
	fi
et=$(date +"%s")
diff=$(($et-$st))
echo " "
echo -e ${YELLOW}"Total Time Taken for Applying JAVA Release Patch : $(($diff / 60)) minutes and $(($diff % 60)) seconds elapsed."${RESET}
#success_mail
fi
}

java_post()
{
DT=`date +"%Y%m%d%H%M"`
cd $JAVA_HOME/jre/lib/security
cp java.security java.security_${DT}
sed -i -e 's/MD5, //g' java.security
sed -i -e 's/MD5withRSA, //g' java.security
sed -i -e 's/keySize < 1024/keySize < 512/g' java.security
sed -i -e 's/keySize < 2048/keySize < 512/g' java.security
GO=`egrep 'MD5,|MD5withRSA,|keySize < 1024|keySize < 2048' java.security | wc -l`
if [[ $GO == 0 ]]; then
	echo "Post Configuration Changes to java.security : SUCCESS "
else
	echo "Post Configuration Changes to java.security : FAILED "
	echo "Make below changes manually:"
	echo "Remove MD5 & MD5withRSA entries from java.security and also Reduce 1024 keysize to 512"
	echo ""
	java_file_remove
	fail_exit
fi
}

cert_verifier()
{
config_loc=$LOG_DIR/$HOST
keystorepass=$PMP_SCRIPT_TOP/keystorepass.txt
echo "Starting certificates verfication for old and new JDK cacerts keystore."
export PATH=$PATH:$JAVA_HOME/bin
certdir="$config_loc/certificates"
if [[ -d $certdir ]]; then
	rm -rf $certdir
fi
mkdir -p $certdir
cd $certdir

passwd=$(cat $keystorepass | openssl enc -base64 -d | openssl enc -des3 -k mysalt -d)
encpsswdchecker=$(echo -n $passwd | openssl enc -des3 -k mysalt | openssl enc -base64)
if [[ -n $passwd && $encpsswdchecker==$keystorepass ]]; then
	old_certs=${JAVA_HOME}_${now}/jre/lib/security;
	new_certs=$JAVA_HOME/jre/lib/security;
	old_jdk_certs_list="/tmp/certlistold.txt"
	keytool -list -keystore "$old_certs/cacerts" -storepass $passwd | grep ","| sort | awk -F "," '{print $1}'| grep -vF $'[jdk]' > $old_jdk_certs_list
	new_jdk_certs_list="/tmp/certlistnew.txt"
	keytool -list -keystore "$new_certs/cacerts" -storepass $passwd | grep ","| sort | awk -F "," '{print $1}'| grep -vF $'[jdk]' > $new_jdk_certs_list
	diff_certs="/tmp/diffcerts.txt"
	diff --unchanged-line-format= --old-line-format= --new-line-format='%L' $new_jdk_certs_list $old_jdk_certs_list > /tmp/tmp_diff_certs.txt
	cat "/tmp/tmp_diff_certs.txt" | grep -vwF -f ${excluded_certs} > ${diff_certs}
	if [[ -s ${diff_certs} ]]; then
		echo "${Yello}Following is the list of certificates difference found is old JDK keystore $old_certs : "
		echo " ------------------------------------- "
		cat ${diff_certs}
		import_certs
	else
		echo "No certificates difference found is old JDK keystore $old_certs."
	fi
else
	echo "[ERROR] Keystore cacert password is not correct, please recreate $keystorepass!! "
	((error_count++))
	return 1
	java_file_remove
	fail_exit
fi
}

import_certs()
{
if [[ -n ${diff_certs} && -f ${diff_certs} && -s ${diff_certs} ]]; then
	cp -p "$old_certs/cacerts" "$old_certs/cacerts_JDKAutoUpdateMCS_$DATE"
	cp -p "$new_certs/cacerts" "$new_certs/cacerts_JDKAutoUpdateMCS_$DATE"
	echo "Exporting the required certificates...."
	while read line; do
	keytool -exportcert -noprompt -keystore "$old_certs/cacerts" -storepass $passwd -alias "${line}" -file "${certdir}/${line}.cer" 2>&1
	if [[ $? != 0 ]]; then
		echo "[ERROR] Export failed for certificate [$line], please check this certificate manually. "
		((error_count++))
		fail_exit
		java_file_remove
	else
		echo "[${line}] : Certificae Exported Successfully"
	fi
	done <${diff_certs}

	cd $certdir
	cert_to_import="/tmp/certtoimp.txt"
	ls -a | sort | grep .cer > ${cert_to_import}

	if [[ -f ${cert_to_import} && -s ${cert_to_import} ]]; then
		echo "Importing the certificates..."
		while read line; do
		aliasname=$(echo "$line" | cut -f 1 -d '.')
		keytool -importcert -noprompt -keystore "${new_certs}/cacerts" -storepass $passwd -alias "${aliasname}" -file "${certdir}/${line}" 2>&1
		if [[ $? == 0 ]]; then
			echo "[${aliasname}] : Certificate Imported Successfully."
			GO=`keytool -list -noprompt -keystore "${new_certs}/cacerts" -storepass $passwd -alias "${aliasname}" | grep -i "${aliasname}"| wc -l`
			if [[ $GO -ge 1 ]]; then
				echo "[${aliasname}] : Certificate Verified Successfully. "
			else
				echo "[ERROR] ["$aliasname"] : Certificate Verification Failed. Please check this certificate manually. "
				((error_count++))
				java_file_remove
				fail_exit
			fi
		else
			keytool -importcert -noprompt -keystore "${new_certs}/cacerts" -storepass $passwd -alias "${aliasname}" -file "${certdir}/${line}" > "/tmp/import.log"
			checker1=$(cat "/tmp/import.log" | grep -E "already\sexists|Signature\snot\savailable|java.security.NoSuchAlgorithmException" | wc -l)
			if [[ $checker1 -ge 1 ]]; then
				echo "[INFO] Certificate [$aliasname] already exist. "
			else
				echo "[ERROR] Import failed for certificate [$aliasname], please check logfile $logfile. "
				((error_count++))
				java_file_remove
				fail_exit
			fi
		fi
		done <${cert_to_import}
	fi
fi
}

java_file_remove()
{
remove_files="/tmp/certtoimp.txt,/tmp/certlistold.txt,/tmp/certlistnew.txt,/tmp/tmp_diff_certs.txt,/tmp/diffcerts.txt,/tmp/import.log"
for remove_file in $(echo ${remove_files} | tr "," "\n")
do
if [ -f ${remove_file} ]; then
	rm ${remove_file}
fi
done
}

############################

get_user_name()
{
    if [[ -n $(logname) ]]; then
        user_id=$(logname)
    elif [[ -n $(who is there | awk '{print $1}') ]]; then
        user_id=$(who commands me | awk '{print $1}')
    else
        user_id=$USER
    fi
}

fail_mail()
{
today=`date +"%Y%m%d"`
WHOTOPAGE=rakesh.tatineni@oracle.com,retail_automation_in_grp@oracle.com
OUT_EXE_DIR=$HOME/cpu_patches/logs/pmp/execution
OUT_EXE_FILE=$OUT_EXE_DIR/APP_PMP_Execution_${today}_${HOST}.log
OUT_EXE_FILE_MAIL=$OUT_EXE_DIR/APP_PMP_Execution_${today}_${HOST}_mail.log
#sed -r 's/'$(echo -e "\033")'\[[0-9]{1,2}(;([0-9]{1,2})?)?[mK]//g' $OUT_EXE_FILE > $OUT_EXE_FILE_MAIL
sed -r 's~\x01?(\x1B\(B)?\x1B\[([0-9;]*)?[JKmsu]\x02?~~g' $OUT_EXE_FILE > $OUT_EXE_FILE_MAIL
get_user_name
echo "Execution Failed"
#message_body="$scriptname invoked by $user_id failed on $DB_NAME: $HOST"
#echo "$message_body" |/bin/mail -s "$DB_NAME : Application Tech Stack PMP Execution for ${release_month} Failed on $HOST" -a $OUT_EXE_FILE_MAIL ${WHOTOPAGE}
/bin/mail -s "Application Tech Stack PMP Execution for ${release_month} Failed on $HOST : Invoked by $user_id" ${WHOTOPAGE} < $OUT_EXE_FILE_MAIL
del_lst=`find $LOG_DIR -name "*.lst" -type f | wc -l`;if [[ $del_lst -ge 1 ]]; then rm $LOG_DIR/opatch*.lst;fi
exit 1;
}

success_mail()
{
today=`date +"%Y%m%d"`
WHOTOPAGE=rakesh.tatineni@oracle.com,retail_automation_in_grp@oracle.com
OUT_EXE_DIR=$HOME/cpu_patches/logs/pmp/execution
OUT_EXE_FILE=$OUT_EXE_DIR/APP_PMP_Execution_${today}_${HOST}.log
OUT_EXE_FILE_MAIL=$OUT_EXE_DIR/APP_PMP_Execution_${today}_${HOST}_mail.log
#sed -r 's/'$(echo -e "\033")'\[[0-9]{1,2}(;([0-9]{1,2})?)?[mK]//g' $OUT_EXE_FILE > $OUT_EXE_FILE_MAIL
sed -r 's~\x01?(\x1B\(B)?\x1B\[([0-9;]*)?[JKmsu]\x02?~~g' $OUT_EXE_FILE > $OUT_EXE_FILE_MAIL
get_user_name
echo "Execution Completed"
#message_body="$scriptname invoked by $user_id succeeded on $DB_NAME: $HOST"
#echo "$message_body" |/bin/mail -s "$DB_NAME : Application Tech Stack PMP Execution for ${release_month} succeeded on $HOST" -a $OUT_EXE_FILE_MAIL ${WHOTOPAGE}
/bin/mail -s "Application Tech Stack PMP Execution for ${release_month} succeeded on $HOST : Invoked by $user_id" ${WHOTOPAGE} < $OUT_EXE_FILE_MAIL
del_lst=`find $LOG_DIR -name "*.lst" -type f | wc -l`;if [[ $del_lst -ge 1 ]]; then rm $LOG_DIR/opatch*.lst;fi
exit 0;
}

fail_exit()
{
et=$(date +"%s")
diff=$(($et-$st))
echo " "
echo "Total Time Taken: $(($diff / 60)) minutes and $(($diff % 60)) seconds elapsed."
fail_mail
exit 1;
}

show_usage() # Prints basic help information.
{
echo -e "\n Usage:"
echo -e "   ${0##*/} -m <Arg1> -a <Arg2> -i <Arg3> -s <Arg4>"
echo -e "   Arg1 : CPU Release Month in MMMYYYY Format [Required]"
echo -e "   Arg2 : Execution Type auto or manual [Conditional]"
echo -e "               For OTM:"
echo -e "                       auto : When no post-patch scripts required to run manually by keeping the script execution on pause."
echo -e "                       manual : When we have to run few post-patch scripts by keeping the script execution on pause, mainly on primary app node."
echo -e " "
echo -e "               For FMW/MDO/RETAIL/DMZ : We can use default value as 'auto' or ignore"
echo -e "   Arg3 : [Optional]"
echo -e "   Option : If we want just apply cpu patches for 'java and/or jdbc and/or weblogic and/or ohs' then,"
echo -e "   We can use all kind of combinations above 4 components to apply."
echo -e "\n Example:"
echo -e "   ./${0##*/} -m apr2019 -a auto/manual\n"
echo -e "   ./${0##*/} -m apr2019 -a auto/manual -i java/jdbc/ohs/wls\n"
echo -e "   ./${0##*/} -m apr2019 -a auto/manual -i java,jdbc\n"
echo -e "   ./${0##*/} -m apr2019 -a auto/manual -i java,wls\n"
echo -e "   ./${0##*/} -m apr2019 -a auto/manual -i ohs,wls\n"
echo -e "   ./${0##*/} -m apr2019 -a auto/manual -i java,wls,ohs\n"
echo -e "   "
echo -e "   Arg4 : [Optional]"
echo -e "   Option : Even after successful planning, if we want skip cpu patches for 'java and/or jdbc and/or weblogic and/or ohs' then,"
echo -e "   We can use all kind of combinations above 4 components to skip."
echo -e "\n Example:"
echo -e "   ./${0##*/} -m apr2019 -a auto/manual\n"
echo -e "   ./${0##*/} -m apr2019 -a auto/manual -s java/jdbc/ohs/wls\n"
echo -e "   ./${0##*/} -m apr2019 -a auto/manual -s java,jdbc\n"
echo -e "   ./${0##*/} -m apr2019 -a auto/manual -s java,wls\n"
echo -e "   ./${0##*/} -m apr2019 -a auto/manual -s ohs,wls\n"
echo -e "   ./${0##*/} -m apr2019 -a auto/manual -s java,wls,ohs\n"
echo -e "   If we wants to skip Weblogic, then automatically jdbc will be part of it."
echo -e " "
echo -e " Note: We can even user combination of include '-i' and skip '-s' in single command"
echo -e " If we want to perform Planning for Weblogic , but to skip jdbc then"
echo -e " ./${0##*/} -m apr2019 -a auto/manual -i java,wls,ohs -s jdbc"
echo -e " "
echo -e "\n Support:"
echo -e "   Email retail_automation_in_grp@oracle.com to report issues or defects.\n"
exit 1;
}

psu_release()
{
echo "This Script is developed to start using from JAN-2019, Provide one CPU release date out of these."
echo "Else Your Input is wrong/incorrect format, please use MMMYYYY format (eg:APR2017).Quitting..."
exit 1;
}

# Main:
script_parameters="$@"

optstring="m:a:i:s:h"
while getopts "$optstring" opt; do
  case "$opt" in
    m)    release_month=$( echo "$OPTARG" | tr  '[:upper:]' '[:lower:]' )
        case $release_month in
        jan2019|apr2019);;
        *)  psu_release;;
        esac;;
    a)    apply_mode=$( echo "$OPTARG" | tr  '[:upper:]' '[:lower:]' )
	case $apply_mode in 
	auto|manual);;
	*)  show_usage;;
	  esac;;
    i)    include=$( echo "$OPTARG" | tr  '[:lower:]' '[:upper:]' )
	case $include in
	ALL|WLS|JAVA|OHS|WLS,JAVA|JAVA,WLS|WLS,OHS|OHS,WLS|JAVA,OHS|OHS,JAVA|WLS,JAVA,OHS|WLS,OHS,JAVA|JAVA,WLS,OHS|JAVA,OHS,WLS|OHS,JAVA,WLS|OHS,WLS,JAVA);;
	*)  show_usage;;
	  esac;;
    s)    skip=$( echo "$OPTARG" | tr  '[:lower:]' '[:upper:]' )
	case $skip in
	JDBC|JAVA|OHS|WLS|WLS,JAVA|JAVA,WLS|WLS,OHS|OHS,WLS|JAVA,OHS|OHS,JAVA|JAVA,WLS,OHS|JAVA,OHS,WLS|JAVA,JDBC,OHS|JAVA,OHS,JDBC|OHS,WLS,JAVA|OHS,JAVA,WLS);;
	*)  show_usage;;
	  esac;;
    h)    show_usage;;
  esac
done;
shift $((OPTIND-1))

if [[ -z $release_month ]]; then
	echo " PSU release is a mandatory arugument you can't skip"
	show_usage
fi

service_active_check

