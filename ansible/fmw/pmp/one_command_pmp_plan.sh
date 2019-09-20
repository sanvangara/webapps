#!/bin/bash
# **********************************************************************************************************
# * Filename            :       one_command_pmp_plan.sh
# * Author              :       Rakesh Tatineni
# * Original            :       01/05/2019
# **********************************************************************************************************
if [ `whoami` = "root" ]; then
echo "${red}You Loged in as root user"
echo "Must be logged on as Application User to run this script.${reset}"
exit 1;
fi

#MY_SID=${USER:2}; echo "MY_SID=$MY_SID"
#BASENM=`basename $0 .sh`
# Set environment
if [ $SHELL = "/bin/bash" ]; then
   source ~/.bash_profile >/dev/null
else
   source ~/.profile >/dev/null
fi

SCRIPT_TOP=/usr/local/MAS/fmw/pmp
#psu_month=$( echo "$1" | tr  '[:lower:]' '[:upper:]' )
#prod_name=$( echo "$2" | tr  '[:lower:]' '[:upper:]' )
CPU_PATCH_TOP=$HOME/cpu_patches
#HOST=`hostname`
HOST=`cat /etc/passwd| grep compute|cut -f2 -d"@"`
if [[ -z $HOST ]]; then
HOST=`cat /etc/passwd| grep oracleoutsourcing|cut -f2 -d"@"`
if [[ -z $HOST ]]; then
HOST=`hostname`
fi
fi
today=`date +"%Y%m%d"`
LOG_DIR=$CPU_PATCH_TOP/logs/pmp/planning

main()
{
mkdir -p $LOG_DIR
if [[ $? == 1 ]]; then
        echo "LOG Directory creation failed. Please make sure we have all privileges under $CPU_PATCH_TOP"
        exit 1;
fi
OUT_FILE=$LOG_DIR/APP_PMP_Planning_${today}_${HOST}.log
if [ -f $OUT_FILE ]; then
        rm $OUT_FILE
fi
plan_go
}

plan_go()
{
if [[ ( -z ${include} ) && ( -z ${skip} ) ]]; then
$SCRIPT_TOP/bin/one_command_pmp_plan_auto.sh -m ${psu_month} -p ${PRODUCT}| tee -a $OUT_FILE
elif [[ ( -z ${include} ) && ( ! -z ${skip} ) ]]; then
$SCRIPT_TOP/bin/one_command_pmp_plan_auto.sh -m ${psu_month} -p ${PRODUCT} -s ${skip}| tee -a $OUT_FILE
elif [[ ( ! -z ${include} ) && ( -z ${skip} ) ]]; then
$SCRIPT_TOP/bin/one_command_pmp_plan_auto.sh -m ${psu_month} -p ${PRODUCT} -i ${include}| tee -a $OUT_FILE
elif [[ ( ! -z ${include} ) && ( ! -z ${skip} ) ]]; then
$SCRIPT_TOP/bin/one_command_pmp_plan_auto.sh -m ${psu_month} -p ${PRODUCT} -i ${include} -s ${skip}| tee -a $OUT_FILE
fi
send_mail
}

psu_release()
{
echo "This Script is developed to start using from JAN-2019, Provide one CPU release date out of these."
echo "Else Your Input is wrong/incorrect format, please use MMMYYYY format (eg:APR2017).Quitting..."
exit 1;
}

send_mail()
{
GO=`grep 'Planning Completed' $OUT_FILE|wc -l`
NOGO=`grep 'Planning Failed' $OUT_FILE|wc -l`
if [[ $GO == 1 ]]; then
        exit 0;
elif [[ $NOGO == 1 ]]; then
        exit 1;
#else
#echo "Planning Failed with Some Warnings, Please check and correct"
#exit 1;
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
echo -e "\n Example:"
echo -e "   ./${0##*/} -m apr2019 -p fmw"
echo -e "   "
echo -e "   Arg3 : [Optional]"
echo -e "   Option : If we want just perform cpu planning for 'java and/or jdbc and/or weblogic and/or ohs' then,"
echo -e "   We can use all kind of combinations for above 4 components to do the planning."
echo -e "\n Example:"
echo -e "   ./${0##*/} -m apr2019 -p fmw -i java/jdbc/ohs/wls"
echo -e "   ./${0##*/} -m apr2019 -p fmw -i java,jdbc"
echo -e "   ./${0##*/} -m apr2019 -p fmw -i java,wls"
echo -e "   ./${0##*/} -m apr2019 -p fmw -i java,wls,ohs"
echo -e "   "
echo -e "   Arg4 : [Optional]"
echo -e "   Option : If we want skip cpu planning for 'java and/or jdbc and/or weblogic and/or ohs' then,"
echo -e "   We can use all kind of combinations above 4 components to skip."
echo -e "\n Example:"
echo -e "   ./${0##*/} -m apr2019 -p fmw -s java/jdbc/ohs/wls"
echo -e "   ./${0##*/} -m apr2019 -p fmw -s java,jdbc"
echo -e "   ./${0##*/} -m apr2019 -p fmw -s ohs,wls"
echo -e "   ./${0##*/} -m apr2019 -p fmw -s java,wls,ohs"
echo -e "   If we wants to skip Weblogic, then automatically jdbc will be part of it."
echo -e " "
echo -e " Note: We can even user combination of include '-i' and skip '-s' in single command"
echo -e " If we want to perform Planning for Weblogic , but to skip jdbc then"
echo -e "\n Example:"
echo -e " ./${0##*/} -m apr2019 -p fmw -i java,wls,ohs -s jdbc"
echo -e " "
echo -e "\n Support:"
echo -e "   Email retail_automation_in_grp@oracle.com to report issues or defects.\n"
exit 1;
}

# Main:
script_parameters="$@"

optstring="m:p:i:s:h"
while getopts "$optstring" opt; do
  case "$opt" in
    m)    psu_month=$( echo "$OPTARG" | tr  '[:upper:]' '[:lower:]' )
	        case $psu_month in
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

if [[ -z $psu_month ]] || [[ -z $PRODUCT ]]; then
	echo " PSU release and Product Name are mandatory aruguments you can't skip"
	show_usage
fi

main

