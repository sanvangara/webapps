#!/bin/bash
# **********************************************************************************************************
# * Filename            :       one_command_pmp_apply.sh
# * Author              :       Rakesh Tatineni
# * Original            :       06/05/2019
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
#PSU_MONTH=$( echo "$1" | tr  '[:lower:]' '[:upper:]' )
#apply_mode=$( echo "$2" | tr  '[:upper:]' '[:lower:]' )

TECHPMPPROPFILE="$HOME/.fmwpmp.env"
OTMPMPPROPFILE="$HOME/.otmpmp.env"

HOST=`cat /etc/passwd| grep compute|cut -f2 -d"@"`
if [[ -z $HOST ]]; then
HOST=`cat /etc/passwd| grep oracleoutsourcing|cut -f2 -d"@"`
if [[ -z $HOST ]]; then
HOST=`hostname`
fi
fi
today=`date +"%Y%m%d"`
LOG_DIR=$HOME/cpu_patches/logs/pmp/execution

main()
{
mkdir -p $LOG_DIR
if [[ $? == 1 ]]; then
        echo "LOG Directory creation failed. Please make sure we have all privileges under $HOME/cpu_patches"
        exit 1;
fi
OUT_FILE=$LOG_DIR/APP_PMP_Execution_${today}_${HOST}.log
if [ -f $OUT_FILE ]; then
        rm $OUT_FILE
fi
apply_go
}

apply_go()
{
if [[ ! -z ${apply_mode} ]]; then
if [[ ( -z ${include} ) && ( -z ${skip} ) ]]; then
$SCRIPT_TOP/bin/one_command_pmp_apply_auto.sh -m ${psu_month} -a ${apply_mode}| tee -a $OUT_FILE
elif [[ ( -z ${include} ) && ( ! -z ${skip} ) ]]; then
$SCRIPT_TOP/bin/one_command_pmp_apply_auto.sh -m ${psu_month} -a ${apply_mode} -s ${skip}| tee -a $OUT_FILE
elif [[ ( ! -z ${include} ) && ( -z ${skip} ) ]]; then
$SCRIPT_TOP/bin/one_command_pmp_apply_auto.sh -m ${psu_month} -a ${apply_mode} -i ${include}| tee -a $OUT_FILE
elif [[ ( ! -z ${include} ) && ( ! -z ${skip} ) ]]; then
$SCRIPT_TOP/bin/one_command_pmp_apply_auto.sh -m ${psu_month} -a ${apply_mode} -i ${include} -s ${skip}| tee -a $OUT_FILE
fi
elif [[ -z ${apply_mode} ]]; then
if [[ ( -z ${include} ) && ( -z ${skip} ) ]]; then
$SCRIPT_TOP/bin/one_command_pmp_apply_auto.sh -m ${psu_month}| tee -a $OUT_FILE
elif [[ ( -z ${include} ) && ( ! -z ${skip} ) ]]; then
$SCRIPT_TOP/bin/one_command_pmp_apply_auto.sh -m ${psu_month} -s ${skip}| tee -a $OUT_FILE
elif [[ ( ! -z ${include} ) && ( -z ${skip} ) ]]; then
$SCRIPT_TOP/bin/one_command_pmp_apply_auto.sh -m ${psu_month} -i ${include}| tee -a $OUT_FILE
elif [[ ( ! -z ${include} ) && ( ! -z ${skip} ) ]]; then
$SCRIPT_TOP/bin/one_command_pmp_apply_auto.sh -m ${psu_month} -i ${include} -s ${skip}| tee -a $OUT_FILE
fi
fi
send_mail
}

psu_release()
{
echo "This Script is developed to use starting from JAN-2019, Provide one CPU release date out of these."
echo "Else Your Input is wrong/incorrect format, please use MMMYYYY format (eg:APR2017).Quitting..."
exit 1;
}

send_mail()
{
GO=`grep 'Execution Completed' $OUT_FILE|wc -l`
NOGO=`grep 'Execution Failed' $OUT_FILE|wc -l`
if [[ $GO == 1 ]]; then
exit 0;
elif [[ $NOGO == 1 ]]; then
exit 1;
#else
#echo "Execution Failed with Some Warnings, Please check and correct"
#exit 1;
fi
}

show_usage() # Prints basic help information.
{
echo -e "\n Usage:"
echo -e "   ${0##*/} -m <Arg1> -a <Arg2> -i <Arg3> -s <Arg4>"
echo -e "   Arg1 : CPU Release Month in MMMYYYY Format [Required]"
echo -e "\n Example:"
echo -e "   ./${0##*/} -m apr2019\n"
echo -e "   Arg2 : Execution Type auto or manual [Optional]"
echo -e "               For OTM:"
echo -e "                       auto : When no post-patch scripts required to run manually by keeping the script execution on pause."
echo -e "                       manual : When we have to run few post-patch scripts by keeping the script execution on pause, mainly on primary app node."
echo -e " "
echo -e "               For FMW/MDO/RETAIL/DMZ : We can use default value as 'auto' or Ignore"
echo -e "\n Example:"
echo -e "   ./${0##*/} -m apr2019 -a auto/manual\n"
echo -e "   Arg3 : [Optional]"
echo -e "   Option : If we want just apply cpu patches for 'java and/or jdbc and/or weblogic and/or ohs' then,"
echo -e "   We can use all kind of combinations above 4 components to apply."
echo -e "\n Example:"
echo -e "   ./${0##*/} -m apr2019 -a auto/manual -i java/jdbc/ohs/wls"
echo -e "   ./${0##*/} -m apr2019 -a auto/manual -i java,jdbc"
echo -e "   ./${0##*/} -m apr2019 -a auto/manual -i ohs,wls"
echo -e "   ./${0##*/} -m apr2019 -a auto/manual -i java,wls,ohs"
echo -e "   "
echo -e "   Arg4 : [Optional]"
echo -e "   Option : Even after successful planning, if we want skip cpu patches for 'java and/or jdbc and/or weblogic and/or ohs' then,"
echo -e "   We can use all kind of combinations above 4 components to skip."
echo -e "\n Example:"
echo -e "   ./${0##*/} -m apr2019 -a auto/manual -s java/jdbc/ohs/wls"
echo -e "   ./${0##*/} -m apr2019 -a auto/manual -s java,jdbc"
echo -e "   ./${0##*/} -m apr2019 -a auto/manual -s ohs,wls"
echo -e "   ./${0##*/} -m apr2019 -a auto/manual -s java,wls,ohs"
echo -e "   If we wants to skip Weblogic, then automatically jdbc will be part of it."
echo -e " "
echo -e " Note: We can even user combination of include '-i' and skip '-s' in single command"
echo -e " If we want to perform Planning for Weblogic , but to skip jdbc then"
echo -e "\n Example:"
echo -e " ./${0##*/} -m apr2019 -a auto/manual -i java,wls,ohs -s jdbc"
echo -e " "
echo -e "\n Support:"
echo -e "   Email retail_automation_in_grp@oracle.com to report issues or defects.\n"
exit 1;
}

# Main:
script_parameters="$@"

optstring="m:a:i:s:h"
while getopts "$optstring" opt; do
  case "$opt" in
    m)    psu_month=$( echo "$OPTARG" | tr  '[:upper:]' '[:lower:]' )
	        case $psu_month in
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

if [[ -z $psu_month ]]; then
	echo " PSU release is a mandatory arugument you can't skip"
	show_usage
fi

main

