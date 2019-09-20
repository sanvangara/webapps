#!/bin/bash
# **********************************************************************************************************
# * Filename            :       one_command_pmp_plan_auto.sh
# * Author              :       rtatinen
# * Original            :       16/11/2018
# **********************************************************************************************************
# * Last Modified       :
# * v3.0  16/05/2018    rtatinen        To CPU Patches Applied for Retail Tech Stack
# * v4.0  16/05/2018    rtatinen        Added April 2018 Patches verification
# * v5.0  30/07/2018    rtatinen        Modified for July 2018 Patches verification
# * v5.0  30/07/2018    rtatinen        Inluded Checks for FMW products July 2018 Patches
# * v7.0  06/09/2018    rtatinen        Planning Script to capture all required variable for execution and saves in HOME/.<sid>_pmp.env file
# * v8.0  06/09/2018    rtatinen        Modified Script to work and capture Mutilple Java , WLS and OHS HOMES
# * v9.0  24/09/2018    rtatinen        Modified code to work on 12c DMZ nodes to validate Nodemanager Weblogic HOME and JAVA versions
# * v10.0 24/09/2018    rtatinen        Included weblogic JDBC Drivers checks
# * v11.0 16/11/2018    rtatinen        Included Patches for October-2018 CPU
# * v12.0  18/01/2019	rtatinen		Included January 2019 CPU Patch(s) OTM, Weblogic, OHS & Java 
# * v13.0  18/01/2019	rtatinen		Modified the script and content to do the planning for OCI and OCI-C
# * v14.0  25/02/2019 	rtatinen		Included January 2019 CPU Patch(s) for SOA,OSB,Webcenter,OTD
# * v15.0  25/02/2019 	rtatinen		Included January 2019 CPU Patch(s) oracle_common [ opss,owsm,adf,fmw,oss,jrf,fmw_platform ]
# * v16.0  24/04/2019 	rtatinen		Included January 2019 CPU Patch(s) OID,OVD,OUD, IDM 12c 
# * v17.0  01/05/2019 	rtatinen		Included 11g Weblogic BSU fix, to make the bsu patching faster
# * v18.0  01/05/2019 	rtatinen		Included April 2019 CPU Patch(s) OTM, Weblogic, OHS & Java 
# * v19.0  02/05/2019 	rtatinen		Included April 2019 CPU Patch(s) oracle_common [ opss,owsm,adf,fmw,oss,jrf,fmw_platform ]
# * v20.0  03/05/2019 	rtatinen		Included April 2019 CPU Patch(s) for SOA,OSB,Webcenter,OTD,OID,OVD,OUD, IDM 12c 
# * v21.0  07/05/2019 	rtatinen		Included skip option for Java and JDBC
# * v22.0  08/05/2019 	rtatinen		Included skip and include options for Java, Jdbc, Weblogic and OHS
# **********************************************************************************************************
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
send_mail FAIL
fi

#SID=$( echo "$1" | tr  '[:upper:]' '[:lower:]' )
#DB_NAME=$( echo "$SID" | tr  '[:lower:]' '[:upper:]' )
#release_month=$( echo "$1" | tr  '[:upper:]' '[:lower:]' )
#PRODUCT=$( echo "$2" | tr  '[:lower:]' '[:upper:]' )
#SKIP=$( echo "$3" | tr  '[:lower:]' '[:upper:]' )
PMP_SCRIPT_TOP=/usr/local/MAS/fmw/pmp
CPU_PATCH_TOP=$HOME/cpu_patches
LOG_DIR=$CPU_PATCH_TOP/logs/pmp/planning
FINAL_PATCH_LIST=$CPU_PATCH_TOP/logs/pmp/planning/cpu_patches_final.lst
scriptname=`basename $0`
#scriptname=${scriptfullname%.*}
#HOST=`hostname`
HOST=`cat /etc/passwd| grep compute|cut -f2 -d"@"`
if [[ -z $HOST ]]; then
HOST=`cat /etc/passwd| grep oracleoutsourcing|cut -f2 -d"@"`
if [[ -z $HOST ]]; then
HOST=`hostname`
fi
fi

TECHPMPPROPFILE="$HOME/.fmwpmp.env"
OTMPMPPROPFILE="$HOME/.otmpmp.env"

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

plan_check()
{
if [[ ( -z $include ) || ( $include == ALL ) ]]; then
java_check
wl_check
ohs_sep
#otd_check
fmw_products_check
fmw_common_patches_check
opatch_list
else
for plan_prd in $(echo $include | tr "," "\n")
do
if [[ $plan_prd == JAVA ]]; then
	if [[ $java_skip == Y ]]; then
	echo -e "${RED}We can't use Java option in both Skip and Plan"${RESET}
	send_mail FAIL
	else
	java_check
	fi
elif [[ $plan_prd == WLS ]]; then
	if [[ $wls_skip == Y ]]; then
	echo -e "${RED}We can't use Weblogic option in both Skip and Plan"${RESET}
	send_mail FAIL
	else
	wl_check
	fi
elif [[ $plan_prd == OHS ]]; then
	if [[ $ohs_skip == Y ]]; then
	echo -e "${RED}We can't use OHS option in both Skip and Plan"${RESET}
	send_mail FAIL
	else
	ohs_sep
	fi
fi
done
fi
}

if [[ -f $TECHPMPPROPFILE ]]; then
	#rm $TECHPMPPROPFILE
	bk_file=${TECHPMPPROPFILE}_`date +"%Y%m%d%H%M"`
	mv $TECHPMPPROPFILE $bk_file
fi

if [[ -f $OTMPMPPROPFILE ]]; then
	#rm $OTMPMPPROPFILE
	bk_otm_file=${OTMPMPPROPFILE}_`date +"%Y%m%d%H%M"`
	mv $OTMPMPPROPFILE ${bk_otm_file}
fi

if [[ ! -d $CPU_PATCH_TOP ]]; then
	mkdir -p $CPU_PATCH_TOP
fi

if [[ ! -d $LOG_DIR ]]; then
	mkdir -p $LOG_DIR
fi

if [[ -f $FINAL_PATCH_LIST ]]; then
	rm $FINAL_PATCH_LIST
fi
PATH=$(getconf "PATH"):/sbin:/usr/sbin:$PATH

product_check() # Validate to which Product we do the planning
{
echo ""
echo "*******************************************************************************************"
echo -e "| ${CYAN}${BOLD} Hostname : $HOST" ${RESET}
echo "*******************************************************************************************"
if [[ $PRODUCT = OTM ]]; then
	if [[ ( -z $include ) || ( $include == ALL ) ]]; then
	otm_env_check
	fi
	gather_instance_info
	source $TECHPMPPROPFILE	
	component_check
elif [[ $PRODUCT = MDO ]]; then
	mdo_env_check
	ORACLE_HOME=''
	gather_instance_info
	component_check
elif [[ $PRODUCT = RETAIL ]]; then
	retail_check
	gather_instance_info
	source $TECHPMPPROPFILE
	component_check
elif [[ $PRODUCT == FTI ]]; then
#	MDOMAIN=`ps -ef | grep -v grep |grep -i Dweblogic.Name|grep -o "Dweblogic.Name.*"|cut -d " " -f 1|cut -d"=" -f 2 | grep -v AdminServer| wc -l`
	MDOMAIN=`ps -ef | grep -v grep |grep -i Dweblogic.Name|grep -o "Dweblogic.Name.*"|cut -d " " -f 1|cut -d"=" -f 2| wc -l`
	if [[ $MDOMAIN -gt 0 ]]; then
	echo "| List of Admin and Managed Servers Configured on `hostname`:"
#	MANAGED=`ps -ef | grep -v grep |grep -i Dweblogic.Name|grep -o "Dweblogic.Name.*"|cut -d " " -f 1|cut -d"=" -f 2 | grep -v AdminServer`
	MANAGED=`ps -ef | grep -v grep |grep -i Dweblogic.Name|grep -o "Dweblogic.Name.*"|cut -d " " -f 1|cut -d"=" -f 2`
    echo wls_servers=`echo $MANAGED | tr ' ' ','` >> $TECHPMPPROPFILE
	echo '|'$MANAGED | tr ' ' ','
	echo "|"
	fi
	gather_instance_info
	BI_HOME=`ps -ef | grep -v grep |grep -i Dbi.oracle.home|grep -o "Dbi.oracle.home.*"|cut -d " " -f 1|cut -d"=" -f 2|awk '!seen[$0]++'`
	if [[ $BI_HOME != '' ]]; then
		cd $BI_HOME/bifoundation
		BI_VERSION=`cat version.txt | grep -i 'Release Version' | cut -d":" -f 2`
		echo "| "
		echo "| BI_HOME=$BI_HOME"
		echo "| OBIEE Version : ${BI_VERSION}"
		echo "| "
	fi
	source $TECHPMPPROPFILE
	MWS="${mw_homes}"
	for MW in $(echo $MWS | tr "," "\n")
	do
	MW_HOME=${MW}
	if [[ -d $MW_HOME/odi ]]; then
		cd $MW_HOME/odi/studio/bin
		echo "| ODI_HOME=$MW_HOME/odi"
		OID_VERSION=`cat version.properties | grep -i VER_FULL | cut -d"=" -f 2`
		echo "| ODI Version : ${OID_VERSION}"
		echo "| "
	fi
	if [[ -d $MW_HOME/odi_111 ]]; then
		cd $MW_HOME/odi_111/oracledi/client/odi/bin
		echo "| ODI_HOME=$MW_HOME/odi_111"
		OID_VERSION=`cat version.properties | grep -i VER_FULL | cut -d"=" -f 2`
		echo "| ODI Version : ${OID_VERSION}"
		echo "| "
	fi
	done
	component_check
elif [[ $PRODUCT == FMW ]]; then
#	MDOMAIN=`ps -ef | grep -v grep |grep -i Dweblogic.Name|grep -o "Dweblogic.Name.*"|cut -d " " -f 1|cut -d"=" -f 2 | grep -v AdminServer| wc -l`
	MDOMAIN=`ps -ef | grep -v grep |grep -i Dweblogic.Name|grep -o "Dweblogic.Name.*"|cut -d " " -f 1|cut -d"=" -f 2 | wc -l`
	if [[ $MDOMAIN -gt 0 ]]; then
	echo "| List of Admin and Managed Servers Configured on `hostname`:"
#	MANAGED=`ps -ef | grep -v grep |grep -i Dweblogic.Name|grep -o "Dweblogic.Name.*"|cut -d " " -f 1|cut -d"=" -f 2 | grep -v AdminServer`
	MANAGED=`ps -ef | grep -v grep |grep -i Dweblogic.Name|grep -o "Dweblogic.Name.*"|cut -d " " -f 1|cut -d"=" -f 2`
    echo wls_servers=`echo $MANAGED | tr ' ' ','` >> $TECHPMPPROPFILE
	echo '|'$MANAGED | tr ' ' ','
	echo "|"
	fi
	gather_instance_info
	component_check
elif [[ $PRODUCT == DMZ ]]; then
	gather_instance_info
	component_check
else
	echo "Not able to identify the Product. Please provide Inputs as OTM/MDO/RETAIL/FTI/FMW/DMZ. Quitting..."
	send_mail FAIL
fi
send_mail SUCCESS
}

component_check() # Tech Stack Validation
{
echo "| ******************************************************************************************************************"
echo -e "| ${CYAN} ${BOLD} Middleware Component(s) Installed and their current CPU Validation :${RESET}"
echo "| ******************************************************************************************************************"
if [[ ( $PRODUCT == OTM ) && ( ! -z $GLOG_HOME ) ]]; then
glog_prop=$GLOG_HOME/glog/config/glog.properties
glog_patch_prop=$GLOG_HOME/glog/config/glog.patches.properties
current_otm_version=`egrep -i 'glog.software.patch.version=' $glog_prop |grep -v '#'|cut -d '=' -f 2 `
install_type=`grep ^glog.software.installtype= $glog_prop | awk -F'=' '{ print $2 }'`
if [[ $install_type == WebServer ]] && [[ $current_otm_version == OTMv6.3.* || $current_otm_version == OTMv6.2* ]]; then
	sed -i '/wl_homes/d' $TECHPMPPROPFILE
	sed -i '/mw_homes/d' $TECHPMPPROPFILE
	echo -e "\n| OTM Version $current_otm_version - Web-Node: Weblogic patching not required"
	wl_homes=
fi
fi
skip_check
plan_check
if [[ -s $FINAL_PATCH_LIST ]]; then
echo "| "
echo "| ******************************************************************************************************************"
echo -e "| ${CYAN} ${BOLD}Final List of Patche(s) required to apply on `hostname`${RESET}"
echo "| ******************************************************************************************************************"
echo "| "
echo -e "| Patche(s) Downloaded Location : ${YELLOW}$CPU_PATCH_TOP"${RESET}
echo "CPU_PATCH_TOP=$CPU_PATCH_TOP" >> $TECHPMPPROPFILE
echo "| "
#ls -I logs -I "*.zip" -I "*.txt" $CPU_PATCH_TOP | sed 's/^/| /'
cat $FINAL_PATCH_LIST | sed 's/^/| /'
echo "| ******************************************************************************************************************"
else
echo "No Patches Identified to Apply"
fi
}

wl_check() # Weblogic HOME and Version Check
{
if [[ $wls_skip -ne Y ]] || [[ -z $wls_skip ]]; then
#if [[ ! -z $wls_skip ]]; then
source $TECHPMPPROPFILE
if [[ ! -z ${wl_homes} ]]; then
WLS="${wl_homes}"
for WL in $(echo $WLS | tr "," "\n")
do
WL_HOME=${WL}
x=`basename $WL_HOME`
if [ $x == server ]; then
	WL_HOME=`dirname $WL_HOME`
fi
if [[ ( ! -z ${WL_HOME} ) && ( -f $WL_HOME/server/bin/setWLSEnv.sh ) ]]; then
	. $WL_HOME/server/bin/setWLSEnv.sh > /dev/null
	cd $WL_HOME/server/lib
	unset _JAVA_OPTIONS
	weblogic_version=`$JAVA_HOME/bin/java -cp weblogic.jar weblogic.version 2>&1 | head -n 2| awk 'NF' | awk -F" " '{print $3}'`
	weblogic_cpu_patch_check
elif [[ ( ! -z $WL_HOME ) && ( ! -f $WL_HOME/server/bin/setWLSEnv.sh ) && ( `basename $WL_HOME` == wlserver ) ]]; then
	WL_OHS=1
#	weblogic_cpu_patch_check
fi
done
fi
fi
}

weblogic_cpu_patch_check()
{
echo "| "
echo "| Weblogic Version : ${weblogic_version}"
echo "| Weblogic Home : $WL_HOME"
#weblogic_version=`$JAVA_HOME/bin/java -cp weblogic.jar weblogic.version 2>&1 |grep 'WebLogic Server'| awk 'NF' | awk -F" " '{print $3}'`
#weblogic_version=`$JAVA_HOME/bin/java -cp weblogic.jar weblogic.version 2>&1 | head -n 2| awk 'NF' | awk -F" " '{print $3}'`
product=weblogic
product_version=${weblogic_version}
ORACLE_HOME=`cd $WL_HOME/..;pwd`
product_argumets_set
echo ${product_name}_${product_short_ver}_wl_home="${WL_HOME}" >> $TECHPMPPROPFILE
if [[ $product_version == 10.3.6.0 ]]; then
	PSU_PATCH=`$JAVA_HOME/bin/java weblogic.version|grep PSU`
	echo "| Current PSU Patch Applied : ${PSU_PATCH}"
	psu_compare=`$JAVA_HOME/bin/java weblogic.version|grep PSU | awk -F" " '{print$3}'`
	if [[ -z $PSU_PATCH ]]; then
		bsu_patch_check
	elif [[ ! -z $psu_compare ]]; then
		psu_compare_shrt=`echo ${psu_compare//[-._]/}`
		trg_psu=${product_short_ver}${psu_patch_release}
		if [[ $psu_compare_shrt -gt $trg_psu ]]; then
			echo -e ${RED}"We are already on Advanced Version. Please validate before we proceed with Pathcing"$RESET
		else
			psu_patch_id=`echo $psu_patch_ids|cut -d "!" -f 1`
			post_patch=`echo $psu_patch_ids|cut -d "!" -f 2`
			if [[ $PSU_PATCH == *${product_version}.${psu_patch_release}* ]]; then
				echo -e "| ${product_name} Patch for ${latest_release} : PSU ${product_version}.${psu_patch_release} Patch ${psu_patch_id} ==> ${GREEN} Already Applied ${RESET}"
			else
				bsu_patch_check
			fi
		fi
	fi
	if [[ ( ! -z ${mand_patch_ids} ) && ( ${mand_patch_ids} != None ) ]]; then
		for mand_patch_id in $(echo ${mand_patch_ids} | tr "," "\n")
		do
		psu_patch_id=`echo $mand_patch_id|cut -d "!" -f 1`
		patch_id=`echo $mand_patch_id|cut -d "!" -f 2`
		if [[ ( $patch_id != IS48 ) && ( ! -z $include ) ]] || [[ -z $include ]]; then
			CACHE_DIR=$WL_HOME/../utils/bsu/cache_dir
			bsu_dir=${WL_HOME}/../utils/bsu
			cd $bsu_dir
			perl -p -i -e "s/-Xms256m/-Xms3072m/g" $bsu_dir/bsu.sh
			perl -p -i -e "s/-Xmx512m/-Xmx3072m/g" $bsu_dir/bsu.sh
			mand_patch=`./bsu.sh -view -status=applied -prod_dir=${WL_HOME} | grep $patch_id | wc -l`
			if [[ ${mand_patch} == 1 ]]; then
				echo -e "| Mandatory Patch ${psu_patch_id}: ${GREEN}Already Applied" ${RESET}
			else
				echo -e "| Mandatory Patch ${psu_patch_id}: ${RED}Not Applied" ${RESET}
				echo ${psu_patch_id} >> $FINAL_PATCH_LIST
				patch_dir_check
				mkdir -p $CPU_PATCH_TOP/${psu_patch_id};cd $CPU_PATCH_TOP;mv *.jar *.xml README.txt ${psu_patch_id}
				jar_file="$(find $CPU_PATCH_TOP/${psu_patch_id} -type f -iname *.jar -execdir basename {} ';')"
				if [[ -z $jar_file ]]; then
					echo "Patch Download for ${psu_patch_id} Failed"
					send_mail FAIL
				fi
			fi
		fi
		done
	fi
	wls_jdbc_driver_check
elif [[ $product_version == 12.* ]]; then
	export ORACLE_HOME=`cd $WL_HOME/..;pwd`
	export PATH=$PATH:$ORACLE_HOME/OPatch
	PSU_PATCH=`$ORACLE_HOME/OPatch/opatch lsinventory -invPtrLoc $ORACLE_HOME/oraInst.loc | egrep -i 'WLS PATCH SET UPDATE|PSU PATCH' | awk '{ $1=""; $2=""; print}'`
	echo "| Current PSU Patch Applied : ${PSU_PATCH}"
	psu_compare=`$ORACLE_HOME/OPatch/opatch lsinventory -invPtrLoc $ORACLE_HOME/oraInst.loc | egrep -i 'WLS PATCH SET UPDATE|PSU PATCH' | awk '{ $1=""; $2=""; print}' | awk -F" " '{print$NF}' |sed 's/"//g'`
	if [[ ! -z $psu_compare ]]; then
		psu_compare_shrt=`echo ${psu_compare//[-._]/}`
		tmp_product_short_ver=`echo ${product_short_ver} | rev | cut -c 2- | rev`
		trg_psu=${tmp_product_short_ver}${psu_patch_release}
		if [[ $psu_compare_shrt -gt $trg_psu ]]; then
			echo -e ${RED}"We are already on Advanced Version. Please validate before we proceed with Pathcing"$RESET
		else
			if [[ -z $no_check ]]; then
			#opatch_version_check
			12c_psu_patch_check
			wls_jdbc_driver_check
			fi
		fi
	elif [[ -z $PSU_PATCH ]]; then
		if [[ -z $no_check ]]; then
		12c_psu_patch_check
		wls_jdbc_driver_check
		fi
	fi
fi
}

bsu_patch_check()
{
echo -e "| ${product_name} Patch for ${latest_release} : PSU ${product_version}.${psu_patch_release} Patch ${psu_patch_id} ==> ${RED} Not Applied ${RESET}"
echo ${psu_patch_id} >> $FINAL_PATCH_LIST
#product_short_ver=1036
patch_dir_check
mkdir -p $CPU_PATCH_TOP/${psu_patch_id};cd $CPU_PATCH_TOP;mv *.jar *.xml README.txt ${psu_patch_id}
jar_file="$(find $CPU_PATCH_TOP/${psu_patch_id} -type f -iname *.jar -execdir basename {} ';')"
if [[ -z $jar_file ]]; then
echo "Patch Download for ${psu_patch_id} Failed"
send_mail FAIL
fi
CACHE_DIR=$WL_HOME/../utils/bsu/cache_dir
bsu_dir=${WL_HOME}/../utils/bsu
cd $bsu_dir
cp -r $PMP_SCRIPT_TOP/bin/bsu_fix/* .
echo "| Applying BSU Fix : "
./bsu_update.sh install > bsu_update.log
go=`grep successful bsu_update.log | wc -l`;no_go=`grep failed bsu_update.log | wc -l`
if [[ ${go} == 1 ]]; then
echo -e "| BSU Fix : ${GREEN} Applied Successfully" ${RESET}
elif [[ ${no_go} == 1 ]]; then
echo -e "| BSU Fix : ${RED} Apply Failed" ${RESET}
exit 1;
fi
perl -p -i -e "s/-Xms256m/-Xms3072m/g" $bsu_dir/bsu.sh
perl -p -i -e "s/-Xmx512m/-Xmx3072m/g" $bsu_dir/bsu.sh
FAIL=`./bsu.sh -view -prod_dir=${WL_HOME} -status=applied|egrep 'The patch target could not be located' |wc -l`
if [ $FAIL == 1 ]; then
	echo -e "| ${RED}bsu not able to identifiy right WL_HOME. Weblogic re-installation is required.Included in Apply Script."${RESET}
	send_mail FAIL
else
	echo -e "| bsu command validation : ${GREEN}Success"${RESET}
	echo "| List of Patch(s) Installed:"
	./bsu.sh -view -status=applied -prod_dir=${WL_HOME} | grep 'Patch ID' | awk -F":" '{print$2}' | sed 's/^/| /'
	conflict_patch_ids_check=`echo $conflict_patch_ids | sed -e 's/,/\|/g'`
	conflict_patch_cnt=`./bsu.sh -view -prod_dir=${WL_HOME} -status=applied|egrep \"${conflict_patch_ids_check}\"|wc -l` >/dev/null
	#for i in $(echo ${conflict_patch_ids} | tr "," "\n")
	#for i in $conflict_id
	#do
	#l=`./bsu.sh -view -prod_dir=${WL_HOME} -status=applied|grep $i |wc -l` >/dev/null
	if [[ ${conflict_patch_cnt} -ge 1 ]]; then
	echo "| Conflict Patch(s) Found:"
	./bsu.sh -view -prod_dir=${WL_HOME} -status=applied|egrep \"${conflict_patch_ids_check}\" | awk -F":" '{print$2}' | sed 's/^/| /'
	fi
	#done
fi
}

ohs_sep() # OHS HOME and Version Check
{
if [[ $ohs_skip -ne Y ]] || [[ -z $ohs_skip ]]; then
#if [[ ! -z $ohs_skip ]]; then
source $TECHPMPPROPFILE
#if [[ ${OHS} == '' ]]; then
for OH in $(echo $ohs_oracle_homes | tr "," "\n")
do
	for OH_DH in $(echo $ohs_domain_homes | tr "," "\n")
	do
	ohs_dh_name=`basename $OH_DH`
	ohs_match=`ps -ef | grep -i ${ohs_dh_name} | grep -i ${OH} | grep -v grep | wc -l`
	if [[ $ohs_match -gt 0 ]]; then
		ohs_oracle_home=${OH}
		ohs_domain_home=${OH_DH}
		MEMVAL=`cat ${TECHPMPPROPFILE} | grep -i "ohs_domain_sets=" | grep -vE '^#'`
		NEWVAL="ohs_domain_sets=\"$ohs_oracle_home:$ohs_domain_home\""
		if [[ -z $MEMVAL ]]; then
			echo "${NEWVAL}" >> $TECHPMPPROPFILE
			ORACLE_HOME=${ohs_oracle_home}
			opatch_version_check
			ohs_cpu_patch_check
		elif [[ $MEMVAL == $NEWVAL ]]; then
			ORACLE_HOME=${ohs_oracle_home}
			opatch_version_check
			ohs_cpu_patch_check
		else
			MEMVALUE=`cat ${TECHPMPPROPFILE} | grep -i "ohs_domain_sets=" | grep -vE '^#' | awk -F'=' '{print $2}'`
			APPEND_VAL="ohs_domain_sets=\"${MEMVALUE}|${ohs_oracle_home}:${ohs_domain_home}\""
			sed -i "/^[^#]*${MEMVAL}/c ${APPEND_VAL}" ${TECHPMPPROPFILE};
			ORACLE_HOME=${ohs_oracle_home}
			opatch_version_check
			ohs_cpu_patch_check
		fi
	fi
done
#ohs_check=`pgrep -l -f httpd| wc -l`
#if [[ ${ohs_check} -gt 0 ]]; then
#OHS_HOMES=`pgrep -l -f httpd | cut -d " " -f 2 | awk '!seen[$0]++'| grep -v vnc`
#OHS_TEMP_HOME=`dirname $OHS_TEMP_HOME`
#ORACLE_HOME=`cd $OHS_TEMP_HOME/../..;pwd`
#echo "ohs_oracle_home=$ORACLE_HOME" >> $TECHPMPPROPFILE
done
fi
}

ohs_cpu_patch_check() # OHS PSU Checks 
{
#HOST=$HOST
export PATH=$PATH:$ORACLE_HOME/bin:$ORACLE_HOME/OPatch
export LD_LIBRARY_PATH=$ORACLE_HOME/ohs/lib:$ORACLE_HOME/opmn/lib:$ORACLE_HOME/lib:$ORACLE_HOME/oracle_common/lib:$LD_LIBRARY_PATH
if [ -f $ORACLE_HOME/ohs/bin/httpd.worker ]; then
l=`$ORACLE_HOME/ohs/bin/httpd.worker -version | egrep -i 'Server label' |grep -v '#'| wc -l`
if [ $l -ge 1 ]; then
apache_version=`$ORACLE_HOME/ohs/bin/httpd.worker -version | egrep -i 'Server label' |grep -v '#'|cut -d ':' -f 2 | awk -F"_" '{print $2}'`
else
apache_version=`grep APACHE $ORACLE_HOME/ohs/bin/version.txt| awk -F"_" '{print $2}'`
fi
elif [ -f $ORACLE_HOME/ohs/bin/httpd ]; then
l=`$ORACLE_HOME/ohs/bin/httpd -version | egrep -i 'Server label' |grep -v '#'| wc -l`
if [ $l -ge 1 ]; then
apache_version=`$ORACLE_HOME/ohs/bin/httpd -version | egrep -i 'Server label' |grep -v '#'|cut -d ':' -f 2 | awk -F"_" '{print $2}'`
else
apache_version=`grep APACHE $ORACLE_HOME/ohs/bin/version.txt | awk -F"_" '{print $2}'`
fi
fi
echo "| "
echo "| OHS Version : $apache_version"
echo "| OHS Oracle Home : $ohs_oracle_home"
echo "| OHS Domain Home : $ohs_domain_home"
#ohs_opatch_cmd_chk=`$ORACLE_HOME/OPatch/opatch lsinventory -invPtrLoc $ORACLE_HOME/oraInst.loc| grep -i 'error code' | wc -l`
#if [[ $ohs_opatch_cmd_chk -gt 0 ]]; then
#echo "OPatch Command Failed. Please make sure it works fine and rerun the script. "
#exit 1;
#fi
product_version=${apache_version}
product=ohs
product_argumets_set
echo ${product_name}_${product_short_ver}_domain_home=$ohs_domain_home >> $TECHPMPPROPFILE
if [[ -z $no_check ]]; then
	12c_psu_patch_check
fi
if [[ $WL_OHS == 1 ]]; then
	echo "| "
	echo -e "| ${YELLOW}Weblogic Home related to Standalone 12c OHS Installed on this host:"${RESET}
	weblogic_version=`echo $product_version`
	weblogic_cpu_patch_check
fi
}

opatch_list()
{
if [[ ( ! -z $weblogic_version ) || ( ! -z $apache_version ) ]] && [[ ( $weblogic_version == 12.* ) || ( $apache_version == 12* ) ]];then
echo "| "
echo "| ************************************************************************************************"
echo -e "|${CYAN} ${BOLD}List of Patches Installed for ${YELLOW} [${ORACLE_HOME}] on $HOST:" ${RESET}
echo "| ************************************************************************************************"
$ORACLE_HOME/OPatch/opatch lspatches > /tmp/opatch.lst
echo "| "
cat /tmp/opatch.lst | while read line; do echo "| $line"; done
echo "| "
rm /tmp/opatch.lst
fi
}

opatch_list_11g()
{
tmp_OH=`grep 'Oracle Home' /tmp/opatch.lst | awk -F":" '{printf$2}' | xargs`
if [[ $tmp_OH != $ORACLE_HOME ]]; then
echo "| "
echo "| ************************************************************************************************"
echo -e "|${CYAN} ${BOLD}List of Patches Installed for ${YELLOW} [${ORACLE_HOME}] on $HOST:" ${RESET}
echo "| ************************************************************************************************"
$ORACLE_HOME/OPatch/opatch lsinventory -invPtrLoc $ORACLE_HOME/oraInst.loc > /tmp/opatch.lst
echo "| "
cat /tmp/opatch.lst | while read line; do echo "| $line"; done
echo "| "
fi
#echo "| *************************************************************************"
#rm /tmp/opatch.lst
}

fmw_common_patches_check()
{
echo "|"
touch $HOME/fmw_components.txt;file=fmw_components.txt
if [[ ( ! -z $weblogic_version ) || ( ! -z $apache_version ) ]] && [[ ( $weblogic_version == 12.* ) || ( $apache_version == 12.* ) ]];then
echo "| ************************************************************************************************************************"
echo -e "| ${CYAN}${BOLD}Below section is specific to default patches applicable for 12c MW_HOME [ $ORACLE_HOME ] " ${RESET}
echo "| ************************************************************************************************************************"
product=mandatory
product_version=$product_version
multi_product_argumets_set
#echo fmw_components=$(IFS=,; echo "${fmw_comp[*]}") >> $TECHPMPPROPFILE
#12c_psu_patch_check
else
fmw_common_patches_11g
fi
#echo -e "\n"fmw_components=\'"`cat $HOME/fmw_components.txt`"\' >> $TECHPMPPROPFILE
#echo -e "\n"fmw_components=\'"`paste -d, -s $HOME/fmw_components.txt`"\' >> $TECHPMPPROPFILE
echo -e "\n"fmw_components=`paste -d, -s $HOME/fmw_components.txt` >> $TECHPMPPROPFILE
rm $HOME/fmw_components.txt
}

fmw_common_patches_11g()
{
source $TECHPMPPROPFILE
for mw_home in $(echo ${mw_homes} | tr "," "\n")
do
if [[ -d $mw_home/oracle_common/OPatch ]]; then
	export ORACLE_HOME=$mw_home/oracle_common
	echo "| ************************************************************************************************************************"
	echo -e  "| ${CYAN}${BOLD}Below section is specific to default patches applicable for oracle_common [ $ORACLE_HOME ]" ${RESET}
	echo "| ************************************************************************************************************************"
	version_check=`$ORACLE_HOME/OPatch/opatch lsinventory | grep 'Oracle AS Common Toplevel Component' | awk -F" " '{print$NF}'`
	if [[ $version_check == 11.1.1.* ]]; then
	product=oracle_common
	multi_product_argumets_set
	opatch_list_11g
	fi
fi
done
#for oracle_home in $(echo ${oracle_homes} | tr "," "\n")
#do
#commonchk=`echo $oracle_home | grep oracle_common | wc -l`
#common_home=$oracle_home
#if [[ ( -d ${common_home} ) && ( -d ${common_home}/OPatch ) ]]; then
#	export ORACLE_HOME=$common_home
#	version_check=`$ORACLE_HOME/OPatch/opatch lsinventory | grep 'Oracle AS Common Toplevel Component' | awk -F" " '{print$NF}'`
#	if [[ $version_check == 11.1.1.* ]]; then
#	product=oracle_common
#	multi_product_argumets_set
#	opatch_list_11g
#	fi
#fi
#done
}

#fmw_products_check_11g()
#{
#source $TECHPMPPROPFILE
##touch $HOME/fmw_products.txt;file=fmw_products.txt
#for oracle_home in $(echo ${oracle_homes} | tr "," "\n")
#do
#soachk=`echo $oracle_home | grep soa | wc -l`
#osbchk=`echo $oracle_home | grep osb | wc -l`
#odichk=`echo $oracle_home | grep odi | wc -l`
#ohschk=`echo $oracle_home | grep ohs | wc -l`
#if [[ $soachk == 1 ]]; then
#	soa_home=$oracle_home
#	if [[ ( -d ${soa_home} ) && ( -d ${soa_home}/OPatch ) && ( -f ${soa_home}/bin/soaversion.sh ) ]]; then
#	export ORACLE_HOME=$soa_home
#	product_version=`$ORACLE_HOME/OPatch/opatch lsinventory | grep 'Oracle SOA Suite 11g' | awk -F" " '{print$NF}'`
#	product=soa
#	multi_product_argumets_set
#	opatch_list_11g
#	fi
#fi
#if [[ $osbchk == 1 ]]; then
#	osb_home=$oracle_home
#	if [[ ( -d ${osb_home} ) && ( -d ${osb_home}/OPatch ) ]]; then
#	export ORACLE_HOME=$osb_home
#	product_version=`$ORACLE_HOME/OPatch/opatch lsinventory | grep 'Oracle Service Bus' | awk -F" " '{print$NF}'`
#	product=osb
#	multi_product_argumets_set
#	opatch_list_11g
#	fi
#fi
#if [[ $odichk == 1 ]]; then
#	odi_home=$oracle_home
#	if [[ ( -d ${odi_home} ) && ( -d ${odi_home}/OPatch ) ]]; then
#	export ORACLE_HOME=$odi_home
#	product_version=`$ORACLE_HOME/OPatch/opatch lsinventory | grep 'Oracle Data Integrator 11g' | awk -F" " '{print$NF}'`
#	product=odi
#	multi_product_argumets_set
#	opatch_list_11g
#	fi
#fi
#done
#}

fmw_products_check_11g()
{
source $TECHPMPPROPFILE
touch $HOME/fmw_products.txt;file=fmw_products.txt
for mw_home in $(echo ${mw_homes} | tr "," "\n")
do
soa_homes='soa,soa_111,soa_112'
osb_homes='osb,osb_111,osb_112'
odi_homes='odi,odi_111,odi_112'
ohs_homes='ohs,ohs_111,ohs_112,ohs_1117'
wc_homes='wcc_111,wcc_112,wcp_111,wcp_112,ucm_111,ucm_112,wcs_111,wcs_112'
oud_homes='oud,oud_112,oud_111'
for soa_home in $(echo $soa_homes | tr "," "\n")
do
if [[ ( -d ${mw_home}/${soa_home} ) && ( -d ${mw_home}/${soa_home}/OPatch ) && ( -f ${mw_home}/${soa_home}/bin/soaversion.sh ) ]]; then
	export ORACLE_HOME=$mw_home/$soa_home
	product_version=`$ORACLE_HOME/OPatch/opatch lsinventory -invPtrLoc $ORACLE_HOME/oraInst.loc| grep 'Oracle SOA Suite 11g' | awk -F" " '{print$NF}'`
	product=soa
	multi_product_argumets_set
	opatch_list_11g
fi
done
for osb_home in $(echo $osb_homes | tr "," "\n")
do
if [[ ( -d $mw_home/$osb_home ) && ( -d ${mw_home}/${osb_home}/OPatch ) ]]; then
	export ORACLE_HOME=$mw_home/$osb_home
	product_version=`$ORACLE_HOME/OPatch/opatch lsinventory -invPtrLoc $ORACLE_HOME/oraInst.loc| grep 'Oracle Service Bus' | awk -F" " '{print$NF}'`
	product=osb
	multi_product_argumets_set
	opatch_list_11g
fi
done
for odi_home in $(echo $odi_homes | tr "," "\n")
do
if [[ ( -d $mw_home/$odi_home ) && ( -d ${mw_home}/${odi_home}/OPatch ) ]]; then
	export ORACLE_HOME=$mw_home/$odi_home
	product_version=`$ORACLE_HOME/OPatch/opatch lsinventory -invPtrLoc $ORACLE_HOME/oraInst.loc| grep 'Oracle Data Integrator 11g' | awk -F" " '{print$NF}'`
	product=odi
	multi_product_argumets_set
	opatch_list_11g
fi
done
for wc_home in $(echo $wc_homes | tr "," "\n")
do
if [[ ( -d ${mw_home}/${wc_home} ) && ( -d ${mw_home}/${wc_home}/OPatch ) ]]; then
	export ORACLE_HOME=$mw_home/$wc_home
	wcc_check=`grep '<EXT_NAME>' $ORACLE_HOME/inventory/ContentsXML/comps.xml|  grep 'Oracle WebCenter'| grep 'Oracle WebCenter Content - Universal Content Management' | wc -l`;if [[ ${wcc_check} -ge 1 ]]; then product=wcc;	product_version=`$ORACLE_HOME/OPatch/opatch lsinventory| grep -A5 "Top-level Products"| grep -B5 "products installed in this Oracle"| egrep -v "^$| products installed in this Oracle Home| Top-level Products"| awk -F" " '{print$NF}'`; opatch_list_11g;multi_product_argumets_set;fi;
	ipm_check=`grep '<EXT_NAME>' $ORACLE_HOME/inventory/ContentsXML/comps.xml|  grep 'Oracle WebCenter'| grep 'Oracle WebCenter Content: Imaging' | wc -l`;if [[ ${ipm_check} -ge 1 ]]; then product=ipm; product_version=`$ORACLE_HOME/OPatch/opatch lsinventory| grep -A5 "Top-level Products"| grep -B5 "products installed in this Oracle"| egrep -v "^$| products installed in this Oracle Home| Top-level Products"| awk -F" " '{print$NF}'`; opatch_list_11g;multi_product_argumets_set;fi;
	wcec_check=`grep '<EXT_NAME>' $ORACLE_HOME/inventory/ContentsXML/comps.xml|  grep 'Oracle WebCenter'| grep 'Oracle WebCenter Enterprise Capture' | wc -l`;if [[ ${wcec_check} -ge 1 ]]; then product=wcec; product_version=`$ORACLE_HOME/OPatch/opatch lsinventory| grep -A5 "Top-level Products"| grep -B5 "products installed in this Oracle"| egrep -v "^$| products installed in this Oracle Home| Top-level Products"| awk -F" " '{print$NF}'`; opatch_list_11g;multi_product_argumets_set;fi;
	#wcp_check=`$ORACLE_HOME/OPatch/opatch lsinventory -invPtrLoc $ORACLE_HOME/oraInst.loc| grep 'Oracle WebCenter Portal' | wc -l`;if [[ ${wcp_check} -ge 1 ]]; then product=wcp; product_version=`$ORACLE_HOME/OPatch/opatch lsinventory| grep -A5 "Top-level Products"| grep -B5 "products installed in this Oracle"| egrep -v "^$| products installed in this Oracle Home| Top-level Products"| awk -F" " '{print$NF}'`; multi_product_argumets_set; opatch_list_11g; fi;
	#wcs_check=`$ORACLE_HOME/OPatch/opatch lsinventory -invPtrLoc $ORACLE_HOME/oraInst.loc| grep 'Oracle WebCenter Sites' | wc -l`;if [[ ${wcs_check} -ge 1 ]]; then product=wcs; product_version=`$ORACLE_HOME/OPatch/opatch lsinventory| grep -A5 "Top-level Products"| grep -B5 "products installed in this Oracle"| egrep -v "^$| products installed in this Oracle Home| Top-level Products"| awk -F" " '{print$NF}'`; multi_product_argumets_set; opatch_list_11g; fi;
	wcp_check=`grep '<EXT_NAME>' $ORACLE_HOME/inventory/ContentsXML/comps.xml|  grep 'Oracle WebCenter'| grep 'Oracle WebCenter Portal' | wc -l`;if [[ ${wcp_check} -ge 1 ]]; then product=wcp; product_version=`$ORACLE_HOME/OPatch/opatch lsinventory| grep -A5 "Top-level Products"| grep -B5 "products installed in this Oracle"| egrep -v "^$| products installed in this Oracle Home| Top-level Products"| awk -F" " '{print$NF}'`; opatch_list_11g;multi_product_argumets_set;fi;
	wcs_check=`grep '<EXT_NAME>' $ORACLE_HOME/inventory/ContentsXML/comps.xml|  grep 'Oracle WebCenter'| grep 'Oracle WebCenter Sites' | wc -l`;if [[ ${wcs_check} -ge 1 ]]; then product=wcs; product_version=`$ORACLE_HOME/OPatch/opatch lsinventory| grep -A5 "Top-level Products"| grep -B5 "products installed in this Oracle"| egrep -v "^$| products installed in this Oracle Home| Top-level Products"| awk -F" " '{print$NF}'`; opatch_list_11g;multi_product_argumets_set;fi;
	#product_version=`$ORACLE_HOME/OPatch/opatch lsinventory -invPtrLoc $ORACLE_HOME/oraInst.loc| grep 'Oracle WebCenter Content Management' | awk -F" " '{print$NF}'`
fi
done
for oud_home in $(echo $oud_homes | tr "," "\n")
do
if [[ ( -d $mw_home/$oud_home ) && ( -d ${mw_home}/${oud_home}/OPatch ) ]]; then
	export ORACLE_HOME=$mw_home/$oud_home
	product_version=`$ORACLE_HOME/OPatch/opatch lsinventory -invPtrLoc $ORACLE_HOME/oraInst.loc| grep 'Oracle Unified Directory' | awk -F" " '{print$NF}'`
	product=oud
	multi_product_argumets_set
	opatch_list_11g
fi
done
#if [[ -d $mw_home/oracle_common/OPatch ]]; then
#	export ORACLE_HOME=$mw_home/oracle_common
#	version_check=`$ORACLE_HOME/OPatch/opatch lsinventory | grep 'Oracle AS Common Toplevel Component' | awk -F" " '{print$NF}'`
#	if [[ $version_check == 11.1.1.* ]]; then
#	product=oracle_common
#	multi_product_argumets_set
#	opatch_list_11g
#	fi
#fi
response_crt
done
}

fmw_products_check()
{
touch $HOME/fmw_products.txt;file=fmw_products.txt
if [[ ( ! -z $weblogic_version ) || ( ! -z $apache_version ) ]] && [[ ( $weblogic_version == 12.* ) || ( $apache_version == 12* ) ]];then
source $TECHPMPPROPFILE
unset _JAVA_OPTIONS
#$ORACLE_HOME/oui/bin/viewInventory.sh | egrep 'Distribution' | grep -v 'WebLogic Server' | awk -F":" ' {printf$2}' | sed 's/^/| /'
#$ORACLE_HOME/oui/bin/viewInventory.sh | egrep 'Distribution' | egrep -v 'WebLogic Server|OPatch' |sed -e "s/.*Distribution: //"|tr -s "\n" ","| sed 's/^/| /'
products_cnt=`$ORACLE_HOME/oui/bin/viewInventory.sh | egrep 'Distribution' | egrep -v 'WebLogic Server|OPatch' |sed -e "s/.*Distribution: //" | wc -l`
if [[ $products_cnt -ge 1 ]]; then
echo "| "
echo "| ****************************************************************"
echo -e "| ${CYAN} ${BOLD}FMW Products Installed on this Host $HOST:" ${RESET}
echo "| ****************************************************************"
$ORACLE_HOME/oui/bin/viewInventory.sh | egrep 'Distribution' | egrep -v 'WebLogic Server|OPatch' |sed -e "s/.*Distribution: //"| sed 's/^/| /'
echo -e "| " 
SOA=`$ORACLE_HOME/oui/bin/viewInventory.sh | grep Distribution | awk -F":" ' {printf$2}' | grep SOA | wc -l`
OSB=`$ORACLE_HOME/oui/bin/viewInventory.sh | grep Distribution | awk -F":" ' {printf$2}' | grep ServiceBus | wc -l`
OTD=`$ORACLE_HOME/oui/bin/viewInventory.sh | grep Distribution | awk -F":" ' {printf$2}' | grep 'Oracle Traffic Director' | wc -l`
ODI=`$ORACLE_HOME/oui/bin/viewInventory.sh | grep Distribution | awk -F":" ' {printf$2}' | grep 'Oracle Data Integrator' | wc -l`
WCC=`$ORACLE_HOME/oui/bin/viewInventory.sh | grep Distribution | awk -F":" ' {printf$2}' | grep 'WebCenterContent' | wc -l`
WCP=`$ORACLE_HOME/oui/bin/viewInventory.sh | grep Distribution | awk -F":" ' {printf$2}' | grep 'WebCenterPortal' | wc -l`
WCEC=`$ORACLE_HOME/oui/bin/viewInventory.sh | grep Distribution | awk -F":" ' {printf$2}' | grep 'WebCenterEnterpriseCapture' | wc -l`
WCS=`$ORACLE_HOME/oui/bin/viewInventory.sh | grep Distribution | awk -F":" ' {printf$2}' | grep 'WebCenterSites' | wc -l`
OID=`$ORACLE_HOME/oui/bin/viewInventory.sh | grep Distribution | awk -F":" ' {printf$2}' | grep 'Oracle Identity Directory' | wc -l`
OID=`$ORACLE_HOME/oui/bin/viewInventory.sh | grep Distribution | awk -F":" ' {printf$2}' | grep 'Oracle Unified Directory' | wc -l`
OVD=`$ORACLE_HOME/oui/bin/viewInventory.sh | grep Distribution | awk -F":" ' {printf$2}' | grep 'Oracle Virtual Directory' | wc -l`
IDM=`$ORACLE_HOME/oui/bin/viewInventory.sh | grep Distribution | awk -F":" ' {printf$2}' | grep 'Oracle Identity Management' | wc -l`
webgate=`$ORACLE_HOME/oui/bin/viewInventory.sh | grep webgate | grep -v otd | wc -l`
if [[ $SOA -ge 1 ]]; then
echo -e "| " 
product=soa
#product_version=`$ORACLE_HOME/soa/bin/soaversion.sh | grep 'Product Version' | awk -F":" ' {printf$2}' | awk -F"-" ' {printf$1}'`
product_version=$product_version
multi_product_argumets_set
fi
if [[ $OSB -ge 1 ]]; then
echo -e "| " 
product=osb
product_version=$product_version
multi_product_argumets_set
fi
if [[ $ODI -ge 1 ]]; then
echo -e "| " 
product=odi
product_version=$product_version
multi_product_argumets_set
fi
if [[ $WCP -ge 1 ]]; then
echo -e "| " 
product=wcp
product_version=$product_version
multi_product_argumets_set
fi
if [[ $WCC -ge 1 ]]; then
echo -e "| " 
product=wcc
product_version=$product_version
multi_product_argumets_set
fi
if [[ $WCEC -ge 1 ]]; then
echo -e "| " 
product=wcec
product_version=$product_version
multi_product_argumets_set
fi
if [[ $WCS -ge 1 ]]; then
echo -e "| " 
product=wcs
product_version=$product_version
multi_product_argumets_set
fi
if [[ $OID -ge 1 ]]; then
echo -e "| " 
product=oid
product_version=$product_version
multi_product_argumets_set
fi
if [[ $OUD -ge 1 ]]; then
echo -e "| " 
product=oud
product_version=$product_version
multi_product_argumets_set
fi
if [[ $OVD -ge 1 ]]; then
echo -e "| " 
product=ovd
product_version=$product_version
multi_product_argumets_set
fi
if [[ $IDM -ge 1 ]] && [[ $SOA -ge 1 ]]; then
echo -e "| " 
product=oim
product_version=$product_version
multi_product_argumets_set
fi
if [[ $IDM -ge 1 ]] && [[ $SOA -eq 0 ]]; then
echo -e "| " 
product=oam
product_version=$product_version
multi_product_argumets_set
fi
if [[ $webgate -ge 1 ]]; then
echo -e "| " 
product=oamwg
product_version=$product_version
multi_product_argumets_set
fi
if [[ ! -z $otd_home ]] || [[ $otd -ge 1 ]]; then
echo -e "| " 
product=otd
product_version=`$otd_domain_home/config/fmwconfig/components/OTD/instances/*/bin/startserv -version | grep 'Traffic Director' | grep -v grep | cut -d ' ' -f 4`
echo "| OTD Version : $product_version"
echo "| OTD Home : $otd_home"
echo "| OTD Domain : $otd_domain_home"
multi_product_argumets_set
fi
fi
else
echo "| "
echo "| ****************************************************************"
echo -e "| ${CYAN} ${BOLD}FMW Products Installed on this Host $HOST:" ${RESET}
echo "| ****************************************************************"
fmw_products_check_11g
fi
#echo -e "\n"fmw_products=\'"`cat $HOME/fmw_products.txt`"\' >> $TECHPMPPROPFILE
#echo -e "\n"fmw_products=\'"`paste -d, -s $HOME/fmw_products.txt`"\' >> $TECHPMPPROPFILE
echo -e "\n"fmw_products=`paste -d, -s $HOME/fmw_products.txt` >> $TECHPMPPROPFILE
rm $HOME/fmw_products.txt
}

response_crt()
{
if [[ ( $product_version == 11.1.1.* ) && ( ! -f $mw_home/ocm.rsp ) ]]; then
	echo "OCM Response File $mw_home/ocm.rsp is Missing, Creating it..."
	$CERTS_TOP/bin/.response_crt.sh $ORACLE_HOME > /dev/null
	if [[ -f $mw_home/ocm.rsp ]]; then
		echo -e "Response File Creation : ${GREEN}Success${RESET}"
	else
		echo -e "Response File Creation : ${RED}Failed${RESET}"
		fail_exit
	fi
fi
}

product_argumets_set()
{
if [[ -z $product_version ]]; then
echo -e "| ${RED}Not Able to Identify $product version. Please Make sure all variables set properly"${RESET}
send_mail FAIL
else
arguments_list=`cat ${CPU_PATCH_FILE} | grep ${product_version} | grep ${product}`
if [[ -z ${arguments_list} ]]; then
echo -e "| ${RED}Either $product $product_version is an De-Supported Version , Where No PSU patches being released by product Development."
echo -e "| or No Patches Released for your $product version $product_version."${RESET}
no_check=Y
else
product_name=`echo $arguments_list | awk -F" " ' {print $8} '`
product_version=`echo $arguments_list | awk -F" " ' {print $2} '`
psu_patch_ids=`echo -e $arguments_list | awk -F" " '{print $5}'`
psu_patch_release=`echo -e $arguments_list | awk -F" " '{print $3}'`
latest_release=`echo -e $arguments_list | awk -F" " '{print $4}'`
prereq_patch_ids=`echo -e $arguments_list | awk -F" " '{print $6}'`
mand_patch_ids=`echo -e $arguments_list | awk -F" " '{print $7}'`
conflict_patch_ids=`echo -e $arguments_list | awk -F" " '{print $9}'`
#echo product_name=$product_name
echo "" >> $TECHPMPPROPFILE
echo ${product_name}_version=$product_version >> $TECHPMPPROPFILE
product_short_ver=`echo ${product_version//[-._]/}`
echo ${product_name}_${product_short_ver}_home=$ORACLE_HOME >> $TECHPMPPROPFILE
echo ${product_name}_${product_short_ver}_psu_patch_id=${psu_patch_ids} >> $TECHPMPPROPFILE
echo ${product_name}_${product_short_ver}_prereq_patch_id=${prereq_patch_ids} >> $TECHPMPPROPFILE
echo ${product_name}_${product_short_ver}_mand_patch_id=${mand_patch_ids} >> $TECHPMPPROPFILE
echo ${product_name}_${product_short_ver}_conflict_id=${conflict_patch_ids} >> $TECHPMPPROPFILE
echo ${product_name}_${product_short_ver}_psu_patch_release=${psu_patch_release} >> $TECHPMPPROPFILE
echo ${product_name}_${product_short_ver}_latest_release="${latest_release}" >> $TECHPMPPROPFILE
#echo "|"
#echo patch_top=$patch_top
fi
fi
}

multi_product_argumets_set()
{
if [[ -z $product_version ]]; then
echo -e "| ${RED} Not Able to Identify $product version. Please Make sure all variables set properly" ${RESET}
send_mail FAIL
else
arguments_list=`cat ${CPU_PATCH_FILE} | grep ${product_version} | grep ${product}`
if [[ -z $arguments_list ]]; then
echo -e "| ${YELLOW}Either $product $product_version is an De-Supported Version , Where No PSU patches being released by product Development."
echo -e "| or No Patches Released for your $product version $product_version."${RESET}
no_check=Y
else
cat ${CPU_PATCH_FILE} | grep ${product_version} | grep ${product} | while read -r argument; do
product_name=`echo $argument | awk -F" " ' {print $8} '`
product_version=`echo $argument | awk -F" " ' {print $2} '`
psu_patch_ids=`echo -e $argument | awk -F" " '{print $5}'`
psu_patch_release=`echo -e $argument | awk -F" " '{print $3}'`
latest_release=`echo -e $argument | awk -F" " '{print $4}'`
prereq_patch_ids=`echo -e $argument | awk -F" " '{print $6}'`
mand_patch_ids=`echo -e $argument | awk -F" " '{print $7}'`
conflict_patch_ids=`echo -e $argument | awk -F" " '{print $9}'`
fmw_comp=($product_name)
echo "" >> $TECHPMPPROPFILE
echo ${product_name}_version=$product_version >> $TECHPMPPROPFILE
product_short_ver=`echo ${product_version//[-._]/}`
echo ${product_name}_${product_short_ver}_home=$ORACLE_HOME >> $TECHPMPPROPFILE
echo ${product_name}_${product_short_ver}_psu_patch_id=${psu_patch_ids} >> $TECHPMPPROPFILE
echo ${product_name}_${product_short_ver}_prereq_patch_id=${prereq_patch_ids} >> $TECHPMPPROPFILE
echo ${product_name}_${product_short_ver}_mand_patch_id=${mand_patch_ids} >> $TECHPMPPROPFILE
echo ${product_name}_${product_short_ver}_conflict_id=${conflict_patch_ids} >> $TECHPMPPROPFILE
echo ${product_name}_${product_short_ver}_psu_patch_release=${psu_patch_release} >> $TECHPMPPROPFILE
echo ${product_name}_${product_short_ver}_latest_release=${latest_release} >> $TECHPMPPROPFILE
echo ${fmw_comp} >> $HOME/$file
echo "|"
12c_psu_patch_check
done
fi
fi
}

osb_11_bp_chk()
{
bp_check=`$ORACLE_HOME/OPatch/opatch lsinventory -invPtrLoc $ORACLE_HOME/oraInst.loc | grep -i 20423630 | wc -l`
if [[ ${bp_check} -ge 1 ]]; then
product_version=11.1.1.7.4
fi
}

12c_psu_patch_check()
{
psu_patch_id=`echo $psu_patch_ids|cut -d "!" -f 1`
post_patch=`echo $psu_patch_ids|cut -d "!" -f 2`
opatch_cmd_chk=`$ORACLE_HOME/OPatch/opatch lsinventory -invPtrLoc $ORACLE_HOME/oraInst.loc | grep -i 'error code' | wc -l`
if [[ $opatch_cmd_chk -gt 0 ]]; then
  echo "OPatch Command Failed. Please make sure it works fine and rerun the script. "
  send_mail FAIL
fi
psu_check=`$ORACLE_HOME/OPatch/opatch lsinventory -invPtrLoc $ORACLE_HOME/oraInst.loc | grep -i ${psu_patch_id} | wc -l`
if [[ ${product_name} == OSB ]] && [[ ${product_version} == 11.1.1.7.0 ]]; then
osb_11_bp_chk
fi
if [[ $psu_check -ge 1 ]]; then
	echo "| For ${product_name} version ${product_version} Last CPU patch released was ${latest_release}"
	echo -e "| ${product_name} ${product_version}.${psu_patch_release} Patch ${psu_patch_id} ==> ${GREEN} Already Applied ${RESET}"
else
	echo "| For ${product_name} version ${product_version} Last CPU patch released was ${latest_release}"
	echo -e "| ${product_name} ${product_version}.${psu_patch_release} Patch ${psu_patch_id} ==> ${RED} Not Applied ${RESET}"
	echo ${psu_patch_id} >> $FINAL_PATCH_LIST
	post_patch_check
	if [[ ( ! -z ${prereq_patch_ids} ) && ( ${prereq_patch_ids} != None ) ]]; then
		for prereq_patch_id in $(echo ${prereq_patch_ids} | tr "," "\n")
		do
		psu_patch_id=`echo $prereq_patch_id|cut -d "!" -f 1`
		post_patch=`echo $prereq_patch_id|cut -d "!" -f 2`
		text=Pre-requisite
		mandatory_patch
		done
	fi
fi
if [[ ( ! -z ${mand_patch_ids} ) && ( ${mand_patch_ids} != None ) ]]; then
	for mand_patch_id in $(echo ${mand_patch_ids} | tr "," "\n")
	do
	psu_patch_id=`echo $mand_patch_id|cut -d "!" -f 1`
	post_patch=`echo $mand_patch_id|cut -d "!" -f 2`
	text=Mandatory
	mandatory_patch
	done
fi
}

mandatory_patch()
{
MAND_CHECK=`$ORACLE_HOME/OPatch/opatch lsinventory -invPtrLoc $ORACLE_HOME/oraInst.loc | egrep -i $psu_patch_id | wc -l`
if [[ $MAND_CHECK -ge 1 ]]; then
	echo -e "| ${text} Patch $psu_patch_id : ${GREEN} Already Applied ${RESET}"
else
	echo "|"
	echo -e "| ${text} Patch $psu_patch_id : ${RED} Not Applied ${RESET}"
	echo ${psu_patch_id} >> $FINAL_PATCH_LIST
	post_patch_check
fi
}

post_patch_check()
{
product_short_name=$( echo "$product_name" | tr  '[:upper:]' '[:lower:]' )
product_short_ver=`echo ${product_version//[-._]/}`
#patch_file="$(find $PMP_TOP/${product_short_name} -type f -iname p${psu_patch_id}*${product_short_ver}*.zip -execdir basename {} ';')"
patch_dir_check
#if [[ -d $CPU_PATCH_TOP/26318200 ]]; then
#	mv $CPU_PATCH_TOP/26318200 $CPU_PATCH_TOP/${psu_patch_id}
#fi
if [[ -d $CPU_PATCH_TOP/${psu_patch_id} ]]; then
patch_top=$CPU_PATCH_TOP/${psu_patch_id}
opatch_conflict_check
if [[ $post_patch == Y ]]; then
echo -e "| ${YELLOW}#########################################################"
echo -e "| Post Patch Steps for ${psu_patch_id}:"
echo -e "| #########################################################"
awk  '/Post-Installation/,/Deinstallation/' $CPU_PATCH_TOP/${psu_patch_id}/README.txt | grep -v Section | egrep -v 'Deinstallation|Post-Installation' | sed 's/^/| /'
echo -e "| ---------------------------------${RESET}"
elif [[ $post_patch == S ]]; then
echo -e "| ${YELLOW}#########################################################"
echo -e "| Special Instructions to be followed for ${psu_patch_id}:"
echo -e "| #########################################################"
awk "/${psu_patch_id}:Start/,/${psu_patch_id}:End/" $PMP_SCRIPT_TOP/bin/special_instructions.txt | egrep -v ${psu_patch_id} | sed 's/^/| /'
echo -e "| ---------------------------------${RESET}"
echo -e "|"
if [[ ${product_name} == OIM ]] && [[ -f $ORACLE_HOME/idm/server/bin/patch_oim_wls.profile ]]; then
	echo "| Taking backup of "patch_oim_wls.profile" File"
	now=$(date +"%m%d%Y")
	if [[ -f $ORACLE_HOME/idm/server/bin/patch_oim_wls.profile_${now} ]]; then
		echo -e "| patch_oim_wls.profile file backup ${GREEN}Already Exsists ${RESET}: [ $ORACLE_HOME/idm/server/bin/patch_oim_wls.profile_${now} ]"
	else
		cp $ORACLE_HOME/idm/server/bin/patch_oim_wls.profile $ORACLE_HOME/idm/server/bin/patch_oim_wls.profile_${now}
		if [[ -f $ORACLE_HOME/idm/server/bin/patch_oim_wls.profile_${now} ]]; then
			echo -e "| patch_oim_wls.profile file backup ${GREEN}Success ${RESET}: [ $ORACLE_HOME/idm/server/bin/patch_oim_wls.profile_${now} ]"
		else
			echo -e "| patch_oim_wls.profile file backup ${RED}Failed ${RESET}, Please take manual backup before we publish the action plan."
		fi
	fi
fi
echo -e "|"
elif [[ $post_patch == Z ]]; then
echo -e "| ${YELLOW}#########################################################"
echo -e "| Post Patch Steps for ${psu_patch_id}:"
echo -e "| #########################################################"
echo -e "| This Patch is having Complicated Post patch steps to be performed, \n| please review the readme manually and inlcude them in the Final Action Plan"
echo -e "| ---------------------------------${RESET}"
fi
fi
}

opatch_conflict_check()
{
#patch_req_chk=`$ORACLE_HOME/OPatch/opatch prereq CheckComponents -phBaseDir $patch_top -invPtrLoc $ORACLE_HOME/oraInst.loc | egrep 'ZOP-45|This patch is not needed|not needed since it has no fixes|component(s) that are not installed in OracleHome' | wc -l`
patch_req_chk=`$ORACLE_HOME/OPatch/opatch prereq CheckComponents -phBaseDir $patch_top -invPtrLoc $ORACLE_HOME/oraInst.loc|grep 'passed'|wc -l`
if [[ $patch_req_chk -ge 1 ]]; then
echo ${product_name}_${psu_patch_id}_apply=Y >> $TECHPMPPROPFILE
I=`$ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir $patch_top -invPtrLoc $ORACLE_HOME/oraInst.loc|grep 'passed'|wc -l`
S=`$ORACLE_HOME/OPatch/opatch prereq CheckConflictAmongPatchesWithDetail -phBaseDir $patch_top -invPtrLoc $ORACLE_HOME/oraInst.loc|grep 'passed'|wc -l`
if [ $I == 1 ] && [ $S == 1 ];then
	echo -e "| Patch Conflict Check : ${GREEN}Passed"${RESET}
else
	if [[ ( ! -z ${conflict_patch_ids} ) && ( ${conflict_patch_ids} != None ) ]]; then
		echo -e "| Patch Conflict Check : ${RED}Failed.Please validate manually and work with GPS if required." 
		echo "| "
		$ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir $patch_top -invPtrLoc $ORACLE_HOME/oraInst.loc > $CPU_PATCH_TOP/logs/${psu_patch_id}_conflicts.log
		awk '/Summary of Conflict Analysis/,/OPatch succeeded/' $CPU_PATCH_TOP/logs/${psu_patch_id}_conflicts.log | egrep -v 'succeeded|fail' | sed 's/^/| /'
		echo -e "| "${RESET}
		conflict_patch_ids_check=`echo $conflict_patch_ids | sed -e 's/,/\|/g'`
		known_con=`$ORACLE_HOME/OPatch/opatch lspatches | egrep \"${conflict_patch_ids_check}\"| wc -l`
		if [[ $known_con -ge 1 ]]; then
			echo -e "| ${YELLOW}Known Conflicts, Where the new patch is a Superset of conflict patch which will be rolled back during Exeuction"
			echo -e "| If we notice more conflicts than below listed, then please work with GPS to get a Merge Patch"${RESET}
			echo -e "| "
			$ORACLE_HOME/OPatch/opatch lspatches | egrep \"${conflict_patch_ids_check}\" | awk -F':' '{ print $1 }' | sed 's/^/| /'
		fi
	elif [[ ( -z ${conflict_patch_ids} ) || ( ${conflict_patch_ids} == None ) ]]; then
		echo -e "| Patch Conflict Check : ${RED}Failed.Please validate manually and work with GPS if required." 
		echo "| "
		$ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir $patch_top -invPtrLoc $ORACLE_HOME/oraInst.loc > $CPU_PATCH_TOP/logs/${psu_patch_id}_conflicts.log
		awk  '/Summary of Conflict Analysis/,/OPatch succeeded/' $CPU_PATCH_TOP/logs/${psu_patch_id}_conflicts.log | egrep -v 'succeeded|fail' | sed 's/^/| /'
		echo -e "| "${RESET}
	fi
fi
opatch_version_check
P=`$ORACLE_HOME/OPatch/opatch prereq CheckMinimumOPatchVersion -phBaseDir $patch_top -invPtrLoc $ORACLE_HOME/oraInst.loc|grep 'passed'|wc -l`
if [[ $P != 1 ]];then
	#opatch_version_check
	echo -e "|${RED} Minium Opatch Version Required : `$ORACLE_HOME/OPatch/opatch prereq CheckMinimumOPatchVersion -phBaseDir $patch_top -invPtrLoc $ORACLE_HOME/oraInst.loc|egrep -i 'requires OPatch version'`" ${RESET}
fi
else
echo -e "| ${YELLOW}This Patch is related to ${product_name} - ${product_version}, but not applicable on this $ORACLE_HOME as few required components are not installed to meet the patch"
echo -e "| So this patch is not needed since it has no fixes for this Oracle Home"${RESET}
echo ${product_name}_${psu_patch_id}_apply=N >> $TECHPMPPROPFILE
sed -i '/`echo $psu_patch_id`/d' $FINAL_PATCH_LIST
fi
}

######### OPATCH Latest Download #################
opatch_version_check()
{
now=$(date +"%m%d%Y")
oui_ver=`$ORACLE_HOME/OPatch/opatch lsinventory -invPtrLoc $ORACLE_HOME/oraInst.loc| grep -i 'OUI Version' | awk -F':' '{ print $2 }'`
opatch_ver=`$ORACLE_HOME/OPatch/opatch version -invPtrLoc $ORACLE_HOME/oraInst.loc| grep -i 'OPatch Version' | awk -F':' '{ print $2 }'`
#if [[ $opatch_ver == *13.9.2.0.0* ]] || [[ $oui_ver == *13.9.2.0.0* ]] || [[ $opatch_ver == *13.9.4.0.0* ]] || [[ $oui_ver == *13.9.4.0.0* ]]; then
if [[ $opatch_ver == *13.* ]] && [[ $opatch_ver != *13.9.4.2.0* ]] && [[ $product_version == 12.2.1.2.0 || $product_version == 12.2.1.3.0 ]]; then
	opatch_file=p28186730_139400_Generic.zip
	if [[ -f ${CPU_PATCH_TOP}/${opatch_file} ]] && [[ -d ${CPU_PATCH_TOP}/6880880 ]]; then
		echo -e "| Required Opatch version 13.9.4.2.0 patch 28186730 downloaded successfully : ${GREEN} $CPU_PATCH_TOP/6880880" ${RESET}
	elif [[ -f ${CPU_PATCH_TOP}/${opatch_file} ]] && [[ ! -d ${CPU_PATCH_TOP}/6880880 ]]; then
		#rm -rf 6880880
		cd ${CPU_PATCH_TOP}
		unzip ${CPU_PATCH_TOP}/${opatch_file} > /dev/null
		if [[ $? == 0 ]] && [[ -d ${CPU_PATCH_TOP}/6880880 ]]; then
			echo -e "| Required Opatch version 13.9.4.2.0 patch 28186730 downloaded successfully : ${GREEN}$CPU_PATCH_TOP/6880880"${RESET}
		else
			echo -e "| Required Opatch version 13.9.4.2.0 patch 28186730 downloaded successfully but Extracting failed : ${RED}$CPU_PATCH_TOP/$opatch_file"
			exit 1;
		fi
	elif [[ ! -f ${CPU_PATCH_TOP}/${opatch_file} ]]; then
		#echo "| Downloading required Opatch version 13.9.4.2.0 patch 28186730"
		opatch_download
		cd ${CPU_PATCH_TOP}
		unzip ${CPU_PATCH_TOP}/${opatch_file}> /dev/null
		if [[ $? != 0 ]] && [[ ! -d ${CPU_PATCH_TOP}/6880880 ]]; then
			echo -e "| Required Opatch version 13.9.4.2.0 patch 28186730 downloaded successfully but Extracting failed : ${RED}$CPU_PATCH_TOP/$opatch_file"${RESET}
			exit 1;
		fi
	fi
fi
if [[ *$oui_ver* == *$opatch_ver* ]];then
	opatch_ver=$opatch_ver
#elif [[ $oui_ver == '12.1.0.2.0' ]] || [[ $oui_ver == '12.2.0.1.0' ]] ; then
elif [[ $oui_ver == '12.1.0.*' ]] || [[ $oui_ver == '12.2.0.*' ]] ; then
	opatch_file=p6880880_122010_Linux-x86-64.zip
	opatch_download
	echo "Applying Latest OPatch Version"
	cd $ORACLE_HOME
	mv OPatch OPatch_${now}
	unzip ${CPU_PATCH_TOP}/$opatch_file
#elif [[ $oui_ver == '13.2.0.0.0' ]] || [[ $oui_ver == '13.1.0.0.0' ]] ; then
elif [[ $oui_ver == '13.2.0.*' ]] || [[ $oui_ver == '13.1.0.*' ]] ; then
	opatch_file=p6880880_132000_Generic.zip
	opatch_download
	echo "Applying Latest OPatch Version"
	cd $ORACLE_HOME
	mv OPatch OPatch_${now}
	unzip ${CPU_PATCH_TOP}/$opatch_file
#elif [[ $oui_ver == '11.2.0.0.0' ]] || [[ $oui_ver == '11.1.0.0.0' ]] ; then
elif [[ $oui_ver == '11.2.0.*' ]] || [[ $oui_ver == '11.1.0.*' ]] ; then
	opatch_file=p6880880_112000_Linux-x86-64.zip
	opatch_download
	echo "Applying Latest OPatch Version"
	cd $ORACLE_HOME
	mv OPatch OPatch_${now}
	unzip ${CPU_PATCH_TOP}/$opatch_file
#else
#echo "Not able to Capture OPatch Version. Make sure Pre-requisites are met"
fi
}

########## JDBC Drivers Checks #############################
wls_jdbc_driver_check()
{
#skip_check
if [[ $jdbc_skip -ne Y ]] || [[ -z $jdbc_skip ]]; then
echo "| "
echo "| Weblogic JDBC Drivers Validation:"
product=weblogic_jdbc
product_version=${weblogic_version}
ORACLE_HOME=`cd $WL_HOME/..;pwd`
product_argumets_set
if [[ ( $product_version == *10.3.6.0* ) || ( $product_version == *12.1.1.0* ) ]]; then
	psu_patch_id=`echo $psu_patch_ids|cut -d "!" -f 1`
	post_patch=`echo $psu_patch_ids|cut -d "!" -f 2`
	cd $WL_HOME/server/lib
	current_jdk_version=`java -jar ojdbc6.jar -getversion | head -n 1`
	echo -e "| Current JDBC driver version : $current_jdk_version"
	recommended_driver=12.1.2.1.0
	go=`echo $current_jdk_version | grep -i $recommended_driver | wc -l`
	if [[ $go == 1 ]]; then
		echo -e "| Weblogic server is having recommended version of jdbc drivers  : ${GREEN} $recommended_driver"${RESET}
	else
		echo -e "| Weblogic server is not having recommended version of jdbc drivers : ${RED} $recommended_driver"${RESET}
		echo -e "| Recommended JDBC Patch : ${psu_patch_id}"
		product_short_ver=121210
		OPATCH_TOP=$CPU_PATCH_TOP
		patch_dir_check
	fi
else
	echo "| JDBC Driver Patch(s):"
	for jdbc_patch in $(echo $psu_patch_ids | tr "," "\n")
	do
	psu_patch_id=`echo $jdbc_patch|cut -d "!" -f 1`
	post_patch=`echo $jdbc_patch|cut -d "!" -f 2`
	go=`$ORACLE_HOME/OPatch/opatch lsinventory -invPtrLoc $ORACLE_HOME/oraInst.loc | egrep -i $psu_patch_id | wc -l`
	if [[ $go -ge 1 ]]; then
		echo -e "| $psu_patch_id:${GREEN} Already Applied ${RESET}"		
	else
		echo -e "| $psu_patch_id:${RED} Not-Applied"${RESET}
		echo ${psu_patch_id} >> $FINAL_PATCH_LIST
		OPATCH_TOP=$CPU_PATCH_TOP		
		patch_dir_check
	fi
	done
fi
fi
}

############ JAVA Patches Check ##############
java_argumets_set()
{
if [[ -z $java_temp_version ]]; then
echo -e "| ${RED}Not Able to Identify $product version. Please Make sure all variables set properly"${RESET}
send_mail FAIL
else
arguments_list=`cat ${CPU_PATCH_FILE} | grep ${java_temp_version} | grep ${product}`
if [[ -z ${arguments_list} ]]; then
echo -e "| ${RED}Either $product $java_temp_version is an De-Supported Version , Where No PSU patches being released by product Development."
echo -e "| or No Patches Released for your $product version $java_temp_version."${RESET}
no_check=Y
else
product_name=`echo $arguments_list | awk -F" " ' {print $8} '`
java_version=`echo $arguments_list | awk -F" " ' {print $2} '`
psu_patch_id=`echo -e $arguments_list | awk -F" " '{print $5}'`
psu_patch_release=`echo -e $arguments_list | awk -F" " '{print $3}'`
latest_release=`echo -e $arguments_list | awk -F" " '{print $4}'`
java_patch_file=`echo -e $arguments_list | awk -F" " '{print $6}'`
java_install_file=`echo -e $arguments_list | awk -F" " '{print $7}'`
#echo product_name=$product_name
echo "" >> $TECHPMPPROPFILE
echo ${product_name}_version=$java_version >> $TECHPMPPROPFILE
product_short_ver=`echo ${java_version//[-._]/}`
echo ${product_name}_${product_short_ver}_home=$JAVA_HOME >> $TECHPMPPROPFILE
echo ${product_name}_${product_short_ver}_psu_patch_id=${psu_patch_id} >> $TECHPMPPROPFILE
echo ${product_name}_${product_short_ver}_patch_file=${java_patch_file} >> $TECHPMPPROPFILE
echo ${product_name}_${product_short_ver}_patch_install_file=${java_install_file} >> $TECHPMPPROPFILE
echo ${product_name}_${product_short_ver}_psu_patch_release=${psu_patch_release} >> $TECHPMPPROPFILE
echo ${product_name}_${product_short_ver}_latest_release="${latest_release}" >> $TECHPMPPROPFILE
#echo "|"
#echo patch_top=$patch_top
fi
fi
}

java_check() # JAVA HOME and Version Check
{
#skip_check
source $TECHPMPPROPFILE
if [[ $java_skip -ne Y ]] || [[ -z $java_skip ]]; then
JVS="${java_homes}"
for JV in $(echo $JVS | tr "," "\n")
do
JAVA_HOME=${JV}
java_jrockit=`$JAVA_HOME/bin/java -version 2>&1 | grep JRockit | wc -l`
java_jdk=`$JAVA_HOME/bin/java -version 2>&1 | grep HotSpot | wc -l`
product=java
if [[ $java_jrockit == 1 ]]; then
	current_java_version=`$JAVA_HOME/bin/java -version 2>&1 | head -n 1 | awk -F '"' '{print $2}'`
	echo "| "
	echo "| Java Version : $current_java_version"
	echo "| JAVA_HOME : $JAVA_HOME"
	java_temp_version=Jrockit_1_6_0
elif [[ $java_jdk == 1 ]]; then
	 unset _JAVA_OPTIONS
	current_java_version=`$JAVA_HOME/bin/java -version 2>&1 | head -n 1 | awk -F '"' '{print $2}'`
	echo "| "
	echo "| Java Version : $current_java_version"
	echo "| JAVA_HOME : $JAVA_HOME"
	#java_version=`$JAVA_HOME/bin/java -version 2>&1 | grep version | awk -F '"' '{print $2}'`
	if [[ $current_java_version == 1.6.* ]];then
	java_temp_version=Hotspot_1_6_0
	elif [[ $current_java_version == 1.7.* ]];then
	java_temp_version=Hotspot_1_7_0
	elif [[ $current_java_version == 1.8.* ]];then
	java_temp_version=Hotspot_1_8_0
	else
		echo -e "| ${RED} Not able capture current JAVA Version, Please verify whether JAVA_HOME was set or not. Quitting..." ${RESET}
		send_mail FAIL
	fi
else
	echo -e "| ${RED}Not able capture current JAVA Version, Please verify whether JAVA_HOME was set or not. Quitting..." ${RESET}
	send_mail FAIL
fi
	java_argumets_set
	if [[ $current_java_version == ${java_version} ]]; then
		echo -e "| ${product} Patch for ${latest_release} : ${psu_patch_id} - ${java_version} ==> ${GREEN} Already Applied ${RESET}"
	else
		echo -e "| ${product} Patch for ${latest_release} : ${psu_patch_id} - ${java_version} ==> ${RED} Not Applied ${RESET}"
		echo ${psu_patch_id} >> $FINAL_PATCH_LIST
		opatch_file=${java_patch_file}
		opatch_download
#		mkdir -p ${CPU_PATCH_TOP}/28414796
#		mv ${CPU_PATCH_TOP}/$opatch_file ${CPU_PATCH_TOP}/28414796
#		cd ${CPU_PATCH_TOP}/28414796
#		unzip $opatch_file > /dev/null
	fi
done
fi
}

######## OTM Patching Checks ################
otm_env_check()
{
pid_list_otm=($(ps -eo pid,cmd|grep java | grep "gc3"|grep -v grep|awk -F" " '{print $1}'))
pid_list_wl=($(ps -eo pid,cmd|grep "Dweblogic.Name="|grep -v grep|awk -F" " '{print $1}'))
pid_list_ohs=($(ps -eo pid,cmd| grep httpd | grep -v grep|awk -F" " '{print $1}'))
if [[ ${#pid_list_wl[@]} == 0 ]] && [[ ${#pid_list_ohs[@]} == 0 ]]; then
	echo -e "\t No 'otm' or 'Weblogic' or 'httpd' process currently running on host $HOST"
	send_mail FAIL
elif [[ ${#pid_list_otm[@]} != 0 ]] && [[ ${#pid_list_wl[@]} == 0 || ${#pid_list_wl[@]} != 0 ]]; then
	GLOG_ENV=`echo $GLOG_HOME`
	if [[ -z $GLOG_ENV ]];then
		echo "GLOG_HOME is not set on this Server. Please make sure we configured to call gc3env.sh in profile file. Quitting..."
		send_mail FAIL
	else
		otm_check
		otm_arguments_set
	fi	
fi
}

otm_check()
{
glog_prop=$GLOG_HOME/glog/config/glog.properties
glog_patch_prop=$GLOG_HOME/glog/config/glog.patches.properties
current_otm_version=`egrep -i 'glog.software.patch.version=' $glog_prop |grep -v '#'|cut -d '=' -f 2 `
if [[ $current_otm_version == OTMv6.2 ]]; then
grep weblogic $glog_patch_prop > /tmp/GLOG_PATCH_VER.txt
GLOG_PATCH_VERSION=`cat /tmp/GLOG_PATCH_VER.txt | tail -n1`
#echo Current OTM Patch Version = $GLOG_PATCH_VERSION
current_otm_version_621=`cat /tmp/GLOG_PATCH_VER.txt | tail -n1 | grep OTMv621- | wc -l`
current_otm_version_622=`cat /tmp/GLOG_PATCH_VER.txt | tail -n1 | grep OTMv622 | wc -l`
current_otm_version_623=`cat /tmp/GLOG_PATCH_VER.txt | tail -n1 | grep OTMv623 | wc -l`
current_otm_version_624=`cat /tmp/GLOG_PATCH_VER.txt | tail -n1 | grep OTMv624 | wc -l`
current_otm_version_625=`cat /tmp/GLOG_PATCH_VER.txt | tail -n1 | grep OTMv625 | wc -l`
current_otm_version_626=`cat /tmp/GLOG_PATCH_VER.txt | tail -n1 | grep OTMv626 | wc -l`
current_otm_version_627=`cat /tmp/GLOG_PATCH_VER.txt | tail -n1 | grep OTMv627 | wc -l`
current_otm_version_628=`cat /tmp/GLOG_PATCH_VER.txt | tail -n1 | grep OTMv628 | wc -l`
current_otm_version_629=`cat /tmp/GLOG_PATCH_VER.txt | tail -n1 | grep OTMv629 | wc -l`
current_otm_version_6210=`cat /tmp/GLOG_PATCH_VER.txt | tail -n1 | grep OTMv6210 | wc -l;`
	if [[ $current_otm_version_6210 == 1 ]]; then
		current_otm_version=OTMv6.2.10
		#elif [[ $current_otm_version_621 == 1  ]] || [[ $current_otm_version_622 == 1 ]] || [[ $current_otm_version_623 == 1 ]] || [[ $current_otm_version_624 == 1 ]] || [[ $current_otm_version_625 == 1 ]] || [[ $current_otm_version_626 == 1 ]] || [[ $current_otm_version_627 == 1 ]] || [[ $current_otm_version_628 == 1 ]] || [[ $current_otm_version_629 == 1 ]]; then
		#elif [[( $current_otm_version_621 == 1 ) || ( $current_otm_version_622 == 1 ) || ($current_otm_version_623 == 1 ) || ($current_otm_version_624 == 1 ) || ($current_otm_version_625 == 1 ) || ($current_otm_version_626 == 1 ) || ($current_otm_version_627 == 1 ) || ($current_otm_version_628 == 1 ) || ($current_otm_version_629 == 1 ) ]]; then
	else
		echo -e "${RED}We are on De-Supported Version of OTM, Either we need to upgrade to latest version(s) or"
		echo -e "Atleast to a version where the CPU patches being relased by OTM Development Team. " ${RESET}
	fi
elif [[ $current_otm_version == OTMv6.1 ]]; then
	echo -e "${RED}De-supported version(s) of OTM, Development team stopped releasing patche(s). Please recommend a upgrade to latest OTM version" ${RESET}
#else
#	echo "Not able to identify the OTM Version, Please verify whether GLOG_HOME is set or not"
#	send_mail FAIL
fi
}

otm_arguments_set()
{
arguments_list=`cat ${CPU_PATCH_FILE} | grep $current_otm_version | grep otm`
echo otm_version=`echo $arguments_list | awk -F" " ' {print $2} ' | tr -d . | sed 's/OTMv//g'` > $OTMPMPPROPFILE
echo cpu_patch_id=`echo -e $arguments_list | awk -F" " '{print $5}'` >> $OTMPMPPROPFILE
echo psu_patch_release=`echo -e $arguments_list | awk -F" " '{print $3}'` >> $OTMPMPPROPFILE
echo latest_release=`echo -e $arguments_list | awk -F" " '{print $4}'` >> $OTMPMPPROPFILE
echo bug_patch_id=`echo -e $arguments_list | awk -F" " '{print $6}'` >> $OTMPMPPROPFILE
echo mand_patch_id=`echo -e $arguments_list | awk -F" " '{print $7}'` >> $OTMPMPPROPFILE
source $OTMPMPPROPFILE
echo OTM_VERSION=$current_otm_version >> $OTMPMPPROPFILE
echo GLOG_HOME=$GLOG_HOME >> $OTMPMPPROPFILE
otm_cpu_patch_check
otm_mandatory_check
otm_cpu_bug_check
}

######### OTM CPU Patches Check ############
otm_cpu_patch_check()
{
source $OTMPMPPROPFILE
echo "| OTM Version = $OTM_VERSION"
echo "| GLOG_HOME= $GLOG_HOME"
echo "| "
echo "| ****************************************************************"
echo -e "| ${CYAN} ${BOLD} Verifying CPU Patches Applied so far on $HOST" ${RESET}
echo "| ****************************************************************"
echo "| "
cat $PMP_SCRIPT_TOP/bin/.${otm_version}_cpu.lst | while read line; do echo "| $line"; done
echo "| ***********************************************************************************************************************************************************"
echo -e "| ${CYAN} ${BOLD} Final List of OTM CPU Patches to be Installed (order-wise), which also includes Pre-requisite Patches and Post Patch Steps (if any)" ${RESET}
echo "| ***********************************************************************************************************************************************************"
echo "| OTM CPU Patches Checks: [ OTM Patches are not Cummulative, So we need to Apply all missing Patches ]"
echo "| "
if [[ ! -z ${cpu_patch_id} ]] || [[ ${cpu_patch_id} != None ]]; then
IN="${cpu_patch_id}"
for SET in $(echo $IN | tr "," "\n")
do
psu_patch_id=`echo $SET|cut -d "!" -f 1`
post_patch=`echo $SET|cut -d "!" -f 2`
CPU_PATCH=`grep -i ${psu_patch_id} $glog_patch_prop| wc -l`
if [[ $CPU_PATCH == 1 ]]; then
echo -e "| ${psu_patch_id} ==> ${GREEN} Already Applied ${RESET} "
else
    if [[ ${post_patch} == YA ]]; then
       	echo -e "| ${psu_patch_id}  ==> ${RED} Not Applied ${RESET}"
		echo ${psu_patch_id} >> $FINAL_PATCH_LIST
		otm_patch_dir_check
		echo "| POST PATCHING INSTRUCTIONS FOR ${psu_patch_id}:"
		echo "| cd $GLOG_HOME/glog/gc3webapp/WEB-INF/lib/3rdparty"
	    echo "| rm struts.jar"
	elif [[ ${post_patch} == YB ]]; then
    	echo -e "| ${psu_patch_id}  ==> ${RED} Not Applied ${RESET}"
 		echo ${psu_patch_id} >> $FINAL_PATCH_LIST
		otm_patch_dir_check
		echo "| POST PATCHING INSTRUCTIONS FOR ${psu_patch_id}:"
		echo "| cd $GLOG_HOME/tomcat/lib"
		echo "| rm ecj-3.7.jar ecj-4.2.2.jar"
	elif [[ ${post_patch} == YC ]]; then
		echo -e "| ${psu_patch_id}  ==> ${RED} Not Applied ${RESET}"
 		echo ${psu_patch_id} >> $FINAL_PATCH_LIST
		otm_patch_dir_check
		echo "| POST PATCHING INSTRUCTIONS FOR ${psu_patch_id}:"
		echo "| cd $GLOG_HOME/tomcat/lib"
		echo "| rm ecj-4.4.jar"
	elif [[ ${post_patch} == YD ]]; then
       	echo -e "| ${psu_patch_id}  ==> ${RED} Not Applied ${RESET}"
 		echo ${psu_patch_id} >> $FINAL_PATCH_LIST
		otm_patch_dir_check
		echo "| POST PATCHING INSTRUCTIONS FOR ${psu_patch_id}:"
		echo "| Edit the $GLOG_HOME/webserver/weblogic.conf file and add the following line before any other "classpath=" lines:"
		echo "| classpath=%GLOG_HOME%/glog/gc3webapp.ear/GC3.war/WEB-INF/lib/3rdparty/commons-fileupload-1.3.3.jar"
	elif [[ ${post_patch} == YE ]]; then
		echo -e "| ${psu_patch_id}  ==> ${RED} Not Applied ${RESET}"
 		echo ${psu_patch_id} >> $FINAL_PATCH_LIST
		otm_patch_dir_check
		echo "| POST PATCHING INSTRUCTIONS FOR ${psu_patch_id}:"
		echo "| Edit the $GLOG_HOME/webserver/weblogic.conf file and add the following line before any other "classpath=" lines:"
		echo "| classpath=%GLOG_HOME%/glog/gc3webapp.ear/APP-INF/lib/3rdparty/commons-fileupload-1.3.3.jar"
	elif [[ ${post_patch} == YF ]]; then
		echo -e "| ${psu_patch_id}  ==> ${RED} Not Applied ${RESET}"
 		echo ${psu_patch_id} >> $FINAL_PATCH_LIST
		otm_patch_dir_check
		echo "| POST PATCHING INSTRUCTIONS FOR ${psu_patch_id}:"
		echo "| Delete the file $GLOG_HOME/glog/gc3webapp.ear/GC3.war/WEB-INF/lib/3rdparty/ridc/log4j-1.2.17.jar"
	elif [[ ${post_patch} == YG ]]; then
       	echo -e "| ${psu_patch_id}  ==> ${RED} Not Applied ${RESET}"
 		echo ${psu_patch_id} >> $FINAL_PATCH_LIST
		otm_patch_dir_check
		echo "| POST PATCHING INSTRUCTIONS FOR ${psu_patch_id}:"
		echo "| Delete the file $GLOG_HOME/glog/gc3webapp/WEB-INF/lib/3rdparty/ridc/log4j-1.2.17.jar"
	elif [[ ${post_patch} == YH ]]; then
		echo -e "| ${psu_patch_id}  ==> ${RED} Not Applied ${RESET}"
 		echo ${psu_patch_id} >> $FINAL_PATCH_LIST
		otm_patch_dir_check
		echo "| POST PATCHING INSTRUCTIONS FOR ${psu_patch_id}:"
		echo "| Delete the file $GLOG_HOME/glog/gc3webapp.ear/GC3.war/WEB-INF/lib/3rdparty/ridc/log4j-1.2.17.jar"
	elif [[ ${post_patch} == YI ]]; then
		echo -e "| ${psu_patch_id}  ==> ${RED} Not Applied ${RESET}"
 		echo ${psu_patch_id} >> $FINAL_PATCH_LIST
		otm_patch_dir_check
		echo "| POST PATCHING INSTRUCTIONS FOR ${psu_patch_id}:"
		echo "| Delete the following directories:"
		echo "| $GLOG_HOME/glog/gc3webapp/WEB-INF/lib/3rdparty/bpel"
		echo "| $GLOG_HOME/glog/gc3webapp/WEB-INF/lib/3rdparty/bpel_10.1.3"
		echo "| "
		echo "| Also  after installing on the application server run the following:"
		echo "| cd $GLOG_HOME/glog/oracle/script8"
		echo "| sqlplus /nolog @run_patch.sql"
	elif [[ ${post_patch} == YJ ]]; then
       	echo -e "| ${psu_patch_id}  ==> ${RED} Not Applied ${RESET}"
 		echo ${psu_patch_id} >> $FINAL_PATCH_LIST
		otm_patch_dir_check
		echo "| POST PATCHING INSTRUCTIONS FOR ${psu_patch_id}:"
		echo "| Delete the following directories:"
		echo "| $GLOG_HOME/glog/gc3webapp.ear/GC3.war/WEB-INF/lib/3rdparty/bpel"
		echo "| $GLOG_HOME/glog/gc3webapp.ear/GC3.war/WEB-INF/lib/3rdparty/bpel_10.1.3"
		echo "| "
		echo "| Also  after installing on the application server run the following:"
		echo "| cd $GLOG_HOME/glog/oracle/script8"
		echo "| sqlplus /nolog @run_patch.sql"
	elif [[ ${post_patch} == Y ]]; then
		echo -e "| ${psu_patch_id}  ==> ${RED} Not Applied ${RESET}"
 		echo ${psu_patch_id} >> $FINAL_PATCH_LIST
		otm_patch_dir_check
		echo "| POST PATCHING INSTRUCTIONS FOR ${psu_patch_id}:"
		echo "| cd $GLOG_HOME/glog/oracle/script8"
		echo "| sqlplus /nolog @run_patch.sql"
	else
		echo -e "| ${psu_patch_id}  ==> ${RED} Not Applied ${RESET}"
 		echo ${psu_patch_id} >> $FINAL_PATCH_LIST
		otm_patch_dir_check	
	fi
fi
done
fi
}

######### OTM Mandatory Patches Check ############
otm_mandatory_check()
{
source $OTMPMPPROPFILE
echo "| *************************************************************************"
echo -e "| ${CYAN} ${BOLD}Verifying Mandatory Patches Applied so far on $HOST" ${RESET}
echo "| *************************************************************************"
echo "| "
echo "| OTM Mandatory Patches listed as per Doc id : 1081306.1 [This check is only applicable starting from OTM6210, For older version please validate manually]"
echo "| "
if [[ -z $mand_patch_id ]] || [[ $mand_patch_id == None ]]; then
echo "| No Mandatory Patches for this version"
else
echo "| ****************************************************************************************************************************************"
echo -e "| ${CYAN} ${BOLD} Below is the final List of Mandatory Patches to be Installed in the same sequence, which also includes Pre-requisite Patches and Post Patch Steps (if any)" ${RESET}
echo "| ****************************************************************************************************************************************"
echo "| "
IN="${mand_patch_id}"
for SET in $(echo $IN | tr "," "\n")
do
psu_patch_id=`echo $SET|cut -d "!" -f 1`
post_patch=`echo $SET|cut -d "!" -f 2`
CPU_PATCH=`grep -i ${psu_patch_id} $glog_patch_prop| wc -l`
if [[ $CPU_PATCH == 1 ]]; then
echo -e "| ${psu_patch_id} ==> ${GREEN} Already Applied ${RESET} "
else
    if [[ ${post_patch} == YA ]]; then
		echo -e "| ${psu_patch_id}  ==> ${RED} Not Applied ${RESET} "
 		echo ${psu_patch_id} >> $FINAL_PATCH_LIST
		otm_patch_dir_check
		echo "| POST PATCHING INSTRUCTIONS FOR ${psu_patch_id}:"
		echo "| cd $GLOG_HOME/glog/oracle/script8"
		echo "| ./run_patch.sh"
	elif [[ ${post_patch} == Y ]]; then
		echo -e "| ${psu_patch_id}  ==> ${RED} Not Applied ${RESET} "
 		echo ${psu_patch_id} >> $FINAL_PATCH_LIST
		otm_patch_dir_check
		echo "| POST PATCHING INSTRUCTIONS FOR ${psu_patch_id}:"
		echo "| cd $GLOG_HOME/glog/oracle/script8"
		echo "| sqlplus /nolog @run_patch.sql"
    else
		echo -e "| ${psu_patch_id}  ==> ${RED} Not Applied ${RESET} "
 		echo ${psu_patch_id} >> $FINAL_PATCH_LIST
		otm_patch_dir_check
    fi
fi
done
fi
}

######### OTM Known Bug Patches Check on top of CPU Patching ############
otm_cpu_bug_check()
{
source $OTMPMPPROPFILE
echo "| ************************************************************************************************************************************"
echo -e "| ${CYAN} ${BOLD} OTM CPU Post Bug fix Patches: [ These patches for the issues reported by customer after applying CPU patches ] (if any)" ${RESET}
echo "| ************************************************************************************************************************************"
echo "| "
if [[ -z $bug_patch_id ]] || [[ $bug_patch_id == None ]]; then
	echo -e "| ${YELLOW} ${BOLD} No Bugs Reported so far for this version after CPU Patching" ${RESET}
	echo "| "
	echo "| ************************************************************************************************************************************"
else
IN="${bug_patch_id}"
for SET in $(echo $IN | tr "," "\n")
do
psu_patch_id=`echo $SET|cut -d "!" -f 1`
post_patch=`echo $SET|cut -d "!" -f 2`
CPU_PATCH=`grep -i ${psu_patch_id} $glog_patch_prop| wc -l`
if [[ $CPU_PATCH == 1 ]]; then
echo -e "| ${psu_patch_id} ==> ${GREEN} Already Applied ${RESET} "
else
    if [[ ${post_patch} == Y ]]; then
		echo -e "| ${psu_patch_id} ==> ${RED} Not Applied ${RESET} "
 		echo ${psu_patch_id} >> $FINAL_PATCH_LIST
		otm_patch_dir_check
		echo "| POST PATCHING INSTRUCTIONS FOR ${psu_patch_id}:"
		echo "| cd $GLOG_HOME/glog/oracle/script8"
		echo "| sqlplus /nolog @run_patch.sql"
    else
		echo -e "| ${psu_patch_id} ==> ${RED} Not Applied ${RESET} "
 		echo ${psu_patch_id} >> $FINAL_PATCH_LIST
		otm_patch_dir_check
    fi
fi
done
echo "| ************************************************************************************************************************************"
fi
}

######### MDO CPU Patches Check ############
mdo_env_check() # MDO Instance Planning Checks 
{
. $HOME/.config.variables
ADMIN_HOST=`echo ${PL_MASTER_HOST}`
if [[ $ADMIN_HOST == '' ]]; then
	echo -e "${RED}Environment Variables are not set, please make sure we configured to call .config.variables in profile file. Quitting..."${RESET}
	send_mail FAIL
else
echo "exit" | sqlplus -L $CDW_LOGIN | grep Connected > /dev/null
if [ $? == 0 ];then
MDO_VERSION=$(sqlplus -s $CDW_LOGIN <<EOF
set feedback off
set pagesize 0
select * from CDW_VERSION;
EOF
)
echo "| RETAIL-MDO Version : ${MDO_VERSION}"
echo "| "
else
	echo -e "${RED}Environment Variables are not set properly. Quitting..." ${RESET}
	send_mail FAIL
fi
fi
}

######### RETAIL CPU Patches Check ############
retail_check() # RETAIL Instance Planning Checks 
{
echo "| Products Installed on $HOST:"
if [ -d $HOME/retail_home/orpatch/config/javaapp_rms ]; then
	echo "| Prodcut Name : RETAIL-RMS"
	cd $HOME/retail_home/orpatch/config/javaapp_rms
	APP_NAME=`grep input.app.name ant.deploy.properties|cut -d"=" -f 2`
	APP_VERSION=`grep -i "${APP_NAME}.version=" ant.deploy.properties |cut -d"=" -f 2|awk '!seen[$0]++'`
	echo "| RETAIL-RMS Version : $APP_VERSION"
fi
if [ -d $HOME/rms/orpatch/config/javaapp_rms ]; then
	echo "| Prodcut Name : RETAIL-RMS"
	cd $HOME/rms/orpatch/config/javaapp_rms
	APP_NAME=`grep input.app.name ant.deploy.properties|cut -d"=" -f 2`
	APP_VERSION=`grep -i "${APP_NAME}.version=" ant.deploy.properties |cut -d"=" -f 2|awk '!seen[$0]++'`
	echo "| RETAIL-RMS Version : $APP_VERSION"
fi
if [ -d $HOME/retail_home/orpatch/config/javaapp_alloc ]; then
	echo "| Prodcut Name : RETAIL-ALLOC"
	cd $HOME/retail_home/orpatch/config/javaapp_alloc
	APP_NAME=`grep input.app.name ant.deploy.properties|cut -d"=" -f 2`
	APP_VERSION=`egrep "alc.version=" ant.deploy.properties |cut -d"=" -f 2|awk '!seen[$0]++'`
	echo "| RETAIL-ALLOC Version : $APP_VERSION"
fi
if [ -d $HOME/alloc/orpatch/config/javaapp_alloc ]; then
	echo "| Prodcut Name : RETAIL-ALLOC"
	cd $HOME/alloc/orpatch/config/javaapp_alloc
	APP_NAME=`grep input.app.name ant.deploy.properties|cut -d"=" -f 2`
	APP_VERSION=`egrep "alc.version=" ant.deploy.properties |cut -d"=" -f 2|awk '!seen[$0]++'`
	echo "| RETAIL-ALLOC Version : $APP_VERSION"
fi
if [ -d $HOME/retail_home/orpatch/config/javaapp_resa ]; then
	echo "| Prodcut Name : RETAIL-RESA"
	cd $HOME/retail_home/orpatch/config/javaapp_resa
	APP_NAME=`grep input.app.name ant.deploy.properties|cut -d"=" -f 2`
	APP_VERSION_MAJ=`egrep -i "${APP_NAME}.version=|resa.version.major=" ant.deploy.properties |cut -d"=" -f 2|awk '!seen[$0]++'`
	APP_VERSION_MNR=`egrep -i "${APP_NAME}.version=|resa.version.minor=" ant.deploy.properties |cut -d"=" -f 2|awk '!seen[$0]++'`
	APP_VERSION_PNT=`egrep -i "${APP_NAME}.version=|resa.version.point=" ant.deploy.properties |cut -d"=" -f 2|awk '!seen[$0]++'`
	echo "| RETAIL-RESA Version : ${APP_VERSION_MAJ}.${APP_VERSION_MNR}.${APP_VERSION_PNT}"
fi
if [ -d $HOME/resa/orpatch/config/javaapp_resa ]; then
	echo "| Prodcut Name : RETAIL-RESA"
	cd $HOME/resa/orpatch/config/javaapp_resa
	APP_NAME=`grep input.app.name ant.deploy.properties|cut -d"=" -f 2`
	APP_VERSION_MAJ=`egrep -i "${APP_NAME}.version=|resa.version.major=" ant.deploy.properties |cut -d"=" -f 2|awk '!seen[$0]++'`
	APP_VERSION_MNR=`egrep -i "${APP_NAME}.version=|resa.version.minor=" ant.deploy.properties |cut -d"=" -f 2|awk '!seen[$0]++'`
	APP_VERSION_PNT=`egrep -i "${APP_NAME}.version=|resa.version.point=" ant.deploy.properties |cut -d"=" -f 2|awk '!seen[$0]++'`
	echo "| RETAIL-RESA Version : ${APP_VERSION_MAJ}.${APP_VERSION_MNR}.${APP_VERSION_PNT}"
fi
if [ -d $HOME/retail_home/orpatch/config/javaapp_rpm ]; then
	echo "| Prodcut Name : RETAIL-RPM"
	cd $HOME/retail_home/orpatch/config/javaapp_rpm
	APP_NAME=`grep input.app.name ant.deploy.properties|cut -d"=" -f 2`
	APP_VERSION_MAJ=`egrep -i "${APP_NAME}.version=|rpm.version.major=" ant.deploy.properties |cut -d"=" -f 2|awk '!seen[$0]++'`
	APP_VERSION_MNR=`egrep -i "${APP_NAME}.version=|rpm.version.minor=" ant.deploy.properties |cut -d"=" -f 2|awk '!seen[$0]++'`
	APP_VERSION_PNT=`egrep -i "${APP_NAME}.version=|rpm.version.point=" ant.deploy.properties |cut -d"=" -f 2|awk '!seen[$0]++'`
	echo "| RETAIL-RPM Version : ${APP_VERSION_MAJ}.${APP_VERSION_MNR}.${APP_VERSION_PNT}"
fi
if [ -d $HOME/rpm/orpatch/config/javaapp_rpm ]; then
	echo "| Prodcut Name : RETAIL-RPM"
	cd $HOME/rpm/orpatch/config/javaapp_rpm
	APP_NAME=`grep input.app.name ant.deploy.properties|cut -d"=" -f 2`
	APP_VERSION_MAJ=`egrep -i "${APP_NAME}.version=|rpm.version.major=" ant.deploy.properties |cut -d"=" -f 2|awk '!seen[$0]++'`
	APP_VERSION_MNR=`egrep -i "${APP_NAME}.version=|rpm.version.minor=" ant.deploy.properties |cut -d"=" -f 2|awk '!seen[$0]++'`
	APP_VERSION_PNT=`egrep -i "${APP_NAME}.version=|rpm.version.point=" ant.deploy.properties |cut -d"=" -f 2|awk '!seen[$0]++'`
	echo "| RETAIL-RPM Version : ${APP_VERSION_MAJ}.${APP_VERSION_MNR}.${APP_VERSION_PNT}"
fi
if [ -d $HOME/retail_home/orpatch/config/javaapp_reim ]; then
	echo "| Prodcut Name : RETAIL-REIM"
	cd $HOME/retail_home/orpatch/config/javaapp_reim
	APP_NAME=`grep input.app.name ant.deploy.properties|cut -d"=" -f 2`
	APP_VERSION_MAJ=`egrep -i "${APP_NAME}.version=|reim.version.major=" ant.deploy.properties |cut -d"=" -f 2|awk '!seen[$0]++'`
	APP_VERSION_MNR=`egrep -i "${APP_NAME}.version=|reim.version.minor=" ant.deploy.properties |cut -d"=" -f 2|awk '!seen[$0]++'`
	APP_VERSION_PNT=`egrep -i "${APP_NAME}.version=|reim.version.point=" ant.deploy.properties |cut -d"=" -f 2|awk '!seen[$0]++'`
	echo "| RETAIL-REIM Version : ${APP_VERSION_MAJ}.${APP_VERSION_MNR}.${APP_VERSION_PNT}"
fi
if [ -d $HOME/reim/orpatch/config/javaapp_reim ]; then
	echo "| Prodcut Name : RETAIL-REIM"
	cd $HOME/reim/orpatch/config/javaapp_reim
	APP_NAME=`grep input.app.name ant.deploy.properties|cut -d"=" -f 2`
	APP_VERSION_MAJ=`egrep -i "${APP_NAME}.version=|reim.version.major=" ant.deploy.properties |cut -d"=" -f 2|awk '!seen[$0]++'`
	APP_VERSION_MNR=`egrep -i "${APP_NAME}.version=|reim.version.minor=" ant.deploy.properties |cut -d"=" -f 2|awk '!seen[$0]++'`
	APP_VERSION_PNT=`egrep -i "${APP_NAME}.version=|reim.version.point=" ant.deploy.properties |cut -d"=" -f 2|awk '!seen[$0]++'`
	echo "| RETAIL-REIM Version : ${APP_VERSION_MAJ}.${APP_VERSION_MNR}.${APP_VERSION_PNT}"
fi
SIM_DM=`ps -ef | grep -v grep |grep -i Ddomain.home|grep -o "Ddomain.home.*"|cut -d " " -f 1|cut -d"=" -f 2 | grep -i SIM | sort -u| wc -l`
if [[ $SIM_DM == 1 ]]; then
	echo "| Prodcut Name : RETAIL-SIM"
	SIM_DOMAIN=`ps -ef | grep -v grep |grep -i Ddomain.home|grep -o "Ddomain.home.*"|cut -d " " -f 1|cut -d"=" -f 2 | grep -i SIM | sort -u`
	cd $SIM_DOMAIN/retail/sim*/wireless/resources/conf
	APP_VERSION_MAJ=`egrep -i 'sim.version.major=' version.properties |cut -d"=" -f 2|awk '!seen[$0]++'`
	APP_VERSION_MNR=`egrep -i 'sim.version.minor=' version.properties |cut -d"=" -f 2|awk '!seen[$0]++'`
	APP_VERSION_PNT=`egrep -i 'sim.version.point=' version.properties |cut -d"=" -f 2|awk '!seen[$0]++'`
	echo "| RETAIL-SIM Version : ${APP_VERSION_MAJ}.${APP_VERSION_MNR}.${APP_VERSION_PNT}"
fi
echo "| "
#MDOMAIN=`ps -ef | grep -v grep |grep -i Dweblogic.Name|grep -o "Dweblogic.Name.*"|cut -d " " -f 1|cut -d"=" -f 2 | grep -v AdminServer| wc -l`
MDOMAIN=`ps -ef | grep -v grep |grep -i Dweblogic.Name|grep -o "Dweblogic.Name.*"|cut -d " " -f 1|cut -d"=" -f 2 | wc -l`
if [[ $MDOMAIN -gt 0 ]]; then
echo "| List of Admin and Managed Servers Configured on $HOST:"
#MANAGED=`ps -ef | grep -v grep |grep -i Dweblogic.Name|grep -o "Dweblogic.Name.*"|cut -d " " -f 1|cut -d"=" -f 2 | grep -v AdminServer`
MANAGED=`ps -ef | grep -v grep |grep -i Dweblogic.Name|grep -o "Dweblogic.Name.*"|cut -d " " -f 1|cut -d"=" -f 2`
echo wls_servers=`echo $MANAGED | tr ' ' ','` >> $TECHPMPPROPFILE
echo '|'$MANAGED | tr ' ' ','
echo "|"
fi
}

# Set CODE_TOP functions
. $PMP_SCRIPT_TOP/bin/.capturefunction
. $PMP_SCRIPT_TOP/bin/.patchfunction

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

send_mail()
{
today=`date +"%Y%m%d"`
WHOTOPAGE=rakesh.tatineni@oracle.com,retail_automation_in_grp@oracle.com
#WHOTOPAGE=rakesh.tatineni@oracle.com
OUT_EXE_DIR=$CPU_PATCH_TOP/logs/pmp/planning
OUT_EXE_FILE=$OUT_EXE_DIR/APP_PMP_Planning_${today}_${HOST}.log
OUT_EXE_FILE_MAIL=$OUT_EXE_DIR/APP_PMP_Planning_${today}_${HOST}_mail.log
#sed -r 's/'$(echo -e "\033")'\[[0-9]{1,2}(;([0-9]{1,2})?)?[mK]//g' $OUT_EXE_FILE > $OUT_EXE_FILE_MAIL
sed -r 's~\x01?(\x1B\(B)?\x1B\[([0-9;]*)?[JKmsu]\x02?~~g' $OUT_EXE_FILE > $OUT_EXE_FILE_MAIL
if [[ -f $OTMPMPPROPFILE ]]; then
post_script=`egrep -i 'run_patch.sql|run_patch.sh' $OUT_EXE_FILE_MAIL | wc -l`
if [[ $post_script -ge 1 ]]; then
echo "run_patch_sql=Y" >> $OTMPMPPROPFILE
else
echo "run_patch_sql=N" >> $OTMPMPPROPFILE
fi
fi
get_user_name
STATUS=$1
if [[ $STATUS == FAIL ]]; then
#message_body="$scriptname invoked by $user_id on $HOST"
#echo "$message_body" |/bin/mail -s "Application PMP Planning for $release_month on $HOST" -a $OUT_EXE_FILE_MAIL ${WHOTOPAGE}
/bin/mail -s "Application PMP Planning for $release_month on $HOST Failed : Invoked by $user_id" ${WHOTOPAGE} < $OUT_EXE_FILE_MAIL
echo "Planning Failed"
exit 1;
elif [[ $STATUS == SUCCESS ]]; then
#message_body="$scriptname invoked by $user_id on $HOST"
#echo "$message_body" |/bin/mail -s "Application PMP Planning for $release_month on $HOST" -a $OUT_EXE_FILE_MAIL ${WHOTOPAGE}
/bin/mail -s "Application PMP Planning for $release_month on $HOST Succeeded : Invoked by $user_id" ${WHOTOPAGE} < $OUT_EXE_FILE_MAIL
echo "Planning Completed"
exit 0;
fi
}

show_usage() # Prints basic help information.
{
echo -e "\n Usage:"
echo -e "   ${0##*/} -m <Arg1> -p <Arg2> -i <Arg3> -s <Arg4>"
echo -e "   Arg1 : CPU Release Month in MMMYYYY Format [Required]"
echo -e "   Arg2 : Product Name for which we need to perform the Planning [Required]"
echo -e "                       FMW : To Perform CPU Patching Plan for FMW Instances"
echo -e "                       OTM : To Perform CPU Patching Plan for OTM Instances"
echo -e "                       MDO : To Perform CPU Patching Plan for MDO Instances"
echo -e "                       RETAIL : To Perform CPU Patching Plan for RETAIL Instances"
echo -e "                       DMZ : To Perform CPU Patching Plan for DMZ Instances"
echo -e "   Arg4 : [Optional]"
echo -e "   Option 1: If we want to wants java patching then use value as 'java'"
echo -e "   Option 2: If we want to wants weblogic jdbc drivers patching then use value as 'jdbc'"
echo -e "   Option 3: If we want to wants both java and weblogic jdbc drivers patching then use value as 'java,jdbc'"
echo -e "\n Example:"
echo -e "   ./${0##*/} -m apr2019 -p fmw\n"
echo -e "   ./${0##*/} -m apr2019 -p fmw -s java\n"
echo -e "   ./${0##*/} -m apr2019 -p fmw -s jdbc\n"
echo -e "   ./${0##*/} -m apr2019 -p fmw -s java,jdbc\n"
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

optstring="m:p:i:s:h"
while getopts "$optstring" opt; do
  case "$opt" in
    m)    release_month=$( echo "$OPTARG" | tr  '[:upper:]' '[:lower:]' )
	        case $release_month in
        jan2019|apr2019);;
        *)  psu_release;;
        esac;;
    p)    PRODUCT=$( echo "$OPTARG" | tr  '[:lower:]' '[:upper:]' )
        case $PRODUCT in
        FMW|OTM|RETAIL|DMZ|MDO|FTI);;
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

if [[ -z $release_month ]] || [[ -z $PRODUCT ]]; then
	echo " PSU release and Product Name are mandatory aruguments you can't skip"
	show_usage
else
if [[ -f $PMP_SCRIPT_TOP/bin/.fmw_cpu_patches_${release_month}.lst ]]; then
CPU_PATCH_FILE=$PMP_SCRIPT_TOP/bin/.fmw_cpu_patches_${release_month}.lst
else
echo "Automation Code is not up-to-date, please make sure we have latest code with all required files and retry the Planning Job"
fi
fi

product_check


