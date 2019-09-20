#!/bin/ksh
# $Header: opatch.sh.UNIX 115.321 2019/03/14 eloland ship $
# *===========================================================================+
# |  Copyright (c) 1996 Oracle Corporation, Redwood Shores, California, USA   |
# |                        All rights reserved                                |
# |                      Applications  Division                               |
# +===========================================================================+
# |
# | FILENAME
# |   opatch.sh
# |
# | DESCRIPTION
# |   Auto-patch script for use with adpatch in non-interactive mode.
# |   Will unzip and apply standard applications patches.
# |   Improves adpatch log handling by grouping together all log files related
# |   to the same patch session in a log directory named after patch number
# |   and language. 
# |	  Log directory will be in $APPL_TOP/admin/<SID>/log/<patchnumber_LANG>
# |	  The autopatch script will handle US as well as NLS patches.
# |	  Autopatch also checks whether patch has already been applied.
# |	  Improved restart functionality: If a patch fails, restart files will
# |	  be backed up (including FND_INSTALL_PROCESSES table), enabling user
# |	  to apply another patch (to fix the issue ?). It will then be possible
# |	  to reapply the failed patch from the point where it failed.
# |	  Restart files will be backed up in the patch log directory.
# |
# |   Prerequisites for using:
# |   1. Make sure that the applmgr environment has been sourced (APPSORA.env)
# |   2. If patch directory is different from $APPL_TOP/patch, an environment
# |	   variable needs to be set:
# |	   export OPATCH_TOP=<full path to base patch directory>;
# |	   This variable should be set in .profile or adovars.env
# |   3. For full usage, AD patch 1899014 (or later) should be applied. The
# |	   patch will load all patch information into the database, obsoleting
# |	   the applptch.txt.
# |
# | USAGE
# |   opatch.sh [-a|-c|-d|-r|-info|-tarinfo] <patchnumber> [-drv copy|database|generate] 
#               [-force] [-langcode] [-tar] [-s] [-h] [-merge]
# |   E.x.:   opatch.sh -a 1899014
# |   If the patch, for some reason, fails during patch run, fix the issue
# |   (if possible) and rerun the opatch.sh script.
# |   When running opatch.sh after a failed patch, you will be prompted
# |   to run it in 'interactive' mode.
# |   Following options can be specified:
# |   -a    Apply patch non-interactively using adpatch in non-interactive mode
# |   -c    Check if a given patch has been applied or not.
# |   -d    Download patch. Requires available FTP connection to 'updates.oracle.com'
# |   -r    Read-only mode, enables users to display and read the patch readme files
# |   -merge    Merge mode. Used for merging comma separated list of patches	
# |   -options Comma separated list of adpatch options (ex. -options norevcache,noprereq)
# |   -drop Drop previous patch session, including FND_INST. table and restart files
# |   -info Check patch information. Timing info, and TAR numbers for patch run
# |   -drv	For applying single driver only. Following drivers can be specified:
# |	   	copy)     Copy driver
# |	   	database) Database driver only
# |	   	generate) Generate driver only
# |	   	unified)  Unified driver
# |   -force Used for force applying a patch that has already been applied
# |   -langcode If you only want to apply a particular language patch (only for MLS env).
# |   -tar  For giving SR/RFC number on command line.
# |   -s    Silent mode.
# |   -h    Will display USAGE section for opatch.sh
# |
# | PLATFORM
# |   Unix Generic
# |
# | NOTES
# |
# |
# | HISTORY
# |	17-05-2002: First offical version of opatch.sh
# |	23-05-2002: Added 'Connection timeout' as ftp status.
# |	28-05-2002: Enabled check option to check for all languages in one run
# |	29-05-2002: Fixed minor bugs
# |	30-05-2002: Created unique temp log directory for each session.
# |	            Ensured that HP-UX error message on uname -X is disabled
# |	            Used export/import of FND_INSTALL_PROCESSES instead of
# |	            create/drop on tables.
# |	04-06-2002: Changed 'tr [] []' to use typeset instead.
# |	07-06-2002: New GetOptions
# |	            Changed typeset back to 'tr' due to 'local' variable
# |	10-06-2002: If previous patch failed, don't display readme files.
# |	            New option <tar> shows TAR number(s) for previously applied
# |	            patches (if any).
# |	11-06-2002: Improved move_patch_dir routine, also checks for read/write
# |	            Improved check to include all patch applications
# |	            Changed display of patch check list
# |	            Trap of cntrl-c changed to exit default on return
# |	12-06-2002: Added TimeCheck function for easier display of patch time
# |	            Changed import/export function to be 'silent'
# |	13-06-2002: New TimeCalc function
# |	            Added help information for -time option
# |	            Fixed bug in patchlang list creation
# |	            Refined display of error messages for ftp status
# |	            Implemented blinking running status
# |	14-06-2002: More changes to ftp_status, simplified process
# |	15-06-2002: New file, PatchInfo.log to replace TAR file and PatchTime
# |	16-06-2002: Changed check_patch_applied to only look for correct
# |	            tier information (WEB, NODE, FORMS, ADMIN).
# |	17-06-2002: New calculation method, using dc
# |	            New message for 'no ftp connection' for download option
# |	18-06-2002: Minor bugfix
# |	20-06-2002: Changed calculation of patch_size/disk_size to use 'dc'
# |	21-06-2002: Added another (HP) method for getting numCPU.
# |	21-06-2002: Improved error handling for grep of missing files.
# |	27-06-2002: Fewer questions asked if previous patch failed.
# |	            Minor 'no file found message' fixes
# |	28-06-2002: New GetOptions
# |	04-07-2002: Fixed issue, where start/end time not provided to TimeCalc
# |	            Fixed issue with logdir not created before -h option
# |	10-07-2002: Added no response required to get_response
# |	11-07-2002: Removed check for defaults.txt Seemingly unecessary
# |	            Enabled opatch.sh to create onlinedef.txt if missing
# |	            Minor changes.
# |	15-07-2002: Fixed unzip, so that opatch.sh can be run from anywhere
# |	18-07-2002: Added option -drop, for dropping previous patch session
# |	20-07-2002: Fixed errors in check_restart_mode, drop
# |	            Added more bug-finding information when checking patch
# |	07-08-2002: Fixed 1100 problem when checking patchzip file
# |	            Changed patchdir naming convention (removing '_')
# |	08-08-2002: Ensured that 'extra' check of patch applied did only
# |	            occur on the database node.
# |	10-08-2002: Minor changes. Also added start time for opatch
# |	13-08-2002: Ask for TAR number unconditionally if using -drop
# |	14-08-2002: Minor changes
# |	15-08-2002: Moved TAR query to after 'apply-patch yes/no' question
# |	            Silent mode now skips readme files. Applies patch without
# |	            any user intervention (except metalink username/password).
# |	25-08-2002: Not able to use grep -w on some platforms. Made workaround
# |	            Made som further improvements on patchdir naming
# |	25-09-2002: Removed break lines from set_platform function
# |	            Made changes for LINUX. Pipe equals new subprocess
# |	26-09-2002: Added new TimeCalc function
# |	02-10-2002: Fixed errors introduced when using new Linux syntax
# |	26-10-2002: Fixed errors in display_readme when 10 or more readme's
# |	08-11-2002: Changed output format of patch application data.
# |	12-11-2002: Added check for unzip utility
# |	29-11-2002: Added check for valid driver files in patch directory
# |	21-01-2003:	Added display of invalid objects (Robin Harris developed)
# |	30-01-2003:	Added check for maximum number of connections on database
# |	11-02-2003: Added support for redhat LINUX (ncftp)
# |	14-02-2003: Fixed error in TimeCalc when adding times
# |	20-02-2003: Improved display of html pages by using LYNX
# |	25-02-2003: Fixed error in ftp_files for LINUX
# |	26-02-2003: Finally fixed the ftp issue
# |	08-04-2003: Check on whether PTS is installed on a given instance
# |	            this is done by checking the variable PTS_BASE...
# |	            new option: IgnorePTS - if needed opatch.sh can
# |	            be used on a PTS installed instance
# |	24-04-2003: Added option 'restart=yes' to adpatch command line.
# |	            This will make sure adpatch does not exit when error occurs
# |	12-06-2003: Redefined def.txt to be onlinedef.txt
# |	            Made LINUX changes for check_zipfile routine
# |	07-07-2003: Added support for new logfile format (AD.H) for timing
# |	08-07-2003: Fixed error in new logfile format
# |	18-08-2003: Changed restart mode to yes and interactive mode to no for
# |	            failed patches. This should enable adpatch to run
# |	            non-interactive even for failed patches.
# |	24-08-2003: Added -options for using adpatch options
# |	04-09-2003: Implemented generic xxonline_dk metalink account
# |	10-09-2003: Allowed co-existence of applptch.txt and AD tables
# |	            Fixed AIX bug in free_disk
# |	11-09-2003: Fixed error in -info (NLS info was not displayed)
# |	12-09-2003: Fixed AIX bug in TimeCalc
# |	19-09-2003: Fixed AIX in free_disk
# |	            Enabled multiple language download for NLS/MLS
# |	20-09-2003: Refined MLS.
# |	            Added new option -force to enable reapplying patch
# |	27-09-2003: Added AIX specific cpu count
# |	30-09-2003: Added uncompress/tar for patch directories
# |	05-10-2003: Disabled exit when ftp access not available
# |	21-10-2003: New function, get_free_disk replaces free_disk
# |	22-10-2003: Minor change in options. -force and -drop can not take param
# |	24-10-2003: Fixed errors in 'which <executable>' statements
# |	14-11-2003: Added export/import of AD_DEFERRED_JOBS table
# |	16-12-2003: Removed a 't' in ending of script
# |	02-02-2004: Added a few more options for the unified driver
# |	06-02-2004: Changed a few things in regards to check_patch_applied drv
# |	17-02-2004: More options for unified driver
# |	22-02-2004: Added new option -workers for setting another number than def
# |	23-02-2004: Fixed bug in 'workers' option
# |	19-04-2004: Fixed 'bug' in reuse of logfiles
# |	04-05-2004: Added running_statement function
# |	14-05-2004: Added format_statement
# |	24-05-2004: Added formatting to 'create_dir' function
# |	            Changed batch size to be 10000 instead of 1000
# |	25-05-2004: Added option 'langcode' for force applying single language
# |	27-05-2004: Changed silent mode to ensure driver check is completed
# |	29-05-2004: Improved silent mode for unavailable patch
# |	30-05-2004: Changed patch info to look the same as when applied
# |	            Changed revcache limit from 30 to 100 pls/pkb/pkh
# |	18-06-2004: Added flags=hidepw and changed buffers to 100000
# |	24-06-2004: Changed default apply/download answer to Y for option=force
# |	10-08-2004: Added another cpu count for linux
# |	13-09-2004: Multiple display changes
# |	17-09-2004: Enabled correct echo for linux
# |	18-09-2004: Changed opatch to always use <patchnum>_<lang> as base dir
# |	26-09-2004: Made patch dir/zip checking mechanism more streamlined for MLS
# |	01-11-2004: Added check for new apsv text file (applptch.txt)
# |	03-11-2004: Enabled option for 'validate'
# |	            Added option -tarinfo for displaying patch statistics for tar
# |	17-11-2004: Added option -localworkers for distributed ad
# |	18-11-2004: Added list of incompleted jobs from db (when using -info)
# |	01-12-2004: Changed tarnumber to be more generic (JZiegler)
# |	09-12-2004: Performance improvement
# |	17-12-2004: Created opatch.sh logfile to track opatch.sh itself
# |	            Also made some fixes and changes
# |	19-12-2004: Implemented maintenance mode feature for AD.I and above
# |	            Also new option -hotpatch
# |	16-01-2005: Added option -noconnect for downloading patches with no db cn.
# |	            Added option -noninteractive for applying patch noninteractive
# |	28-01-2005: Corrected languages to be displayed properly for NLS
# |	02-02-2005: Had to limit HP-UX downloads to only be HPUX11 (apps)
# |	04-02-2005: Included options=validate when creating defaultsfile 
# |	11-02-2005: Added new implicit option wait_on_failed_job for 
# |	            noninteractive mode. Not implemented yet (only for AD.I)
# |	16-02-2005: Added new option -backup for writing patch backup files to an
# |	            alternate directory (linked up to $PATCH_TOP/patchnum/backup)
# |	12-03-2005: Added information about noprereq option.
# |	15-03-2005: Could not use wait_on_failed_job in AD.I. Disabled feature
# |	16-04-2005: Minor fix ... not creating log backup dir
# |	17-05-2005: Added copy_timing_report function to copy timing report	
# |	20-05-2005: Changed incompleted jobs section (changed xxxx to !)
# |	26-05-2005: Changed to not depend on OPATCH_TOP for -c, -info,-tarinfo
# |	02-06-2005: Implemented -merge (merge patches)
# |	03-10-2005: Made changes when no onlinedef.txt using noconnect
# |	29-10-2005: Added support for partial translations
# |	09-11-2005: First release of -merge functionality
# |	14-11-2005: Implemented verification of passwords in onlinedef.txt
# |	15-11-2005: Implemented support for occn-updates.oracle-occn.com
# |	16-11-2005: Added MISSING_TRANSLATION tag to onlinedef.txt file
# |	28-11-2005: Exit program if any passwords where invalid in silent mode
# |	14-12-2005: Implemented check of metalink account (xxonline_dk terminated)
# |	29-12-2005: Refined metalink check
# |	02-01-2006: Added support for hotpatch when supplied as adpatch option
# |	10-02-2006: Added function status_statement
# |	28-03-2006: check_zipfile fixed ... check routine enhanced
# |	01-04-2006: Implemented return codes for errors
# |	22-04-2006:	Added option 'prereq' as default
# |	24-04-2006: Added support for encrypted defaults file
# |	01-05-2006: Moved metalink account check for silent mode
# |	            Implemented option 'clean' for deleting patchdir and zipfile
# |	05-06-2006: Removed passwords from command line in logfile
# |	            Added new option -notty (no tty to screen)
# |	12-06-2006: New option -kill for killing active patch sessions	
# |	13-06-2006: Added a more 'resilient' patch_applied checking routine 
# |	20-06-2006: Fixed issues in get_xml_file (making opatch.sh hang)	
# |	            Added 'expect' support for later AD versions (create_def)
# |	02-07-2006: Fixed checking routine to able to determine merged nls patches
# |	05-07-2006: Changed method of getting maintenance mode
# |	10-07-2006: Removed initial 'clear' command when running using -notty
# |	16-08-2006: Removed validate option when creating defaultsfile
# |	30-08-2006: Implemented kill of defaults creation script if using cntrl+c
# |	05-09-2006: Implemented check for node tier application
# |	09-09-2006: Implemented check to ensure expect does not run in loops 
# |	            Implemented fundamental changes to create_default option
# |	12-09-2006: Fixed a OS related error in expect commands.
# |	14-09-2006: Removed verbose 0 command from admrgpch 
# |	15-09-2006: Implemented merge of NLS patches	
# |	18-09-2006: Fixed some issues in merge patch 
# |	22-09-2006: Added message and check for autoconfig templates.
# |	            Implemented a 2 minute timeout on expect created def. file		
# |	09-10-2006: Implemented preinstall mode
# |	02-11-2006: New ftp check (some ftp cant redirect). Caught the error
# |	            Implemented new option '-forcemaint' to force set/unset 
# |	            maintenance mode when applying patches. 	
# |	07-11-2006: Implemented new timing calculation. Now able to handle 24 hour+
# |	09-11-2006: Fixed issue in check_ftp_status
# |	10-11-2006: Disabled 'autoconfig' warning if no new templates introduced
# |	            Enhanced check for applied 'merge' patch (ad_applied_patches)	
# |	11-11-2006: Implemented 'special' driver, for applying special apps drivers
# |	12-11-2006: Added check for running adpatch sessions to avoid conflicts
# |	15-11-2006: Bug fix for driver line
# |	21-11-2006: Bug fix for detecting cdg drivers	
# |	23-11-2006: Added failure in case no adpatch logfile generated
# |	29-11-2006: Changed function name get_num_cpu to get_num_workers
# |	05-12-2006: Changed clean function to also include merged patches
# |	06-12-2006: Fixed minor issue in clean function (patch_lang).
# |	07-12-2006: Added more TNS checks in run_sql
# |	29-01-2007: Changed default number of workers to be num_cpu*3
# |	30-01-2007: Added 2>/dev/null for all 'which' commands
# |	31-01-2007: Did a check on aiibas.lc version for defaultsfile creation	
# |	05-02-2007: Added 'test mode' option -test
# |	11-03-2007: Added check for WRONG_DRIVER when using -specialfile	
# |	23-03-2007: Fixed -kill for adctrl noninteractive	
# |	03-04-2007: Implemented impact analysis report (-impact)
# |	            Fixed minor bugs in -impact option
# |	18-04-2007: Limited -impact to only show installed products
# |	24-04-2007: Small fix for patchlog location
# |	22-05-2007: Added NLS reminder statement in end of patch log
# |	27-05-2007: Changed post upgrade info to a more simplified output	
# |	02-06-2007: More changes regarding display
# |	03-07-2007: Changed merge logfile name to be <patch>_merge.log
# |	05-07-2007: Multiple fixes relating to exit code
# |	11-11-2009: Implemented ARU account instead of metalink
# |	19-11-2009: Implemented WGET instead of FTP	
# |	11-09-2013: Implemented extra check for platform
# |	06-01-2014: Added http_proxy to wget connection. (aru-akam.oracle.com)
# |	------------------------- MAJOR REWRITE ----------------------------------
# |	05-11-2015: Major rewrite including apply|rollback modes for TECH
# |	09-11-2015: Added recursive read permissions on all files in PATCH_DIR
# |	12-11-2015: Fixed issue with opath versions (bugs_fixed/CheckConflicts)
# |	13-11-2015: Changed -tech parameter naming to -version
# |	19-11-2015: Fixed issue with sourcing RUN edition for WLS on PATCH
# |	24-11-2015: Fixed issue with multiple patches for one ID in WLS
# |	08-12-2015: Initial changes for runInstaller
# |	            Fixed issue with conflict checking on 10.1 OUI
# |	07-01-2016: Fixed disctionary corruption issue check to exlude old XML type
# |	13-01-2016: Added error handling for invalid patches
# |	27-01-2016: Added extra handling for 'check' mode
# |	08-02-2016: Fixed issues in rollback identifying subpatch as applied
# |	13-02-2016: Fixed issue with special opatch directory location
# |	15-02-2016: Addition to special opatch dir, plus error correction
# | 01-04-2016: Added support for SUN (no openssl)	
# |	21-05-2016: OPC awareness
# |	14-07-2016: Additional error checking for BSU
# |	03-10-2016: Added provisions for sshkey (SSH keystore connect for FTP)
# |	31-10-2016: Implemented check for previous failed opatch session 
# |	21-12-2016: Added path for 'nc' and 'nc32' executable
# | 31-01-2017: Permission issue on $logdir	
# |	01-02-2017: New option -ignoreDiskWarning for runInstaller 
# |	29-03-2017: Made changes for timeout during wget downloads
# |	18-05-2017: Removed long parameter -sshkey and -oh from GetOptions handling
# |	01-06-2017: Fixed parameters issue
# |	11-07-2017: End program after -c (check) if patch applied.
# | 24-07-2017: Fixed issue with moving patch directory if already existing	
# |	04-10-2017: Added additional error check for runInstaller
# |	26-10-2017: Added noproxy as initproxy for OPC
# |	27-11-2017: Changed min bsu memory argument to -Xms2048m 
# |	30-11-2017: Fixed issues with placeholder patches only
# |	09-01-2018: Added additional check to check if OPC
# |	23-01-2018: Major addition for WLS PSU/OVERLAY checking
# |	25-01-2018: Increased max bsu memory argument to -Xmx3074m
# |	25-01-2018: Fixed issue in forced version (WLS patches)
# |	20-02-2018: Added additional checks for NC_EXE
# |	27-02-2018: Addition version checks for zipfile check
# |	12-03-2018: Implemented additional checks for adop completion (multi MT)
# |	06-05-2018: Fixed bug in missing patch list
# |	05-08-2018: Changed zipfile check for dedicated forced version
# |	11-12-2018: Added missing -p usage information.
# |	05-02-2019: Additional change for forced zipfile version check
# |	
# +===========================================================================+
command_line="$@"
options_line="$@"
caller_script=$(basename $(ps --no-headers -o command $PPID 2>/dev/null|awk '{print $2}') 2>/dev/null)
if [[ $caller_script = omcs_opatch.sh ]];then
  opatch_script_name=omcs_opatch.sh
else
  opatch_script_name=opatch.sh
fi

# functions
target_oracle_home=""


function set_defaults
{
# Variable declarations
LOG_ORACLE_HOME=$ORACLE_HOME

# Set up default parameters
interactivemode=no
restart_mode=no
skip_download=no
if [[ ! -z $ORACLE_HOME ]];then
	patchlog=$ORACLE_HOME/opatch_log
	patchlog_name=ORACLE_HOME/opatch_log
else
	patchlog=$HOME/opatch_log
	patchlog_name=HOME/opatch_log
fi
if [[ ! -f $patchlog ]];then
	mkdir -p $patchlog 2>/dev/null
fi

HOST_NAME=$(echo $(hostname)|awk -F"." '{print $1}')


if [[ ! -z $ORACLE_SID ]];then
  mkdir /tmp/${ORACLE_SID}_DB 2>/dev/null
  chmod 777 /tmp/${ORACLE_SID}_DB 2>/dev/null
	logdir=/tmp/${ORACLE_SID}_DB/$$
	ENV_NAME=$ORACLE_SID
  ep_file=$ORACLE_HOME/.cryptfile
elif [[ ! -z $TWO_TASK ]];then
  mkdir /tmp/${TWO_TASK}_OTO 2>/dev/null
  chmod 777 /tmp/${TWO_TASK}_OTO 2>/dev/null
	logdir=/tmp/${TWO_TASK}_OTO/$$
	ENV_NAME=$(echo $TWO_TASK|sed 's%_806_BALANCE%%g'|sed 's%_BALANCE%%g'|sed 's%_patch%%g')
	if [[ -d $ORACLE_HOME ]];then
		ep_file=$ORACLE_HOME/.cryptfile_$HOST_NAME
	else
		ep_file=$HOME/.cryptfile_$HOST_NAME
	fi
else
  mkdir /tmp/OTO 2>/dev/null
  chmod 777 /tmp/OTO 2>/dev/null
	logdir=/tmp/OTO/$$
	envname=$(echo $HOME|awk -F"/" '{print $2}'|tr '[a-z]' '[A-Z]')
	if [[ $(echo $envname|wc -c) -eq 7 ]];then 
	  ENV_NAME=$envname
	else
  	ENV_NAME=UNKNOWN
  fi
	ep_file=$HOME/.cryptfile_$HOST_NAME
fi
mkdir -p $(dirname $logdir) 2>/dev/null
chmod 777 $(dirname $logdir) 2>/dev/null
edition_based=no

if [[ -d $APPL_TOP ]];then
	case $APPS_VERSION in 
		12.2*)	edition_based=yes
		        target_edition=PATCH;;
	esac	
	if [[ $edition_based = yes ]]&&((!$dbtier));then
		PATCH_APPL_TOP=$(echo $APPL_TOP|sed "s%$RUN_BASE%$PATCH_BASE%g")
		RUN_APPL_TOP=$(echo $APPL_TOP|sed "s%$PATCH_BASE%$RUN_BASE%g")
#		if [[ ! -z $ADOP_LOG_HOME ]];then
#  		patchlog=$ADOP_LOG_HOME
#  		patchlog_name="ADOP_LOG_HOME"
#  	elif [[ ! -z $NE_BASE ]];then
#  	  patchlog=$NE_BASE/EBSapps/log/adop
#  		patchlog_name="TECH_LOG"
#    else 
#  	  patchlog=$(dirname $APPL_TOP_NE)/log/adop
#  		patchlog_name="TECH_LOG"
#    fi
		if [[ ! -d $APPL_TOP_NE/ad/admin ]];then
  		mkdir -p $APPL_TOP_NE/ad/admin 2>/dev/null
  	fi 
		if [[ ! -d $APPL_TOP_NE/ad/bin ]];then
  		mkdir -p $APPL_TOP_NE/ad/bin 2>/dev/null
  	fi 
		ep_file=$APPL_TOP_NE/ad/admin/.cryptfile
	fi
fi
if [[ ! -f $patchlog ]];then
	mkdir -p $patchlog 2>/dev/null
fi

# Create logfile in $TECH_LOG directory
LogDate=$(echo $(date +%T%j%y|sed 's.:..g'))
LogFile=$patchlog/opatch_$LogDate.log
LogName=opatch_$LogDate.log
touch $LogFile 2>/dev/null
TECH_LOG=$patchlog

export ENV_NAME
nf=0
newpatch=yes
drop_patch=no
drop_previous=no
patchzipname=""
batch_mode=single
run_mode=normal
epfile_created=no
move_log_status=0
check_driver=""
driver_option=all
apply_options=""
#mlink_uname=xxonline_dk
#mlink_pwd=welcome
protocol_connection_check=NOTOK
workers=0
local_workers=""
localworkers=""
forced_lang=""
hotpatch="disabled"
db_connect=yes
patch_backup_dir=""
wait_on_failed_job=""
MlinkSet=1
exit_code=0
prereq=""
CleanPatch=0
CreateDef=0
apwd=""
spwd=""
LogStatement="tty"
password_status=1
run_autoconfig=no
pre_install_mode=n
apply_mode=y
maint_option=passive
special_file=""
special_option=normal
impact_option=none
patch_log_move_status=1
forced_tech_version=no
forced_platform_version=no
skip_inventory=no
tech_version=""
OPATCH_STAGE=${OPATCH_STAGE:-""}
restricted_pwd=""
use_backup_dir=0
encrypt_password=no
crypt_type=http
protocol=HTTP
http_crypt_pass="U2FsdGVkX1+wBhK0ClK04ikzFJZbQcP6a7bAUN0="
http_crypt_name="U2FsdGVkX1+ScbmIRZuA6Cxq62pkL+zjgHDkmI/mla8+qNo3rM8smiVXuS1QcYI="
credential=MOS
patch_ext=""
patch_ext2="NOTVALID"
inventory_check=1
set_linux32=0
opatch_apply_mode=apply
force_option=""
get_customer_type
ODCODE_TOP=$OHSUPG_TOP
if [[ ! -d $ODCODE_TOP ]];then
  if [[ -d /autofs/upgrade/ohsupg ]];then
    export ODCODE_TOP=/autofs/upgrade/ohsupg
  elif [[ -d /usr/local/MAS/ohsupg ]];then
    export ODCODE_TOP=/usr/local/MAS/ohsupg
  fi
fi
reverse=`tput rev 2>/dev/null`
bold=`tput smso 2>/dev/null`
blink=`tput blink 2>/dev/null`
off=`tput sgr0 2>/dev/null`

space_line=" ......................................................................"

#if [[ -f /usr/bin/zip ]];then
#  alias zip=/usr/bin/zip
#fi
#if [[ -f /usr/bin/unzip ]];then
#  alias unzip=/usr/bin/unzip
#fi

if [[ $(uname) = Linux ]]&&[[ -f /bin/echo ]];then
  echo="/bin/echo -e"
else
  echo=echo
fi
}

function get_whoami
{
if [[ -f /usr/xpg4/bin/id ]]; then
	WHOAMI=$(/usr/xpg4/bin/id -u -n) > /dev/null 2>&1
	GROUP=$(/usr/xpg4/bin/id -g -n) > /dev/null 2>&1
fi
if [[ "$WHOAMI" = "" ]]; then
	WHOAMI=$(id -u -n) > /dev/null 2>&1
	GROUP=$(id -g -n) > /dev/null 2>&1
	if [[ "$WHOAMI" = "" ]]; then
		WHOAMI=$(whoami| awk '{print $1}')
		GROUP=$(id|awk -F"(" '{print $3}'|awk -F")" '{print $1}') > /dev/null 2>&1
	fi
fi
unixuid=$WHOAMI
unixgid=$GROUP
}


function reset_log_location
{
if [[ $LOG_ORACLE_HOME != $TARGET_ORACLE_HOME ]]&&[[ ! -z $TARGET_ORACLE_HOME ]];then
  if [[ ! -d  $TARGET_ORACLE_HOME/opatch_log ]];then
    mkdir -p $TARGET_ORACLE_HOME/opatch_log 2>/dev/null
  fi
  patchlog=$TARGET_ORACLE_HOME/opatch_log
  TECH_LOG=$patchlog 
  mv $LogFile $patchlog >/dev/null 2>&1
  LogFile=$TARGET_ORACLE_HOME/opatch_log/$LogName
fi
}

function get_patch_extension
{
if [[ -z $patch_ext ]];then
	patch_ext2="INVALID"
	platform_id2=""
	platform_id_list=""
	case $(uname) in
		OSF1)	patch_ext=TRU64
		      platform_id=87;;
		SunOS)	if [[ $(uname -a|grep -ic solaris64) -gt 0 ]]||[[ $(isainfo -k 2>/dev/null|grep -c "sparcv9") -gt 0 ]]||[[ $(isainfo -b 2>/dev/null|grep -c "64") -gt 0 ]] ;then
						patch_ext=SOLARIS64
						platform_id=23
						patch_ext2=SOLARISx86-64
						platform_id2=267
					else
						patch_ext=SOLARIS
						platform_id=453
						patch_ext2=SOLARISx86
						platform_id2=173
					fi;;
		HP*)	case $(uname -i) in
				ia64)	patch_ext=HPUX-IA64
				      platform_id=197;;
				ia32)	patch_ext=HPUX-IA32
				      platform_id=278;;
				*)	patch_ext=HP64
				    platform_id=59;;
				esac;;
		AIX)	run_sql "system/$systempwd" "get_os.lst" "select dbms_utility.port_string from dual;"
				if [[ $(grep -i AIX64 $logdir/get_os.lst|wc -l) -gt 0 ]];then
					patch_ext=AIX64-5L
					platform_id=212
				else
					patch_ext=AIX
					platform_id=319
				fi;;
		Linux)	case $(uname -i) in
					i386)	patch_ext=Linux-x86
					      platform_id=46;;
					x86-64|x86_64)	patch_ext=Linux-x86-64
					                platform_id=226;;
					ia64)	patch_ext=Linux-IA64
					      platform_id=214;;
					esac
					if [[ $(file $TARGET_ORACLE_HOME/bin/tnsping 2>/dev/null|grep "32-bit"|wc -l) -gt 0 ]];then
					  if [[ $(echo $patch_ext|grep 64|wc -l) -gt 0 ]];then
					    set_linux32=1
					    OPATCH_PLATFORM_ID=46
					    export OPATCH_PLATFORM_ID
					  fi 
				    patch_ext=LINUX
				    platform_id=46
				  fi
					patch_ext2=LINUX
					platform_id2=46
					;;
  	WINNT)  patch_ext=WINNT;;
		*) 		patch_ext="";;
	esac
	platform_id_list="$platform_id,$platform_id2,2000,99999"
	platform_id_list=$(no_duplicate_word "$platform_id_list" ",")
fi
export patch_ext patch_ext2 platform_id_list
}		

# Parameter 1 is test to have duplicate chars removed 
# Parameter 2 is one or more chars to remove (example "; : ,")
# Default character is ","
function no_duplicate_char
{
  duptext="$1"
  dup_char=${2:-","}
  for dupchar in $(echo "$dup_char");do
    duptext=$(echo "$duptext"| sed "s%${dupchar}${dupchar}*%${dupchar}%g"|sed "s%^ *${dupchar}%%g"|sed "s%${dupchar} *$%%g")
  done
  echo "$duptext"
}

# Parameter 1 is test to have duplicate words removed 
# Parameter 2 is word separator (example ",")
# Default character is ","
function no_duplicate_word
{
  duptext="$1"
  dup_char=${2:-","}
  newline=""
  for line_data in $(echo "$duptext"|tr "$dup_char" "\n"|sed 's% %x#x%g');do
    line=$(echo $line_data|sed 's%x#x% %g')
    if [[ $(echo "$newline"|grep -c "${line}${dup_char}") -eq 0 ]];then
      newline="${newline}${line}${dup_char}"
    fi
  done
  duptext=$newline
  duptext=$(no_duplicate_char "$duptext" "$dup_char")
  echo "$duptext"
}

function set_platform
{
if [[ -z $platform_name ]];then
	case $(uname) in
		OSF1)	  platform_name=tru64;;
		SunOS)	platform_name=solaris;;
		HP*)	  platform_name=hpux;;
		AIX)	  platform_name=aix;;
		Linux)	platform_name=linux;;
  	WINNT)  platform_name=winnt;;
		*) 		  platform_name="unknown";;
	esac
fi
}

# Running statement is for displaying 'running' line
# Parameter 1 is the base text
function running_statement
{
typeset -L60 line=$1$space_line
$echo "      ${line}${blink} running $off \r\c"
}

# Format statement is for displaying formatted line
# Parameter 1 is the base text
# Parameter 2 is status message
function format_statement
{
status_message_count=$(echo $2|wc -c)
((status_message_count-=1))
if [[ $status_message_count -gt 11 ]];then
  line_message_count=$(echo "60 11 + $status_message_count - pq"|dc)
  typeset -L$line_message_count line=$1$space_line
  typeset -L$status_message_count line_status=$2
else
  typeset -L60 line=$1$space_line
  typeset -L11 line_status=$2"             "
fi  
xxecho "      $line $line_status"
}

# Status statement is for displaying status line (OK/failed)
# Parameter 1 is the text for display
# Parameter 2 is status (optional)
function status_statement
{
typeset -L60 line=$1$space_line
if [[ $2 = "" ]];then
	xxecho "      $line" N
	echo "      $line\c"
else
	if (($2));then
		xxecho "      $line$blink failed    $off"
		return $2
	else
		xxecho "      $line succeeded  "
	fi
fi
}

function get_free_disk
{
disk_info=""
case $(uname) in
OSF1)	df -k $OPATCH_TOP|grep -vi used|while read line;do
			disk_info="$disk_info $line"
			echo $disk_info > $logdir/disk_info.txt
		done
		free_disk=$(cat $logdir/disk_info.txt|awk '{print $4}');;
SunOS)	df -k $OPATCH_TOP|grep -vi used|while read line;do
				disk_info="$disk_info $line"
				echo $disk_info > $logdir/disk_info.txt
			done
			free_disk=$(cat $logdir/disk_info.txt|awk '{print $4}');;
HP*)	bdf $OPATCH_TOP|grep -vi used|grep -v ^$|while read line;do
			disk_info="$disk_info $line"
			echo $disk_info > $logdir/disk_info.txt
		done
		free_disk=$(cat $logdir/disk_info.txt|awk '{print $4}');;
AIX)	df -k $OPATCH_TOP|grep -vi used|while read line;do
			disk_info="$disk_info $line"
			echo $disk_info > $logdir/disk_info.txt
		done
		free_disk=$(cat $logdir/disk_info.txt|awk '{print $3}');;
Linux)	df -k $OPATCH_TOP|grep -vi used|while read line;do
				disk_info="$disk_info $line"
				echo $disk_info > $logdir/disk_info.txt
			done
			free_disk=$(cat $logdir/disk_info.txt|awk '{print $4}');;
esac
echo $free_disk > $logdir/disk_space.adp
}

GetOptions() {
  trap OnTerm TERM
  function OnTerm
  {
    exit 1
  }
#
  DeBug=${DeBug:-0}
  if (($DeBug));then
    set -x
  fi
#
  ProgTermination() {
    case $GOusage in
       1) echo $PTtxt
          $UsageRoutine $CurOpt $CurOptMod;;
       2) $UsageRoutine $CurOpt $CurOptMod;;
       3) return "$PTcode";;
      99) echo $PTtxt;;        #this entry when internal error
      *)  echo $PTtxt;;
    esac
#
    kill -TERM $$
  }
#
  splitOpt() {
    splitVar=$1
    varOpt=$2
    eval $splitVar=$(echo "$varOpt"|/usr/bin/awk '{
      alpha=0; modifier=0; optreq=0; parreq=0; controlopt=""
      for(pos=1;pos<=length($0);pos++)
      {
        if(substr($0,pos,1) ~ /[a-zA-Z]/) {alpha++}
        if(substr($0,pos,1) ~ /[+:%@!-]/)
          {modifier++}
        if(substr($0,pos,1) ~ /[1-9]/)
        {
          if(index($0,"+"substr($0,pos,1)) > 0) parreq=substr($0,pos,1)
          else if(alpha) optreq=substr($0,pos,1)
        }
        if(substr($0,pos,1) ~ /[\/]/)
        {
          controlopt=substr($0,pos+1,length($0))
          print "controlopt="substr($0,pos+1,length($0)) >> "p5"
          break
        }
      }
          print alpha"/"modifier"/"optreq"/"parreq"/"controlopt
    }')
  }
#
  chReqOpt() {
    cROstat=$(echo "$GOopt $OptLen $OptReq $GOoptions"|$AWK -v par="$GOparameters" '
      function chReq(option, optlen, req, options, parameters)
      { reqlen=length(req) ; o_options=options; reqn=0;
        options=","options","; o_req=req; reqn=0
#
#while loop to check if caller has indeed marked req options
#as required options
#
#loop as long as we can find a required option in the options list
#
        while(index(options,"/"option",") > 0)
        {
          reqn++
          optslen=length(options)
          opre=substr(options,1,index(options,"/"option)-1)
          oapp=substr(options,index(options,"/"option)+optlen+reqlen,optslen)
          options=opre oapp
          mro="-"a[n=split(opre,a,",")]"/"
          oneopt=""
          for(i=1;i<=length(mro);i++)
            if(substr(mro,i,1) ~ /[a-zA-Z]/)
              oneopt=oneopt substr(mro,i,1)
          reqopt=reqopt"-"oneopt"/"
          Vreqopt=Vreqopt a[n=split(opre,a,",")]" "
        }
        reqStat="okReq"
        reqTxt=""
        if(reqn < req)
        {
          reqStat="CnoReq"
          reqTxt="<internal error> "
          reqTxt=reqTxt "option "option" requires "req" options "
          if(reqn < req)
            reqTxt=reqTxt "only "reqn"("Vreqopt") was found in: "o_options
          else
            reqTxt=reqTxt "but "reqn" can be found in: "o_options
          return reqStat"@"reqTxt
        }
        pn=split(parameters,aa)
        for(i=1;i<=pn;i++)
          if(index(reqopt,aa[i]"/") > 0)
          {
            req--
            optspe=optspe aa[i]" "
          }
        if(req != 0)
        {
          reqTxt="you specified "o_req-req" option(s):"
          reqTxt=reqTxt optspe
          reqTxt=reqTxt ", but option -"option" requires "o_req" option(s): "
          reqStat="UnoReq"
        }
        return reqStat"@"reqTxt"@"Vreqopt
      }
    {
      p=chReq($1,$2,$3,$4,par)
      print p
    }')
#
    IFS=$OIFS
    cROerr=1
    case $(echo $cROstat|$AWK -F"@" '{print $1}') in
      okReq) cROerr=0;;
       *) case $(echo $cROstat|$AWK -F"@" '{print $1}') in
            CnoReq) PTtxt="$(echo $cROstat|$AWK -F"@" '{print $2}')"
                    PTcode=CnoReq;;
            UnoReq) UreqOpt=$(echo $cROstat|$AWK -F"@" '{print $3}')
                    for mo in $UreqOpt;do
                      splitOpt mol "$mo"
                      mol=$(echo $mol|$AWK -F/ '{print $1}')
                      mo=$(echo $mo|$AWK -v len=$mol '{print substr($1,1,len)}')
                      moTab=$moTab" -"$mo
                    done
                    PTtxt="$(echo $cROstat|$AWK -F"@" '{print $2}') $moTab"
                    PTcode=UnoReq;;
          esac;;
    esac
    if ((cROerr));then
     ProgTermination
    fi
  }
#
#  debug
#
#if this is the first time then do some housekeeping and at
#the same time test if user has entered a non-option as the
#first parameter($1)...that is not valid...
#
  if [[ -z $InitOpt ]];then
#
    AWK=awk
    sun=0 hp=0 aix=0 osf=0
    platform=$(uname|$AWK '{print (tolower(substr($1,1,3)))}')
    case $platform in
    hp-) hp=1;;
    [Ss][Uu][Nn]) sun=1;; #'awk tolower' not working correctly on sun...
    aix) aix=1;;
    osf) osf=1;;
    esac
#
    if (($sun));then
      if [[ -x /usr/xpg4/bin/awk ]];then
        AWK=/usr/xpg4/bin/awk
      else
        if [[ -x /usr/bin/nawk ]];then
          AWK=/usr/bin/nawk
        else
          echo "\nunable to locate proper awk"
          echo "searched for /usr/xpg4/bin/awk and /usr/bin/nawk"
          echo "check for file existance and file permissions\n"
          GOusage=99
          ProgTermination
        fi
      fi
    fi

    #move Options($1) and Case variable name($2) to local variables
    GOoptions=$1
    GOcaseVar=$2
    shift 2       #$@ will - after the shift - contain options/parameters
                  #given by the user...
    mutexTab=""   #variable to contain MuTualEXclusive options
#
#at this time $1 can be either U|u or user given option/parameters
#if $1 = U|u then $2 must be the name of the usage routine
    GOparameters=$1
    GOusage=0
    GOshiftNum=2
    case $GOparameters in
      R|r) GOshiftNum=1
           GOusage=3;;
      S|s) GOusage=2;;
      U|u) GOusage=1;;
      *) GOshiftNum=0;;
    esac
    UsageRoutine=$2   #set it unconditionally since this variable is only
                      #used when caller in fact does have a 'usage' section
    shift $GOshiftNum #shift positional parameters
#
    GOparameters=$@  #move user options/parameters to local variable
    GOparamNum=$#    #move number of user options/prameters to local variable

    if [[ $(echo $1|$AWK '{print substr($1,1,1)}') != "-" ]];then
      PTtxt="\ncannot start with a parameter"
      PTcode=notOption
      ProgTermination
    else
      InitOpt=done
#get the number of options specified from the user...
#some options cant be the only option given...
      nOpt=0
      for arg in $GOparameters;do
        if [[ $(echo $arg|$AWK '{print substr($1,1,1)}') = "-" ]];then
          ((nOpt+=1))   #count number of options given by user
        fi
      done
    fi
  fi
#
  CurOptOk=0 #set to 1 if current option can be found in var Options

#  holds the current option from caller
   CurOpt=$(echo "$GOparameters"|$AWK '{split($0,A);print A[1]}')

#if CurOpt is empty it means that all options has been processed
#so return 1 in order for the callers while loop to end...
#
   if [[ $CurOpt = "" ]];then
#
#check if user has entered options that are mutaually exclusive...
#
     if [[ $(echo $mutexTab|$AWK '{print n=split($0,mta)}') -gt 1 ]];then
       PTtxt="\nfollowing options are mutually exclusive:\n$mutextab"
       PTcode=mutex
       ProgTermination
     fi
     return 1
   fi

#  holds the next option/parameter from caller
   NextArg=$(echo "$GOparameters"|$AWK '{print $2}')   #1.3.1

#
#loop through Options to check if CurOpt is valid and to get modifiers
#
  OIFS=$IFS
  IFS=,
  for ValOpt in $GOoptions;do
    splitOpt OptModLen "$ValOpt"
#
    OptLen=$(echo $OptModLen|$AWK -F/ '{print $1}')
    ModLen=$(echo $OptModLen|$AWK -F/ '{print $2}')
    OptReq=$(echo $OptModLen|$AWK -F/ '{print $3}')
    ParReq=$(echo $OptModLen|$AWK -F/ '{print $4}')
    ControlOpt=$(echo $OptModLen|$AWK -F/ '{print $5}')
#
    if ((!$OptLen));then
      PTtxt="\nsome invalid chars given in GetOptions\n"
      GOusage=99
      ProgTermination
    fi
#
    GOopt=$(echo $ValOpt|$AWK -v len=$OptLen '{print substr($1,1,len)}')
#
    if [[ $CurOpt = "-"$GOopt ]];then
      OptMod=$(echo $ValOpt|$AWK -v len=$ModLen -v pos=$OptLen '{print substr($1,pos+1,len)}')
      CurOptOk=1
      break
    fi
  done
#
  IFS=$OIFS
  if ((!$CurOptOk));then
    PTtxt="\n$CurOpt is not a valid option\n"
    ProgTermination
  fi
#
  NextArgIsOpt=0
  if [[ $(echo $NextArg|$AWK '{print substr($1,1,1)}') = "-" ]];then
    NextArgIsOpt=1 #next parameter is in fact an option and per
    NextArg=""     #definition will NextArg be returned as an empty string
    ShiftNum=1
  else
    ShiftNum=2
  fi
#
  GOparameters=$(echo "$GOparameters"|$AWK -v skip=$ShiftNum '
                  {an=split($0,PArray)
                   for(pn=skip+1;pn<=an;pn++) {params=params " " PArray[pn]}
                   print params
                  }'
                 )
#
    if (($OptReq)) && [[ $CurOpt = "-"$GOopt ]];then
      chReqOpt
    fi
#
  OPN=0
  while (($OPN < $ModLen));do
    ((OPN+=1))
    case $(echo $OptMod|$AWK -v pos=$OPN '{print substr($0,pos,1)'}) in
      +) if [[ $NextArg = "" ]];then
           PTtxt="\nOption $CurOpt reqiures a parameter\n"
           PTcode=noParam
           ProgTermination
         fi;;
      -) if [[ $NextArg != "" ]] && ((!$NextArgIsOpt));then
           PTtxt="\nOption $CurOpt does not take a parameter\n"
           PTcode=param
           ProgTermination
         fi;;
      :) if [[ $nOpt < 2 ]];then
           PTtxt="\nOption $CurOpt cant be the only option\n"
           PTcode=alone
           ProgTermination
         fi;;
      %) mutexTab="$mutexTab $CurOpt";;
      @) an=$(echo $NextArg|/usr/bin/awk '{n=0
                 for(pos=1;pos<=length($0);pos++)
                   if(substr($0,pos,1) ~ /[a-zA-Z]/) {n++}
                 print(n)
          }')
          if [[ $an != ${#NextArg} ]];then
            PTtxt="\nparameter $NextArg must be alphabetic\n"
            PTcode=notAlpha
            ProgTermination
          fi ;;
      !) n=$(echo $NextArg|/usr/bin/awk '{n=0
                 for(pos=1;pos<=length($0);pos++)
                   if(substr($0,pos,1) ~ /[0-9]/) {n++}
                 print(n)
          }')
          if [[ $n != ${#NextArg} ]];then
            PTtxt="\nparameter $NextArg must be numeric\n"
            PTcode=notNum
            ProgTermination
          fi ;;
      "") break;;
    esac
  done
#
#remove '-' from option before returning option to caller
#
  if [[ $(echo $CurOpt|$AWK -F"-" '{split($0,A);print A[2]}') != "" ]];then
    CurOpt=$(echo $CurOpt|$AWK -F"-" '{split($0,A);print A[2]}')
  fi
#
#write option into callers variable
#
  eval $GOcaseVar=$CurOpt
  return 0
}

function wrong_syntax
{
clear
echo > /tmp/wrong_syntax.txt
chmod 777 /tmp/wrong_syntax.txt 2>/dev/null
echo " =============================================================================" >> /tmp/wrong_syntax.txt
echo "   AUTO OPATCH SCRIPT" >> /tmp/wrong_syntax.txt
echo " =============================================================================" >> /tmp/wrong_syntax.txt
echo >> /tmp/wrong_syntax.txt
echo "   Invalid parameter(s) specified" >> /tmp/wrong_syntax.txt
echo >> /tmp/wrong_syntax.txt
echo "   Valid options are:" >> /tmp/wrong_syntax.txt
echo "   $opatch_script_name -a|-c|-d|-r|-v|-p|-rollback (patch#) [-noconnect] " >> /tmp/wrong_syntax.txt
echo "             [-s] [-force] [-p <patch zipfile name>]" >> /tmp/wrong_syntax.txt
echo "             [-platform <platform>] [-version <TECH version>]" >> /tmp/wrong_syntax.txt
echo "             [-type <db|fmw_web|fmw_common|fmw_*|wls|oas|ias|forms>]" >> /tmp/wrong_syntax.txt
echo "             [-oh <ORACLE_HOME>] [-edition <run|patch>]" >> /tmp/wrong_syntax.txt
echo "             [-skipinventory]" >> /tmp/wrong_syntax.txt
echo "             [-spass <system password>]" >> /tmp/wrong_syntax.txt
echo "             [-apass <apps password>]" >> /tmp/wrong_syntax.txt
echo "             [-wpass <weblogic password>]" >> /tmp/wrong_syntax.txt
echo "             [-mname <metalink username> -mpass <metalink password>]" >> /tmp/wrong_syntax.txt

echo "   Following options are mutually exclusive:" >> /tmp/wrong_syntax.txt
echo "      -a, -c, -d, -r, -v, -p and -rollback" >> /tmp/wrong_syntax.txt
echo "   I.e. only one of these options can be specified at a time." >> /tmp/wrong_syntax.txt
echo "   Parameter for option -a, -c, -d, -r, -v and -rollback is required to" >> /tmp/wrong_syntax.txt
echo "   be numeric, i.e. a patch number or comma separated list of patches." >> /tmp/wrong_syntax.txt
echo >> /tmp/wrong_syntax.txt
echo "   -a  Apply patch using opatch/bsu.sh in non-interactive mode" >> /tmp/wrong_syntax.txt
echo "   -c  Check if a given patch has been applied or not." >> /tmp/wrong_syntax.txt
echo "   -d  Download patch. Requires available HTTP connection to " >> /tmp/wrong_syntax.txt
echo "       'updates.oracle.com'" >> /tmp/wrong_syntax.txt
echo "   -r  Read-only mode, enables users to display and read the patch" >> /tmp/wrong_syntax.txt
echo "       readme files" >> /tmp/wrong_syntax.txt
echo "   -v  Validate mode, enables users to check potential patch for conflicts" >> /tmp/wrong_syntax.txt
echo "   -p  Download patch zipfile. Requires available HTTPS connection to updates.oracle.com" >> /tmp/wrong_syntax.txt
echo "       Downloads list of zipfiles (example: -p p21681552_12102180717_Linux-x86-64.zip)" >> /tmp/wrong_syntax.txt
echo "   -rollback  Rollback patch using opatch/bsu.sh in non-interactive mode" >> /tmp/wrong_syntax.txt
echo "   -tar  Provide SR/RFC number on commandline." >> /tmp/wrong_syntax.txt
echo "   -info Check patch information. Timing info, and SR/RFC numbers as for patch" >> /tmp/wrong_syntax.txt
echo "   -tarinfo Check patch timing information in relation to tar. " >> /tmp/wrong_syntax.txt
echo "            Patch and Timing info for SR/RFC" >> /tmp/wrong_syntax.txt
echo "   -interactive  Interactive mode. All prompts will be presented." >> /tmp/$$.txt
echo "   -s  Silent mode. Skips readme files, applies patch immediately." >> /tmp/wrong_syntax.txt
echo "   -noconnect Enables you to download or read readme files for a given" >> /tmp/wrong_syntax.txt
echo "              patch without actually connecting to database and checking" >> /tmp/wrong_syntax.txt
echo "              if patch has been applied." >> /tmp/wrong_syntax.txt
echo "              This option only works with '-d' and '-r'." >> /tmp/wrong_syntax.txt
#echo "   -clean Cleans up after successfull patch application." >> /tmp/wrong_syntax.txt
#echo "          When patch has been successfully applied, patchdir" >> /tmp/wrong_syntax.txt
#echo "          and patch zipfile will be deleted." >> /tmp/wrong_syntax.txt
#echo "              patch without actually connecting to database and checking" >> /tmp/wrong_syntax.txt
#echo "              if patch has been applied." >> /tmp/wrong_syntax.txt
#echo "              This option only works with '-d' and '-r'." >> /tmp/wrong_syntax.txt
echo "   -edition   Only applicable for 12.2. If you want to force the edition for $opatch_script_name." >> /tmp/wrong_syntax.txt
echo "              Default edition is PATCH. You can force the edition to 'run' by using" >> /tmp/wrong_syntax.txt
echo "              -edition RUN" >> /tmp/wrong_syntax.txt
echo "   -platform  If you want to download a patch for a different platform." >> /tmp/wrong_syntax.txt
echo "              Example: -platform Linux-x86-64." >> /tmp/wrong_syntax.txt
echo "   -version   If you want to download a patch for a different TECH version." >> /tmp/wrong_syntax.txt
echo "              Example: -version 10105" >> /tmp/wrong_syntax.txt
echo "   -type      If you want to download/apply a patch for a specific tech type." >> /tmp/wrong_syntax.txt
echo "              This is especially useful when you have several different ORACLE_HOME's" >> /tmp/wrong_syntax.txt
echo "              installed under same user." >> /tmp/wrong_syntax.txt
echo "              db: DB tier OH. This is default type." >> /tmp/wrong_syntax.txt
echo "              fmw_web: FMW Web tier OH" >> /tmp/wrong_syntax.txt
echo "              fmw_common: FMW Common OH" >> /tmp/wrong_syntax.txt
echo "              fmw_*: Other FMW OH (requires -oh parameter)" >> /tmp/wrong_syntax.txt
echo "              wls: WebLogic OH (FMW_HOME, MW_HOME)" >> /tmp/wrong_syntax.txt
echo "              oas|ias: OAS/IAS OH (example IAS_ORACLE_HOME under R12.0)" >> /tmp/wrong_syntax.txt
echo "              forms: FORMS OH (example ORACLE_HOME under R12.0)" >> /tmp/wrong_syntax.txt
echo "   -oh        For forcing ORACLE_HOME value." >> /tmp/wrong_syntax.txt
echo "              ORACLE_HOME for WLS (1036) is typically \$FMW_HOME or \$MW_HOME" >> /tmp/wrong_syntax.txt
echo "   -skipinventory If you want to skip the inventory check." >> /tmp/wrong_syntax.txt
echo "                  Inventory is skipped default if -version or -platform" >> /tmp/wrong_syntax.txt
echo "                  has been provided on command line." >> /tmp/wrong_syntax.txt
echo "   -mname Used for supplying metalink username." >> /tmp/wrong_syntax.txt
echo "          Should be used in conjunction with -mpass" >> /tmp/wrong_syntax.txt
echo "   -mpass Used for supplying metalink password." >> /tmp/wrong_syntax.txt
echo "          Should be used in conjunction with -mname" >> /tmp/wrong_syntax.txt
echo "   -apass Used for supplying system password on commandline."  >> /tmp/wrong_syntax.txt
echo "          Can be used in conjunction with silent mode"  >> /tmp/wrong_syntax.txt
echo "   -spass Used for supplying system password on commandline."  >> /tmp/wrong_syntax.txt
echo "          Can be used in conjunction with silent mode"  >> /tmp/wrong_syntax.txt
echo "   -wpass Used for supplying WebLogic password on commandline."  >> /tmp/wrong_syntax.txt
echo "          Can be used in conjunction with silent mode"  >> /tmp/wrong_syntax.txt
echo "   -force Used for force applying a patch despite of conlicting patches."  >> /tmp/wrong_syntax.txt
echo "          Using this option only has effect during apply, and it will"  >> /tmp/wrong_syntax.txt
echo "          rollback any conflicting patches regardless."  >> /tmp/wrong_syntax.txt
echo "   -notty Used for supplying patch without echo to screen."  >> /tmp/wrong_syntax.txt
echo "   -proxy Used in connection to protocol HTTP."  >> /tmp/wrong_syntax.txt
echo "          Enter proxy url for accessing updates.oracle.com"  >> /tmp/wrong_syntax.txt
echo "   -h     Will display USAGE section for $opatch_script_name" >> /tmp/wrong_syntax.txt
echo " =============================================================================" >> /tmp/wrong_syntax.txtecho >> /tmp/wrong_syntax.txt
more /tmp/wrong_syntax.txt
rm -f /tmp/wrong_syntax.txt > /dev/null 2>&1
end_program ParameterError
}

function USAGE
{
echo "   FILENAME" > /tmp/$$.txt
echo "   $opatch_script_name - DB patch download script" >> /tmp/$$.txt
echo >> /tmp/$$.txt
echo "   SYNOPSIS" >> /tmp/$$.txt
echo "   $opatch_script_name -a|-c|-d|-r|-v|-rollback|-verify|-info|-tarinfo <patch#> " >> /tmp/$$.txt
echo "             [-s] [-force] [-platform <platform>] [-version <TECH version>] " >> /tmp/$$.txt
echo "             [-p <patch zipfile name>]" >> /tmp/$$.txt
echo "             [-type <fmw_web|fmw_common|fmw_*|wls|oas|ias|forms>]" >> /tmp/$$.txt
echo "             [-oh <ORACLE_HOME>] [-edition <run|patch>]" >> /tmp/$$.txt
echo "             [-skipinventory] [-noconnect]" >> /tmp/$$.txt
echo "             [-apass <apps password> ]" >> /tmp/$$.txt
echo "             [-spass <system password> ]" >> /tmp/$$.txt
echo "             [-wpass <weblogic password> ]" >> /tmp/$$.txt
echo "             [-mname <metalink username> -mpass <metalink password> ]" >> /tmp/$$.txt
echo >> /tmp/$$.txt
echo "   DESCRIPTION" >> /tmp/$$.txt
echo "   The $opatch_script_name script is a wrapper script that will enable users" >> /tmp/$$.txt
echo "   to download and apply patches in a more user friendly way." >> /tmp/$$.txt
echo "   Log directory will be in \$TARGET_ORACLE_HOME/log/<patchnumber_techver>" >> /tmp/$$.txt
echo "   The $opatch_script_name script also checks whether patch has already been applied." >> /tmp/$$.txt
echo >> /tmp/$$.txt
echo "   Prerequisites for using:" >> /tmp/$$.txt
echo "   1. Make sure that the oracle environment has been sourced (ORACLE_SID.env)" >> /tmp/$$.txt
echo "   2. If patch directory is different from \$TARGET_ORACLE_HOME/patch, an environment" >> /tmp/$$.txt
echo "      variable needs to be set:" >> /tmp/$$.txt
echo "      export OPATCH_TOP=<full path to base patch directory>;" >> /tmp/$$.txt
echo "      Typically: export OPATCH_TOP=/ood_repository/patches/TECH_PATCHES" >> /tmp/$$.txt
echo "      This variable should be set in .profile or adovars.env" >> /tmp/$$.txt
echo >> /tmp/$$.txt
echo "   The wrapper script enables user to do one (only one at a time) of following:" >> /tmp/$$.txt
echo "   -a    Apply patch using opatch/bsu.sh in non-interactive mode" >> /tmp/$$.txt
echo "         Also checks if patch has previously been applied, downloads patch," >> /tmp/$$.txt
echo "         unzips patch and displays readme files" >> /tmp/$$.txt
echo "   -c  Check if a given patch has been applied or not." >> /tmp/$$.txt
echo "   -d  Download patch. Requires available HTTPS connection to updates.oracle.com" >> /tmp/$$.txt
echo "       Also checks if patch has previously been applied, or if zip file is" >> /tmp/$$.txt
echo "       already present." >> /tmp/$$.txt
echo "   -r  Read-only mode, enables users to display and read the patch readme files" >> /tmp/$$.txt
echo "       Downloads patch (if HTTPS connection is possible), unzips patch and " >> /tmp/$$.txt
echo "       displays readme files." >> /tmp/$$.txt
echo "   -v  Validate mode, enables users to check if a patch may have conflicts" >> /tmp/$$.txt
echo "       with already applied patches." >> /tmp/$$.txt
echo "       Downloads patch (if HTTPS connection is possible), unzips patch and " >> /tmp/$$.txt
echo "       check for conflicts." >> /tmp/$$.txt
echo "   -p  Download patch zipfile. Requires available HTTPS connection to updates.oracle.com" >> /tmp/$$.txt
echo "       Downloads list of zipfiles (example: -p p21681552_12102180717_Linux-x86-64.zip)" >> /tmp/$$.txt
echo "   -rollback  Rollback patch using opatch/bsu.sh in non-interactive mode" >> /tmp/$$.txt
echo "              Also checks if patch has previously been applied, downloads patch" >> /tmp/$$.txt
echo "              and unzips patch" >> /tmp/$$.txt
#echo "   -options To provide further adpatch options to adpatch." >> /tmp/$$.txt
#echo "            Can only be used together with option -a (apply)." >> /tmp/$$.txt
#echo "            Options can be entered as '-options noprereq,novalidate' etc." >> /tmp/$$.txt
#echo "   -tar  Provide SR/RFC number on command line." >> /tmp/$$.txt
#echo "   -info Check patch information. Timing info, and SR/RFC numbers associated to patch" >> /tmp/$$.txt
#echo "   -tarinfo Check patch timing information in relation to SR/RFC. Patch and Timing info for SR/RFC" >> /tmp/$$.txt
echo >> /tmp/$$.txt
echo "   Other parameters:" >> /tmp/$$.txt
echo "   -interactive  Interactive mode. This will apply using opatch with all" >> /tmp/$$.txt
echo "       prompts. This should be used for applying patch fully interactive." >> /tmp/$$.txt
echo "       Usually used if a patch fails (for 'changing' default answers)." >> /tmp/$$.txt
echo "       This is mutually exclusive with -s (silent) mode." >> /tmp/$$.txt
echo "   -s  Silent mode. This will skip several interactive routines, and should only" >> /tmp/$$.txt
echo "       be used in circumstances where user is aware of any potential issues" >> /tmp/$$.txt
echo "       concerning the patch. " >> /tmp/$$.txt
echo "       When running in silent mode, readme files will be skipped," >> /tmp/$$.txt
echo "       and patch will be downloaded immediately without intervention." >> /tmp/$$.txt
echo "       If a patch has already been applied it will be skipped by default." >> /tmp/$$.txt
echo "   -noconnect Enables you to download or read readme files for a given" >> /tmp/$$.txt
echo "              patch without actually connecting to database and checking" >> /tmp/$$.txt
echo "              if patch has been applied." >> /tmp/$$.txt
echo "              This option only works with '-d' and '-r'." >> /tmp/$$.txt
echo "   -edition   Only applicable for 12.2. If you want to force the edition for $opatch_script_name."  >> /tmp/$$.txt
echo "              Default edition is PATCH. You can force the edition to 'run' by using"  >> /tmp/$$.txt
echo "              -edition RUN"  >> /tmp/$$.txt
echo "   -platform  If you want to download a patch for a different platform than current." >> /tmp/$$.txt
echo "              Example: -platform Linux-x86-64." >> /tmp/$$.txt
echo "   -version   If you want to download a patch for a different TECH version than current." >> /tmp/$$.txt
echo "              Example: -version 10105" >> /tmp/$$.txt
echo "   -tech      See -version above." >> /tmp/$$.txt
echo "   -type      If you want to download/apply a patch for a specific tech type." >> /tmp/$$.txt
echo "              This is especially useful when you have several different" >> /tmp/$$.txt
echo "              ORACLE_HOME's installed under same user." >> /tmp/$$.txt
echo "              db: DB tier OH. This is default type" >> /tmp/$$.txt
echo "              fmw_web: FMW Web tier OH" >> /tmp/$$.txt
echo "              fmw_common: FMW Common OH" >> /tmp/$$.txt
echo "              fmw_*: Other FMW OH (requires -oh parameter)" >> /tmp/$$.txt
echo "              wls: WebLogic OH" >> /tmp/$$.txt
echo "              oas|ias: OAS/IAS OH (example IAS_ORACLE_HOME under R12.0)" >> /tmp/$$.txt
echo "              forms: FORMS OH (example ORACLE_HOME under R12.0)" >> /tmp/$$.txt
echo "   -oh        For forcing ORACLE_HOME value." >> /tmp/$$.txt
echo "   -skipinventory If you want to skip the inventory check." >> /tmp/$$.txt
echo "                  Inventory is skipped default if -version or -platform" >> /tmp/$$.txt
echo "                  has been provided on command line." >> /tmp/$$.txt
#echo "   -clean Cleans up after successfull patch application." >> /tmp/$$.txt
#echo "          When patch has been successfully applied, patchdir" >> /tmp/$$.txt
#echo "          and patch zipfile will be deleted." >> /tmp/$$.txt
echo "   -mname Used for supplying metalink username."  >> /tmp/$$.txt
echo "          Should be used in conjunction with -mpass and -s"  >> /tmp/$$.txt
echo "   -mpass Used for supplying metalink password."  >> /tmp/$$.txt
echo "          Should be used in conjunction with -mname and -s"  >> /tmp/$$.txt
echo "   -apass Used for supplying apps password on commandline."  >> /tmp/$$.txt
echo "          Can be used in conjunction with silent mode"  >> /tmp/$$.txt
echo "   -spass Used for supplying system password on commandline."  >> /tmp/$$.txt
echo "          Can be used in conjunction with silent mode -s"  >> /tmp/$$.txt
echo "   -wpass Used for supplying WebLogic password on commandline."  >> /tmp/$$.txt
echo "          Can be used in conjunction with silent mode -s"  >> /tmp/$$.txt
echo "   -force Used for force applying a patch despite of conlicting patches."  >> /tmp/$$.txt
echo "          Using this option only has effect during apply, and it will"  >> /tmp/$$.txt
echo "   -notty Used for supplying patch without echo to screen."  >> /tmp/$$.txt
#echo "   -kill  Used for killing active patch sessions."  >> /tmp/$$.txt
echo "   -h     Help. Displays this usage section." >> /tmp/$$.txt
echo >> /tmp/$$.txt
echo "   EXAMPLES" >> /tmp/$$.txt
#echo "   Apply patch 123456:" >> /tmp/$$.txt
#echo "        $opatch_script_name -a 123456" >> /tmp/$$.txt
#echo >> /tmp/$$.txt
echo "   Check if patch 123456 has been applied:" >> /tmp/$$.txt
echo "        $opatch_script_name -c 123456" >> /tmp/$$.txt
echo >> /tmp/$$.txt
echo "   Download patch 123456 for platform LINUX and version 10105:" >> /tmp/$$.txt
echo "        $opatch_script_name -d 123456 -platform LINUX -version 10105" >> /tmp/$$.txt
echo >> /tmp/$$.txt
echo "   Rollback FORMS patch 123456 for current platform and version:" >> /tmp/$$.txt
echo "        $opatch_script_name -rollback 123456 -type forms" >> /tmp/$$.txt
echo >> /tmp/$$.txt
echo "   Apply WLS patch 123456 (MHJJ) for current platform and version:" >> /tmp/$$.txt
echo "        $opatch_script_name -a 123456:MHJJ -type wls" >> /tmp/$$.txt
echo "        NOTE: WebLogic 10.3.6 has additional 4 letter patch id for patches." >> /tmp/$$.txt
echo "        If a patch has a specific patchid, add it as <patch>:<ID>." >> /tmp/$$.txt
echo >> /tmp/$$.txt
#echo "   Apply patch 123456 with force option, provide tar number:" >> /tmp/$$.txt
#echo "        $opatch_script_name -a 123456 -force -tar 999999.999" >> /tmp/$$.txt
#echo >> /tmp/$$.txt
#echo "   Apply several patches in silent mode:" >> /tmp/$$.txt
#echo "        $opatch_script_name -a -b /oracle/apps/patchlist.txt -s" >> /tmp/$$.txt
#echo >> /tmp/$$.txt
echo "   INVALID SYNTAX" >> /tmp/$$.txt
echo "   Following syntax will be determined as invalid:" >> /tmp/$$.txt
echo "        $opatch_script_name -s " >> /tmp/$$.txt
echo "           -> The silent mode requires at least one run mode [-a|-c|-d|-r|-rollback]" >> /tmp/$$.txt
echo "        $opatch_script_name -a -c" >> /tmp/$$.txt
echo "           -> Only one run mode at a time is valid" >> /tmp/$$.txt
#echo "        $opatch_script_name -b /patch.txt" >> /tmp/$$.txt
#echo "           -> The batch mode requires at least one run mode [-a|-c|-d|-r|-info]" >> /tmp/$$.txt
echo >> /tmp/$$.txt
more /tmp/$$.txt
end_program
}

function source_environment
{
  if [[ $edition_based = yes ]];then
    ORIG_OPATCH_TOP=""
    source_edition=${1:-RUN}
    if [[ ! -z $OPATCH_TOP ]];then
      ORIG_OPATCH_TOP=$OPATCH_TOP
    fi
    if [[ -z $APPS_BASE ]];then 
      get_xml_value $CONTEXT_FILE s_base
      APPS_BASE=$xml_value
    fi
    if [[ -f $APPS_BASE/EBSapps.env ]];then 
      . $APPS_BASE/EBSapps.env $source_edition >/dev/null 2>&1
      get_xml_file
      set_environment_path
      if [[ $(grep s_fmw_home $XML_FILE|wc -l) -gt 0 ]];then
  	    get_xml_value $XML_FILE s_fmw_home 
  	    FMW_HOME=$xml_value
  	  fi
  	  if [[ $(grep s_wls_home $XML_FILE|wc -l) -gt 0 ]];then
  	    get_xml_value $XML_FILE s_wls_home 
  	    WLS_HOME=$xml_value
  	  fi
    else 
      xxecho "   Unable to source environment!"
      exit_program EnvironmentError
    fi
    if [[ ! -z $ORIG_OPATCH_TOP ]];then
      OPATCH_TOP=$ORIG_OPATCH_TOP
    fi
  fi
  
}

function set_environment_path
{
opatch_type=opatch
if [[ $tech_type != db ]];then
  if [[ -f $XML_FILE ]];then
    get_xml_value $XML_FILE s_apps_version 
    ebso_main_release=$(echo $xml_value|awk -F"." '{print $1$2}')
    if [[ $ebso_main_release = 122 ]];then    
      get_xml_value $XML_FILE s_wls_home 
      WLS_OHOME=$xml_value
      get_xml_value $XML_FILE s_fmw_home 
      FMW_HOME=$xml_value
      get_xml_value $XML_FILE s_weboh_oh 
      FMW_WEB_OHOME=$xml_value
      if [[ -d $FMW_HOME/oracle_common ]];then
        FMW_COMMON_OHOME=$FMW_HOME/oracle_common
      fi
    fi
    if [[ $(grep s_tools_oh $XML_FILE|wc -l) -gt 0 ]];then
      get_xml_value  $XML_FILE s_tools_oh 
      FORMS_OHOME=$xml_value
    fi
    if [[ $(grep s_weboh_oh $XML_FILE|wc -l) -gt 0 ]];then
      get_xml_value $XML_FILE s_weboh_oh 
      OAS_OHOME=$xml_value
    fi
  fi
  FORMS_OHOME=${FORMS_OHOME:-$TARGET_ORACLE_HOME}
  OAS_OHOME=${OAS_OHOME:-$TARGET_ORACLE_HOME}
  WLS_OHOME=${WLS_OHOME:-$WLS_HOME}
  WLS_OHOME=${WLS_OHOME:-$WL_HOME}
  if [[ $tech_type = wls ]];then
    if [[ -z $WLS_OHOME && ! -z $TARGET_ORACLE_HOME ]];then
      WLS_OHOME=$TARGET_ORACLE_HOME
    elif [[ ! -z $WLS_OHOME && -z $TARGET_ORACLE_HOME ]];then
      TARGET_ORACLE_HOME=$WLS_OHOME
    fi
  fi
  FMW_HOME=${FMW_HOME:-$MV_HOME}
  FMW_HOME=${FMW_HOME:-$(dirname $WLS_OHOME 2>/dev/null)}
  
  if [[ -z $TARGET_ORACLE_HOME ]];then
    case $tech_type in
      fmw_web)  if [[ ! -d $FMW_WEB_OHOME ]];then
                  if [[ -d $FMW_HOME/webtier ]];then 
                    FMW_WEB_OHOME=$FMW_HOME/webtier
                  elif [[ -d $FMW_HOME/ohs_111 ]];then 
                    FMW_WEB_OHOME=$FMW_HOME/ohs_111
                  elif [[ -d $FMW_HOME/ohs ]];then 
                    FMW_WEB_OHOME=$FMW_HOME/ohs
                  elif [[ -d $FMW_HOME/disco_111 ]];then 
                    FMW_WEB_OHOME=$FMW_HOME/disco_111
                  fi
                fi;;
      fmw_common) if [[ ! -d $FMW_COMMON_OHOME ]];then          
                    if [[ -d $FMW_HOME/oracle_common ]];then
                      FMW_COMMON_OHOME=$FMW_HOME/oracle_common
                    fi
                  fi;;
      fmw_ohs)  if [[ ! -d $FMW_OHS_OHOME ]];then          
                  if [[ -d $FMW_HOME/ohs ]];then 
                    FMW_OHS_OHOME=$FMW_HOME/ohs
                  elif [[ -d $FMW_HOME/ohs_111 ]];then 
                    FMW_OHS_OHOME=$FMW_HOME/ohs_111
                  fi
                fi;;
      fmw_disco)  if [[ ! -d $FMW_DISCO_OHOME ]];then          
                    if [[ -d $FMW_HOME/disco_111 ]];then 
                      FMW_DISCO_OHOME=$FMW_HOME/disco_111
                    fi
                  fi;;
    esac
  fi
  if [[ -d $FMW_HOME/utils/bsu ]];then
    BSU_LOC=$FMW_HOME/utils/bsu
  elif [[ -d $(dirname $WLS_OHOME 2>/dev/null)/utils/bsu ]];then
    BSU_LOC=$(dirname $WLS_OHOME)/utils/bsu
  elif [[ -d $TARGET_ORACLE_HOME/utils/bsu ]];then
    BSU_LOC=$TARGET_ORACLE_HOME/utils/bsu
  elif [[ -d $(dirname $TARGET_ORACLE_HOME 2>/dev/null)/utils/bsu ]];then
    BSU_LOC=$(dirname $$TARGET_ORACLE_HOME)/utils/bsu
  fi
  if [[ -z $TARGET_ORACLE_HOME ]];then
    case $tech_type in
      wls)  if [[ -d $BSU_LOC ]];then 
              opatch_type=bsu
            fi;;
      fmw_web)  TARGET_ORACLE_HOME=${FMW_WEB_OHOME:-$TARGET_ORACLE_HOME};;
      fmw_ohs)  TARGET_ORACLE_HOME=${FMW_OHS_OHOME:-$TARGET_ORACLE_HOME};;
      fmw_common) TARGET_ORACLE_HOME=${FMW_COMMON_OHOME:-$TARGET_ORACLE_HOME};;
      fmw_disco) TARGET_ORACLE_HOME=${FMW_DISCO_OHOME:-$TARGET_ORACLE_HOME};;
      fmw_*)    thome_name=$(echo $tech_type|tr '[a-z]' '[A-Z]')
                THOME=$(eval echo '$'${thome_name})
                TARGET_ORACLE_HOME=${THOME:-$TARGET_ORACLE_HOME};;
      oas|ias)  TARGET_ORACLE_HOME=${OAS_OHOME:-$TARGET_ORACLE_HOME};;
      forms)  TARGET_ORACLE_HOME=${FORMS_OHOME:-$TARGET_ORACLE_HOME};;
    esac
  fi
  if [[ -z $TARGET_ORACLE_HOME && $(echo $tech_type|awk -F"_" '{print $1}') = fmw ]];then
    thome_name=$(echo $tech_type|tr '[a-z]' '[A-Z]')
    THOME=$(eval echo '$'${thome_name})
    TARGET_ORACLE_HOME=$THOME
  fi
  reset_log_location
else
  TARGET_ORACLE_HOME=$ORACLE_HOME
fi

}

function get_pwd
{
line_statement
if (($password_status));then 
  if [[ $edition_based = yes ]];then
    appspwd=$apwd
    systempwd=$spwd
    wlspwd=$wpwd
    while true;do
    	if [[ -z $appspwd || -z $systempwd ]]||[[ -z $wlspwd && $skip_wls_pwd = no ]];then
    	  password_status=1
    		if [[ -z $appspwd ]];then
    			get_response "Please enter APPS password: " "silent"
    			appspwd=$response
    		fi
    		if [[ -z $systempwd ]];then
    			get_response "Please enter SYSTEM password: " "silent"
    			systempwd=$response
    		fi
    	fi
    	if [[ -z $wlspwd && $skip_wls_pwd = no ]];then
    		get_response "Please enter WLS admin password: " "silent"
    		wlspwd=$response
    	fi
    	xxecho
    	check_passwords all
    	if ((!$?));then
    		break
    	fi
    done
  else
    systempwd=$spwd
    while true;do
    	if [[ -z $systempwd ]];then
    		get_response "Please enter SYSTEM password: " "silent"
    		systempwd=$response
    		xxecho
    	fi
    	check_passwords system
    	if ((!$?));then
    		break
    	fi
    done
  fi
fi
create_pfile
}


function get_system_pwd
{
if [[ $edition_based = yes ]]&&((!$dbtier));then
  appspwd=$(decrypt_pwd "" ACRYPT)
  wlspwd=$(decrypt_pwd "" WCRYPT)
fi
systempwd=$(decrypt_pwd "" SCRYPT)
}


# Parameter 1 is name of patch_list file
# Parameter 2 is optional grep list
function update_lang_list
{
patch_list_file=$1
grep_param="${2:-"$patchnumber"}"
mv $patch_list_file $logdir/temp_patch_list 2>/dev/null
touch $patch_list_file
for list_item in $(cat $logdir/temp_patch_list 2>/dev/null);do
	if [[ $(echo $list_item|grep "$grep_param"|wc -l) -eq 0 ]];then
		echo "$list_item" >> $patch_list_file
	fi
done
count_total_plist=$(cat $logdir/temp_patch_list 2>/dev/null|wc -l)
if [[ $run_mode = silent ]]&&[[ $count_plist -gt 1 ]];then
	xxecho
	xxecho "   Not able to apply multiple patches in silent mode ..."
	exit_program ParameterError
fi

}

function get_expect_exe
{
if [[ -z $expect_exe ]];then
  if [[ -f /usr/local/bin/expect ]];then
  	expect_exe=/usr/local/bin/expect
  elif [[ -f /usr/bin/expect ]];then
  	expect_exe=/usr/bin/expect
  elif [[ -f /usr/sbin/expect ]];then
  	expect_exe=/usr/sbin/expect
  elif [[ -f $(which expect 2>/dev/null) ]];then
  	expect_exe=$(which expect 2>/dev/null)
  fi
  if [[ ! -f $expect_exe ]]&&[[ -d $ODCODE_TOP/expect ]];then
    PLATFORM=`uname`
    OSRELEASE=`uname -r`
    expect_base_dir=$OHSUPG_TOP/expect
    TCL_LIBRARY="$expect_base_dir/library"
    case "$PLATFORM" in
    	'Linux')	expect_dir=$ODCODE_TOP/expect/Linux;;
    	'OSF1') # Get the two first letters of the release string
    			osfrel=${OSRELEASE%"${OSRELEASE#??}"}
    			expect_dir=$ODCODE_TOP/expect/OSF1/$osfrel;;
    	'SunOS')	expect_dir=$ODCODE_TOP/expect/Solaris;;
    	'HP-UX')	expect_dir=$ODCODE_TOP/expect/HP-UX
    				SHLIB_PATH=$SHLIB_PATH:"$expect_dir/library"
    				export SHLIB_PATH
    				TCL_LIBRARY="$expect_dir/library";;
    	'AIX')	VERSION=`uname -v`
    			expect_dir=$ODCODE_TOP/expect/AIX${VERSION}
    			LIBPATH=$LIBPATH:"$expect_dir"	
    			export LIB_PATH;;
    esac
    PATH=$PATH:$expect_dir
    export PATH
    LD_LIBRARY_PATH=$LD_LIBRARY_PATH:"$expect_dir"
    export LD_LIBRARY_PATH
    export TCL_LIBRARY
    expect_exe=$expect_dir/expect
    if [[ $DeBug -gt 0 ]];then
    	expect_exe="$expect_exe -d"
    fi
  fi
  if [[ ! -f $expect_exe && $protocol = FTP && ! -f $sshkey ]];then
    protocol=HTTP
  fi
fi	
 }

function create_pfile
{
line_statement
xxecho "   Creating encrypted password file..."
running_statement "Creating encrypted password file"
rm $ep_file 2>/dev/null
if [[ $edition_based = yes ]]&&((!$dbtier));then
  encrypt_pwd "$appspwd" ACRYPT
  ep_status=$?
  encrypt_pwd "$systempwd" SCRYPT
  ((ep_status+=$?))
  if [[ ! -z $wlspwd ]];then
    encrypt_pwd "$wlspwd" WCRYPT
	  ((ep_status+=$?))
  fi
else 
  encrypt_pwd "$systempwd" SCRYPT
  ep_status=$?
fi
chmod 600 $ep_file 2>/dev/null
status_statement "Creating encrypted password file" $ep_status
if (($?));then
	echo
	echo "   Encrypted password file failed to be created."
	exit_program PasswordError
fi
xxecho
epfile_created=yes
}

function check_passwords
{
if ((!$password_status));then 
  return 0
fi
exit_check=N
checkpwd=$1
apps_statement=""
system_statement=""
wls_statement=""
xxecho "   Checking database connection password(s)..."
if [[ $checkpwd = apps || $checkpwd = all ]];then
	running_statement "Checking <APPS> password"
	if [[ -z $appspwd ]];then
		format_statement "Checking <APPS> password" "invalid  "
		apps_statement="      <APPS> password not set."
		exit_check=Y
	else
		run_sql "apps/$appspwd" "appspwd_check.log" "select * from dual;" "1"
		exit_check_error=$?
		if [[ $exit_check_error -eq 1 ]];then
			format_statement "Checking <APPS> password" "invalid  "
			apps_statement="      Invalid <APPS> password specified!"
			exit_check=Y
		elif (($exit_check_error));then
			format_statement "Checking <APPS> password" "failed  "
			exit_case $exit_check_error
			exit_program ConnectError
		else
			format_statement "Checking <APPS> password" "valid   "
		fi
	fi
fi
if [[ $checkpwd = system || $checkpwd = all ]];then
	running_statement "Checking <SYSTEM> password"
	if [[ -z $systempwd ]];then
		format_statement "Checking <SYSTEM> password" "invalid  "
		system_statement="      <SYSTEM> password not set."
		exit_check=Y
	else
		run_sql "system/$systempwd" "systempwd_check.log" "select * from dual;"  "1"
		exit_check_error=$?
		if [[ $exit_check_error -eq 1 ]];then
			format_statement "Checking <SYSTEM> password" "invalid  "
			system_statement="      Invalid <SYSTEM> password specified!"
			exit_check=Y
		elif (($exit_check_error));then
			format_statement "Checking <SYSTEM> password" "failed  "
			exit_case $exit_check_error
			exit_program ConnectError
		else
			format_statement "Checking <SYSTEM> password" "valid   "
		fi
	fi
fi
if [[ $checkpwd = wls || $checkpwd = all ]]&&[[ $skip_wls_pwd = no ]];then
	running_statement "Checking <WLS> password"
	if [[ -z $wlspwd ]];then
		format_statement "Checking <WLS> password" "invalid  "
		wls_statement="      <WLS> password not set."
		exit_check=Y
	else
    rm -f	$logdir/check_wls_pwd.log 2>/dev/null
		{ echo $wlspwd; } | perl $AD_TOP/patch/115/bin/adProvisionEBS.pl ebs-get-serverstatus -contextfile=$CONTEXT_FILE -servername=AdminServer -promptmsg=hide -logfile=$logdir/check_wls_pwd.log >/dev/null 2>&1
		exit_check_error=$?
		if [[ $exit_check_error -eq 9 || $(grep "Invalid credentials" $logdir/check_wls_pwd.log|wc -l) -gt 0 ]];then
			format_statement "Checking <WLS> password" "invalid  "
			wls_statement="      Invalid <WLS> password specified!"
			exit_check=Y
    elif [[ $(grep "not running" $logdir/check_wls_pwd.log|wc -l) -gt 0 ]];then
			format_statement "Checking <WLS> password" "failed  "
      exit_case 10
			exit_program ConnectError
		elif (($exit_check_error));then
			format_statement "Checking <WLS> password" "failed  "
			exit_case 11
			exit_program ConnectError
		else
			format_statement "Checking <WLS> password" "valid   "
		fi
	fi
fi
if [[ $exit_check = Y ]];then
	xxecho
	if [[ ! -z $apps_statement ]];then
		xxecho "$apps_statement"
		appspwd=""
	fi
	if [[ ! -z $system_statement ]];then
		xxecho "$system_statement"
		systempwd=""
	fi
	if [[ ! -z $wls_statement ]];then
		xxecho "$wls_statement"
		wlspwd=""
	fi
	exit_check_error=1
	if [[ $run_mode = silent ]];then
		if [[ -z $apwd || -z $spwd ]]||[[ -z $wpwd && $skip_wls_pwd = no ]];then
			exit_program PasswordError
		fi
		appspwd=$apwd
		systempwd=$spwd
		wlspwd=$wpwd
	fi
	xxecho
fi
password_status=$exit_check_error
return $exit_check_error
}



function get_xml_value
{
xml_file=$1
xml_tag=$2
xml_value=""
tag_status=invalid
if [[ -f $xml_file ]];then
	if [[ $(grep "\"$xml_tag\"" $xml_file|wc -l) -gt 0 ]];then
		xml_value=$(grep "\"$xml_tag\"" $xml_file|awk -F">" '{print $2}'|awk -F"<" '{print $1}')
		tag_status=valid
	fi		
else
	return 1
fi
}

function check_environment
{
	# Create pfile if missing
	if [[ $db_connect = yes ]];then
    if [[ $edition_based = yes ]]&&((!$dbtier));then
     	source_environment RUN
    fi
		if [[ ! -r $ep_file ]];then
			get_pwd
			echo
		fi
		get_system_pwd
  	if (($password_status));then
      if [[ $edition_based = yes ]]&&((!$dbtier));then 
        check_passwords all
        pwd_check_status=$?
      else 
        check_passwords system
        pwd_check_status=$?
      fi
  		if (($pwd_check_status));then
  			xxecho
  			xxecho "   The encrypted passwords in password file is not corresponding "
  			xxecho "   to your present environment."
				if [[ $epfile_created = no ]];then
    			running_statement "Deleting encrypted password file"
    		  rm -f $ep_file > /dev/null 2>&1
    			status_statement "Deleting encrypted password file" "completed"
		    fi
  			get_pwd
  		else
  			xxecho
  		fi
  	fi
    if [[ $edition_based = yes ]]&&((!$dbtier));then
      check_edition_information
      xxecho
     	if [[ $target_edition = PATCH ]];then 
        source_environment PATCH
      fi
    fi
	fi

	case $patch_option in
	readonly|download|apply|verify|check|rollback)	
		if [[ -z $OPATCH_TOP ]]; then
		  if [[ ! -z $PATCH_TOP ]];then 
		    OPATCH_TOP=$PATCH_TOP
		  else
  			xxecho "   The OPATCH_TOP parameter has not been set."
  			xxecho "   Please set your OPATCH_TOP environment parameter to point to your current"
  			xxecho "   base patch directory:"
  			xxecho "   export OPATCH_TOP=<full path to patch directory>"
  			xxecho
  			xxecho "   You would probably want to add this environment variable to"
  			xxecho "   your '.profile' file or set it up in adovars.env"
  			exit_program PatchTopError
  		fi
		fi
		
		# Check if OPATCH_TOP directory is valid
		if [[ ! -d $OPATCH_TOP ]]; then
			xxecho "   Base Patch directory does not exist: "
			xxecho "   '$OPATCH_TOP' is not a valid path"
			xxecho "   Please set your OPATCH_TOP environment parameter to point to a valid"
			xxecho "   base patch directory:"
			xxecho "   export OPATCH_TOP=<full path to patch directory>"
			xxecho
			xxecho "   You would probably want to add this environment variable to"
			xxecho "   your '.profile' file or set it up in adovars.env"
			exit_program PatchTopError
		else
			touch $OPATCH_TOP/dummy > /dev/null 2>&1
			if [[ -r $OPATCH_TOP/dummy ]]; then
				rm -f $OPATCH_TOP/dummy > /dev/null 2>&1
			else
				xxecho "   Base patch directory (OPATCH_TOP) is not writeable."
				xxecho "   Please make sure that '$OPATCH_TOP' is writeable by"
				xxecho "   the Applications UNIX account, or that the OPATCH_TOP environment"
				xxecho "   parameter is redefined to another writeable directory."
				exit_program PatchTopError
			fi
		fi
		if [[ -d /autofs/upgrade/ebso/linux/TECH_PATCHES ]]&&[[ ! -d $OPATCH_STAGE ]];then
      OPATCH_STAGE="/autofs/upgrade/ebso/linux/TECH_PATCHES"
      export OPATCH_STAGE
		fi
    if [[ -d $OPATCH_STAGE ]]&&[[ -r $OPATCH_STAGE ]];then
			OPATCH_STAGE_ZIP=$OPATCH_STAGE
			if [[ ! -w $OPATCH_STAGE ]]&&[[ $patch_option != download_zip ]];then
				OPATCH_STAGE=$OPATCH_TOP
			fi
		else
			OPATCH_STAGE=$OPATCH_TOP
			OPATCH_STAGE_ZIP=$OPATCH_TOP
		fi;;
	esac
}

function set_edition_information
{
  edition_name=$1
  edition_check=$2
  edition_node_info=""
  if [[ -z $(eval echo '$'${edition_name}_status) ]];then 
    eval ${edition_name}_status=0
    eval ${edition_name}_node=""
    eval ${edition_name}_host_status=0
  fi
  if [[ $(echo "$edition_check"|grep "$(eval echo '$'${edition_name}_info)"|wc -l) -eq 0 ]];then 
    eval ${edition_name}_status=1
    if [[ -z $(eval echo '$'${edition_name}_node) ]];then
      eval ${edition_name}_node="$node_info" 
    else
      eval ${edition_name}_node="$(eval echo '$'${edition_name}_node)!$node_info" 
    fi
    if [[ $HOST_NAME = $(echo $node_info|awk -F":" '{print $2}') ]];then 
      eval ${edition_name}_host_status=1
    fi
  fi 
}


function check_edition_information
{
if [[ $edition_based = yes ]]&&((!$dbtier));then
	# Check enough disk space in DB (SYSTEM 25 GB free, APPS_TS_SEED 5 GB free)
	# Check if db is edition enabled
	# Check if patch service (!) has been created
	# Check if logon trigger enabled
	edition_critical=0
	edition_warning=0
  adop_failed=0
  adop_running=0
  adop_failures=0
  current_phase_status=""
  current_phase_completed=0
  edition_type_error=ReadyForAction
	xxecho "   Checking edition based information..."
	running_statement "Checking edition based requirements"
	get_xml_value $XML_FILE s_patch_service_name
	patch_service_name=$xml_value
	run_sql "apps/$appspwd" "check_edition_environment.log" "select 'EDITION_ENABLED!'||count(*)||'!'
	  from dba_users where username='APPS' and EDITIONS_ENABLED='Y';
	  select 'LOGON_TRIGGER!'||count(*)||'!' from dba_triggers 
	  where owner='SYSTEM' and TRIGGER_NAME='EBS_LOGON' and status='ENABLED';
	  select 'PATCH_ED_ENABLED!'||count(*)||'!' from all_editions aed
      where aed.parent_edition_name = (select property_value from database_properties 
  	    where property_name = 'DEFAULT_EDITION');
	  select 'PATCH_SERVICE!'||count(*)||'!' from dba_services where lower(name)='ebs_patch'
	  or upper(name) = '${ENV_NAME}_EBS_PATCH' or name='$patch_service_name';
	  SELECT 'TBS_FREE_SIZE!'||fs.tablespace_name||'!'||fs.free_space||'!'||replace(fs.tablespace_name,(select tablespace from fnd_tablespaces where TABLESPACE_TYPE='REFERENCE'),'REFERENCE')||'!'
    FROM
      ( SELECT tablespace_name, round(SUM(bytes/1024/1024/1024),0) FREE_SPACE
          FROM dba_free_space
          GROUP BY tablespace_name) fs
    WHERE fs.tablespace_name in
      ('SYSTEM', (select tablespace from fnd_tablespaces where TABLESPACE_TYPE='REFERENCE' ))
    ORDER BY fs.tablespace_name;
    --select 'RUN_PATCH_EDITION!'||aed.edition_name||'!'||ad_zd.get_edition_type(aed.edition_name)||'!'
    --from all_editions aed where ad_zd.get_edition_type(aed.edition_name) in ('RUN','PATCH');"
	edition_enabled=$(grep EDITION_ENABLED $logdir/check_edition_environment.log|awk -F"!" '{print $2}')
	edition_enabled=${edition_enabled:-0}
	logon_trigger_enabled=$(grep LOGON_TRIGGER $logdir/check_edition_environment.log|awk -F"!" '{print $2}')
	logon_trigger_enabled=${logon_trigger_enabled:-0}
	patch_service_enabled=$(grep PATCH_SERVICE $logdir/check_edition_environment.log|awk -F"!" '{print $2}')
	patch_service_enabled=${patch_service_enabled:-0}
	system_free=$(grep TBS_FREE_SIZE $logdir/check_edition_environment.log|grep "SYSTEM"|awk -F"!" '{print $3}')
	reference_free=$(grep TBS_FREE_SIZE $logdir/check_edition_environment.log|grep "REFERENCE"|awk -F"!" '{print $3}')
	reference_tbs=$(grep TBS_FREE_SIZE $logdir/check_edition_environment.log|grep "REFERENCE"|awk -F"!" '{print $2}')
	patch_edition_active=$(grep PATCH_ED_ENABLED $logdir/check_edition_environment.log|awk -F"!" '{print $2}')
  #patch_edition=$(grep RUN_PATCH_EDITION $logdir/check_edition_environment.log|grep "!PATCH!"|awk -F"!" '{print $2}')
  #run_edition=$(grep RUN_PATCH_EDITION $logdir/check_edition_environment.log|grep "!RUN!"|awk -F"!" '{print $2}')
  adop_failures=0
  cutover_completed=0
  prepare_completed=0
	if (($edition_enabled))&&(($logon_trigger_enabled))&&(($patch_service_enabled));then
  	run_sql "apps/$appspwd" "check_adop_status.log" "WHENEVER OSERROR EXIT FAILURE ROLLBACK;
      WHENEVER SQLERROR EXIT FAILURE ROLLBACK;

      VARIABLE g_clone_at_next_s number;
      VARIABLE report_session_id NUMBER
      begin
        :g_clone_at_next_s := 0;
      end;
/

      declare
        l_session_id         number;
        l_session_id_patches number;
        l_bug_number         varchar2(30);
        
      begin
          begin
             select max(adop_session_id) into l_session_id from ad_adop_sessions;
          exception
            when others then
             RAISE_APPLICATION_ERROR (-20001, 'No Session ID found.');
          end;

          begin
              select max(adop_session_id) into l_session_id_patches from ad_adop_session_patches
                     where bug_number in ('CLONE','CONFIG_CLONE');
              if (l_session_id_patches > l_session_id) then
                   :g_clone_at_next_s := 1;
                   :report_session_id := l_session_id_patches;
              elsif (l_session_id_patches = l_session_id) then
                   :report_session_id := l_session_id_patches;
              else
                   :report_session_id := l_session_id;
              end if;
          exception
            when others then
              :report_session_id := l_session_id;
          end;
      end;
/
      DEFINE s_report_session_id = 0;
      COLUMN SESSION_ALIAS NEW_VALUE s_report_session_id NOPRINT
      select TRIM(:report_session_id) SESSION_ALIAS from dual;

      DEFINE s_clone_at_next_s =0;
      COLUMN REPORT_ALIAS NEW_VALUE s_clone_at_next_s NOPRINT
      select TRIM(:g_clone_at_next_s) REPORT_ALIAS from dual;
      
      select 'ADOP_STATUS!EDITION!NOT_STARTED!$HOST_NAME!' STATUS from dual
        where not exists (select '1' from ad_adop_sessions
        where adop_session_id = &s_report_session_id);

      select 'ADOP_STATUS!ABORT!NOT_APPLICABLE!$HOST_NAME!' STATUS from dual
        where not exists (select '1' from ad_adop_sessions
        where adop_session_id = &s_report_session_id
        and &s_clone_at_next_s=0);
        
      select 'ADOP_STATUS!FS_CLONE!NOT_APPLICABLE!$HOST_NAME!' STATUS from dual
        where not exists (select '1' from ad_adop_session_patches ap
          where ap.adop_session_id = &s_report_session_id
          and ap.session_type in ('CLONE','CONFIG_CLONE')
          and ap.clone_status is not null
          and not exists (select '1' from ad_adop_sessions aas where aas.adop_session_id=ap.adop_session_id
          and aas.adop_session_id = ap.adop_session_id
          and abort_status='Y' and aas.ABORT_END_DATE > ap.end_date
          and ap.node_name=aas.node_name));

      select 'ADOP_STATUS!PREPARE!NOT_APPLICABLE!$HOST_NAME!' STATUS from dual
       where not exists (select '1' from ad_adop_sessions
          where adop_session_id = &s_report_session_id
          and &s_clone_at_next_s=0);
        
      select 'ADOP_STATUS!APPLY!NOT_APPLICABLE!$HOST_NAME!' STATUS from dual   
       where not exists (select '1' from ad_adop_sessions
          where adop_session_id = &s_report_session_id
          and &s_clone_at_next_s=0);   
        
      select  'ADOP_STATUS!CUTOVER!NOT_APPLICABLE!$HOST_NAME!' STATUS from dual   
       where not exists (select '1' from ad_adop_sessions
          where adop_session_id = &s_report_session_id
          and &s_clone_at_next_s=0);     
        
      select 'ADOP_STATUS!CLEANUP!NOT_APPLICABLE!$HOST_NAME!' STATUS from dual   
        where not exists (select '1' from ad_adop_sessions
           where adop_session_id = &s_report_session_id
           and &s_clone_at_next_s=0);
        
      select 'ADOP_STATUS!FINALIZE!!NOT_APPLICABLE!$HOST_NAME!' STATUS from dual   
        where not exists (select '1' from ad_adop_sessions
          where adop_session_id = &s_report_session_id
          and &s_clone_at_next_s=0);

      select 'ADOP_STATUS!EDITION!'||
          (case
            when status='C' then 'COMPLETED!'||node_name||'!'
            when status='F' then
              case
                 when abandon_flag is null then 'ABANDONED!'||node_name||'!'
              else
                 'FAILED!'||node_name||'!'
              end
            when status='R' then 'RUNNING!'||node_name||'!'
            when status='N' then 'NOT_STARTED!'||node_name||'!'
            when status='X' then 'NOT_STARTED!'||node_name||'!'
          end) STATUS  
        from ad_adop_sessions
        where adop_session_id = &s_report_session_id;

        select 'ADOP_STATUS!ABORT!'|| 
          (case
            when abort_status='Y' then 'COMPLETED!'||node_name||'!'
            when abort_status='R' and status='F' then
              case
                 when abandon_flag is null then 'ABANDONED!'||node_name||'!'
              else
                 'FAILED!'||node_name||'!'
              end
            when abort_status='R' then 'RUNNING!'||node_name||'!'
            when abort_status='N' then 'NOT_STARTED!'||node_name||'!'
            when abort_status='X' then 'NOT_APPLICABLE!'||node_name||'!'
          end) STATUS
        from ad_adop_sessions
        where adop_session_id = &s_report_session_id
          and &s_clone_at_next_s=0;
      select 'ADOP_STATUS!FS_CLONE!'||
        (case
          when ap.status='Y' and ap.clone_status = 'COMPLETED' then 'COMPLETED!'||node_name||'!'
          when ap.status='F' and ap.clone_status <> 'COMPLETED' then 'FAILED!'||node_name||'!'
          when ap.status='R' and ap.clone_status <> 'COMPLETED' then 'RUNNING!'||node_name||'!'
          when ap.status='N' and ap.clone_status in ('NOT STARTED','NOT-STARTED') then 'NOT_STARTED!'||node_name||'!'
          when ap.status='X' then 'NOT_APPLICABLE!'||node_name||'!'
        end) STATUS
        from ad_adop_session_patches ap
           where ap.adop_session_id = &s_report_session_id
           and ap.session_type in ('CLONE','CONFIG_CLONE')
           and ap.clone_status is not null
           and not exists (select '1' from ad_adop_sessions aas where aas.adop_session_id=ap.adop_session_id
           and aas.adop_session_id = ap.adop_session_id
           and abort_status='Y' and aas.ABORT_END_DATE > ap.end_date
           and ap.node_name=aas.node_name);
        select 'ADOP_STATUS!PREPARE!'||
          (case
            when abort_status='Y' then 'ABORTED!'||node_name||'!'
            else
              case
                when prepare_status='Y' then 'COMPLETED!'||node_name||'!'
                when prepare_status='R' and status='F' then
                  case
                      when abandon_flag is null then 'ABANDONED!'||node_name||'!'
                  else
                     'FAILED!'||node_name||'!'
                  end
                when prepare_status='R' then 'RUNNING!'||node_name||'!'
                when prepare_status='N' then 'NOT_STARTED!'||node_name||'!'
                when prepare_status='X' then 'NOT_APPLICABLE'||node_name||'!'
              end
          end) STATUS
        from ad_adop_sessions
        where adop_session_id = &s_report_session_id
          and &s_clone_at_next_s =0;
        select 'ADOP_STATUS!APPLY!'||
          (case
            when abort_status='Y' then 'ABORTED!'||node_name||'!'
            else
              case
                when apply_status='Y' and cutover_status<>'N' then 'COMPLETED!'||node_name||'!'
                when apply_status='P' and cutover_status in ('N','X') and
                     prepare_status in ('Y','X') and status='F' then
                    case
                        when abandon_flag is null then 'ABANDONED!'||node_name||'!'
                    else
                       'FAILED!'||node_name||'!'
                    end
                when apply_status='P' and cutover_status in ('N','X') and
                     prepare_status in ('Y','X') and status='R' then 'RUNNING!'||node_name||'!'
                when apply_status='N' then 'NOT_STARTED!'||node_name||'!'
                else
                  'ACTIVE!'||node_name||'!'
              end
          end) STATUS
        from ad_adop_sessions
        where adop_session_id = &s_report_session_id and &s_clone_at_next_s =0;
        select  'ADOP_STATUS!CUTOVER!'||
          (case
            when abort_status='Y' then 'ABORTED!'||node_name||'!'
            else
              case
                when cutover_status='Y' then 'COMPLETED!'||node_name||'!'
                when cutover_status not in ('N','Y','X') and status='F' then
                    case
                        when abandon_flag is null then 'ABANDONED!'||node_name||'!'
                    else
                       'FAILED!'||node_name||'!'
                    end
                when cutover_status not in ('N','Y','X') and status='R' then 'RUNNING!'||node_name||'!'
                when cutover_status='N' then 'NOT_STARTED!'||node_name||'!'
                when cutover_status='X' then 'NOT_APPLICABLE!'||node_name||'!'
              end
          end) STATUS
        from ad_adop_sessions
        where adop_session_id = &s_report_session_id
          and &s_clone_at_next_s =0;
        select 'ADOP_STATUS!CLEANUP!'||
          (case
            when cleanup_status='Y' then 'COMPLETED!'||node_name||'!'
            when prepare_status in ('Y','X') and apply_status='Y' 
              and cutover_status in ('Y','X') and cleanup_status='N' and status='F' then 'FAILED!'||node_name||'!'
            when prepare_status in ('Y','X') and apply_status='Y' 
              and cutover_status in ('Y','X') and cleanup_status='N' and status='R' then 'RUNNING!'||node_name||'!'
           else
              'NOT_STARTED!'||node_name||'!'
          end) STATUS
        from ad_adop_sessions
        where adop_session_id = &s_report_session_id  and &s_clone_at_next_s =0;
        select 'ADOP_STATUS!FINALIZE!'||
          (case
            when abort_status='Y' then 'ABORTED!'||node_name||'!'
            else
              case
                when finalize_status='Y' then 'COMPLETED!'||node_name||'!'
                when prepare_status ='Y' and apply_status in ('N','P','Y') and finalize_status='R' and status='F' then
                    case
                        when abandon_flag is null then 'ABANDONED!'||node_name||'!'
                    else
                       'FAILED!'||node_name||'!'
                    end
                when prepare_status ='Y' and apply_status in ('N','P','Y') and finalize_status='R' and status='R' then 'RUNNING!'||node_name||'!'
                when finalize_status ='X' then 'NOT_APPLICABLE!'||node_name||'!'
                else
                  'NOT_STARTED!'||node_name||'!'
              end
          end) STATUS
        from ad_adop_sessions
        where adop_session_id = &s_report_session_id 
          and &s_clone_at_next_s =0 ;" 
    for adop_phase_type in $(echo "fs_clone prepare cutover abort");do
      adop_phase_UC=$(echo $adop_phase_type|tr '[a-z]' '[A-Z]')
      adop_phase_status=""
      for adop_phase_stats in $(echo "FAILED RUNNING ABORTED ABANDONED NOT_STARTED COMPLETED NOT_APPLICABLE");do 
        adop_phase_status=$(grep "ADOP_STATUS!$adop_phase_UC!$adop_phase_stats!" $logdir/check_adop_status.log|grep -v select 2>/dev/null|awk -F"!" '{print $3}'|sort -u)
        if [[ ! -z $adop_phase_status ]];then
          break
        fi
      done
      #adop_phase_status=$(grep "ADOP_STATUS!$adop_phase_UC!" $logdir/check_adop_status.log|grep -v select 2>/dev/null|awk -F"!" '{print $3}')
      adop_phase_status=${adop_phase_status:-UNKNOWN}
      eval ${adop_phase_type}_status=$adop_phase_status
      case $adop_phase_type in
        fs_clone|prepare|abort) case $adop_phase_status in
                                            COMPLETED) eval ${adop_phase_type}_completed=1;;
                                            *)  eval ${adop_phase_type}_completed=0;;
                                          esac;;
        cutover) case $adop_phase_status in
                            COMPLETED|ABORTED) eval ${adop_phase_type}_completed=1;;
                            *)  eval ${adop_phase_type}_completed=0;;
                          esac;;
      esac
      if [[ $adop_phase_status = FAILED ]];then
        ((adop_failures+=1))
        failed_adop=$adop_phase_type
      fi
      if [[ $adop_phase_status = RUNNING ]];then
        ((adop_running+=1))
        running_adop=$adop_phase_type
      fi
    done
    if (($adop_running));then
      adop_action=exit
      edition_critical=1
    elif (($adop_failures));then
      adop_action=exit
      edition_critical=1
      edition_type_error=OtherAdopFailedCrit
    fi
  else
    adop_action=exit
    edition_critical=1
  fi
  case $patch_option in 
    apply|rollback)    if [[ $target_edition = PATCH ]];then
                if ((!$prepare_completed))||((!$patch_edition_active));then
                  adop_action=exit
                  edition_type_error=EditionNotPrepared
                fi
              else
                if (($patch_edition_active));then
                  adop_action=exit
                  edition_type_error=EditionNotCutover
                fi
              fi;;  
    *)    if [[ $target_edition = PATCH ]];then
                if ((!$prepare_completed))||((!$patch_edition_active));then
                  adop_action=warning
                  edition_type_error=EditionNotPrepared
                fi
              else
                if (($patch_edition_active));then
                  adop_action=warning
                  edition_type_error=EditionNotCutover
                fi
              fi;;  
  esac
  edition_status=$(echo "$edition_critical $edition_warning + pq"|dc)
  if (($edition_critical));then
    status_statement "Checking edition based requirements" $edition_critical
  elif (($edition_warning));then
    format_statement "Checking edition based requirements" "warning"
  else
    status_statement "Checking edition based requirements" $edition_status
  fi
  if [[ $adop_action = exit ]];then 
    xxecho
		xxecho "   --------------------------  EDITION CRITICAL  ---------------------------"
    if ((!$edition_enabled));then 
      xxecho "      Database schemas have not been enabled for editioning!" 
      xxecho "      Please ensure to enable schemas for editioning prior to applying patches!"
      edition_type_error=BaselineEditionError
    elif ((!$logon_trigger_enabled));then
      xxecho "      EBS_LOGON trigger has not been created/enabled!" 
      xxecho "      Please ensure to enable EBS_LOGON trigger prior to applying patches!"
      edition_type_error=BaselineEditionError
    elif ((!$patch_service_enabled));then
      xxecho "      Patching Service has not been created!" 
      xxecho "      Please ensure to create patching service 'EBS_PATCH' prior to applying patches!"
      edition_type_error=BaselineEditionError
    elif [[ $edition_type_error = EditionNotPrepared ]];then
      xxecho "      PATCH edition has not been created/existing!" 
      case $patch_option in
        apply|rollback)  xxecho "      Please ensure to run adop phase=prepare before applying patches!"
                xxecho "      Alternately use following syntax on main MT: "
                xxecho "      apatch.sh -adop prepare"
                xxecho
                xxecho "      If you want to $patch_option patches on RUN edition, force the"
                xxecho "      edition using -edition RUN";;
      esac
    elif [[ $edition_type_error = EditionNotCutover ]];then
      xxecho "      PATCH edition is active and has not been cutover!" 
      case $patch_option in
        apply|rollback)  xxecho "      Please ensure to run adop phase=cutover/abort before applying patches"
                xxecho "      in RUN edition!"
                xxecho "      Alternately use following syntax on main MT:"
                xxecho "      apatch.sh -adop [cutover|abort]"
                xxecho
                xxecho "      If you want to $patch_option patches on PATCH edition, force the"
                xxecho "      edition using -edition PATCH";;
      esac
    elif [[ $edition_type_error = OtherAdopFailedCrit ]];then
		  xxecho "      An ADOP run failed [phase=$failed_adop]!"
      xxecho "      Please ensure to complete any adop sessions before"
      xxecho "      $patch_option of patches."
    elif (($adop_running));then
      xxecho "      Running adop session detected [phase=$running_adop]." 
      xxecho "      Please ensure to complete any running adop sessions before"
      xxecho "      $patch_option of patches."
      edition_type_error=EditionInProgressError
    fi
 		xxecho "   -------------------------------------------------------------------------"
 		exit_program $edition_type_error
 	elif [[ $adop_action = warning ]];then
    xxecho
 		xxecho "   --------------------------  EDITION WARNING  ----------------------------"
		if [[ $edition_type_error = EditionNotPrepared ]];then
      xxecho "      PATCH edition has not been created/existing!" 
      xxecho "      However the PATCH edition has been sourced for $patch_option."
      xxecho
      xxecho "      If you want to $patch_option patches on RUN edition, force the"
      xxecho "      edition using -edition RUN"
		elif [[ $edition_type_error = EditionNotCutover ]];then
      xxecho "      PATCH edition is active and has not been cutover!" 
      xxecho "      However the RUN edition has been sourced for $patch_option."
      xxecho
      xxecho "      If you want to $patch_option patches on PATCH edition, force the"
      xxecho "      edition using -edition PATCH"
    fi
		xxecho "   --------------------------  EDITION WARNING  ----------------------------"
    xxecho
    yes_no "   Do you wish to continue $patch_option on $target_edition edition? [N]: " "N" "ignore"
    if (($?));then 
      exit_program $edition_type_error
    fi     
    xxecho
  fi
fi
}


#function check_edition_information
#{
#if [[ $edition_based = yes ]]&&((!$dbtier));then
#	# Check enough disk space in DB (SYSTEM 25 GB free, APPS_TS_SEED 5 GB free)
#	# Check if db is edition enabled
#	# Check if patch service (!) has been created
#	# Check if logon trigger enabled
#	edition_critical=0
#	edition_warning=0
#	xxecho "   Checking edition based information..."
#	running_statement "Checking edition based requirements"
#	get_xml_value $XML_FILE s_patch_service_name
#	patch_service_name=$xml_value
#	run_sql "apps/$appspwd" "check_edition_environment.log" "select 'EDITION_ENABLED!'||count(*)||'!'
#	  from dba_users where username='APPS' and EDITIONS_ENABLED='Y';
#	  select 'LOGON_TRIGGER!'||count(*)||'!' from dba_triggers 
#	  where owner='SYSTEM' and TRIGGER_NAME='EBS_LOGON' and status='ENABLED';
#	  select 'PATCH_SERVICE!'||count(*)||'!' from dba_services where lower(name)='ebs_patch'
#	  or upper(name) = '${ENV_NAME}_EBS_PATCH' or name='$patch_service_name';
#	  SELECT 'TBS_FREE_SIZE!'||fs.tablespace_name||'!'||fs.free_space||'!'||replace(fs.tablespace_name,(select tablespace from fnd_tablespaces where TABLESPACE_TYPE='REFERENCE'),'REFERENCE')||'!'
#    FROM
#      ( SELECT tablespace_name, round(SUM(bytes/1024/1024/1024),0) FREE_SPACE
#          FROM dba_free_space
#          GROUP BY tablespace_name) fs
#    WHERE fs.tablespace_name in
#      ('SYSTEM', (select tablespace from fnd_tablespaces where TABLESPACE_TYPE='REFERENCE' ))
#    ORDER BY fs.tablespace_name;
#    select 'RUN_PATCH_EDITION!'||aed.edition_name||'!'||ad_zd.get_edition_type(aed.edition_name)||'!'
#    from all_editions aed where ad_zd.get_edition_type(aed.edition_name) in ('RUN','PATCH');
#    select nvl((select 'EDITION_STATUS!'||NODE_TYPE||'!'||NODE_NAME||'!'||PREPARE_STATUS||'!'||APPLY_STATUS||'!'||FINALIZE_STATUS||'!'||CUTOVER_STATUS||'!'||CLEANUP_STATUS||'!'||ABORT_STATUS||'!'||STATUS||'!RUN!'
#      from ad_adop_sessions aas,all_editions aed
#      where aas.edition_name=aed.edition_name
#      and ad_zd.get_edition_type(aed.edition_name) ='RUN'
#      and aas.NODE_TYPE='master'
#      and aas.adop_session_id=(select max(adop_session_id) from ad_adop_sessions aas,all_editions aed
#        where aas.edition_name=aed.edition_name
#        and ad_zd.get_edition_type(aed.edition_name) ='RUN')),'EDITION_STATUS!!!N!N!N!N!N!N!C!RUN!') from dual
#    UNION ALL
#    select nvl((select 'EDITION_STATUS!'||NODE_TYPE||'!'||NODE_NAME||'!'||PREPARE_STATUS||'!'||APPLY_STATUS||'!'||FINALIZE_STATUS||'!'||CUTOVER_STATUS||'!'||CLEANUP_STATUS||'!'||ABORT_STATUS||'!'||STATUS||'!PATCH!'
#      from ad_adop_sessions aas,all_editions aed
#      where aas.edition_name=aed.edition_name
#      and ad_zd.get_edition_type(aed.edition_name) ='PATCH'
#      and aas.NODE_TYPE='master'
#      and aas.adop_session_id=(select max(adop_session_id) from ad_adop_sessions aas,all_editions aed
#        where aas.edition_name=aed.edition_name
#        and ad_zd.get_edition_type(aed.edition_name) ='PATCH')),'EDITION_STATUS!!!N!N!N!N!N!N!C!PATCH!') from dual
#    UNION ALL
#      select 'EDITION_STATUS!'||NODE_TYPE||'!'||NODE_NAME||'!'||PREPARE_STATUS||'!'||APPLY_STATUS||'!'||FINALIZE_STATUS||'!'||CUTOVER_STATUS||'!'||CLEANUP_STATUS||'!'||ABORT_STATUS||'!'||STATUS||'!INPROGRESS!'
#      from ad_adop_sessions aas
#      where adop_session_id=(select max(adop_session_id) from ad_adop_sessions where edition_name is null)
#      and aas.NODE_TYPE='master'
#      and adop_session_id>(select max(adop_session_id) from ad_adop_sessions where edition_name is not null);
#   select nvl((select 'FS_CLONE_STATUS!master!'||NODE_NAME||'!'||STATUS||'!'||clone_status||'!' from ad_adop_session_patches aasp
#     where adop_session_id = (select max(adop_session_id) from ad_adop_session_patches)
#     and bug_number in ('CLONE','CONFIG_CLONE') and rownum = 1),'FS_CLONE_STATUS!N!NOT-COMPLETED!') from dual;
#   --select 'DICTIONARY_CORRUPTION!'||count(*)||'!' from sys.dependency$ d,sys.obj$ o1,sys.user$ usr
#   -- where d_obj# = o1.obj#
#   --  and o1.status =1
#   --  and o1.owner# not in (0,1)
#   --  and usr.user# = o1.owner#
#   --  and (o1.type# <> 13 or o1.subname is null)
#   --  and not exists
#   --     (select 1
#   --     from sys.obj$ o2
#   --      where p_obj# = o2.obj#);"
#	edition_enabled=$(grep EDITION_ENABLED $logdir/check_edition_environment.log|awk -F"!" '{print $2}')
#	edition_enabled=${edition_enabled:-0}
#	logon_trigger_enabled=$(grep LOGON_TRIGGER $logdir/check_edition_environment.log|awk -F"!" '{print $2}')
#	logon_trigger_enabled=${logon_trigger_enabled:-0}
#	patch_service_enabled=$(grep PATCH_SERVICE $logdir/check_edition_environment.log|awk -F"!" '{print $2}')
#	patch_service_enabled=${patch_service_enabled:-0}
#	system_free=$(grep TBS_FREE_SIZE $logdir/check_edition_environment.log|grep "SYSTEM"|awk -F"!" '{print $3}')
#	reference_free=$(grep TBS_FREE_SIZE $logdir/check_edition_environment.log|grep "REFERENCE"|awk -F"!" '{print $3}')
#	reference_tbs=$(grep TBS_FREE_SIZE $logdir/check_edition_environment.log|grep "REFERENCE"|awk -F"!" '{print $2}')
#  patch_edition=$(grep RUN_PATCH_EDITION $logdir/check_edition_environment.log|grep "!PATCH!"|awk -F"!" '{print $2}')
#  run_edition=$(grep RUN_PATCH_EDITION $logdir/check_edition_environment.log|grep "!RUN!"|awk -F"!" '{print $2}')
#  #dictionary_corrupted=$(grep DICTIONARY_CORRUPTION $logdir/check_edition_environment.log|awk -F"!" '{print $2}')
#  for edition_line in $(grep EDITION_STATUS $logdir/check_edition_environment.log|grep "!PATCH!");do
#    node_info=$(echo $edition_line|awk -F"!" '{print $2":"$3}') 
#    prepare_patch_info=$(echo $edition_line|awk -F"!" '{print $4}') 
#    apply_patch_info=$(echo $edition_line|awk -F"!" '{print $5}') 
#    finalize_patch_info=$(echo $edition_line|awk -F"!" '{print $6}') 
#    cutover_patch_info=$(echo $edition_line|awk -F"!" '{print $7}') 
#    abort_patch_info=$(echo $edition_line|awk -F"!" '{print $9}') 
#    edition_patch_info=$(echo $edition_line|awk -F"!" '{print $10}') 
#    set_edition_information "prepare_patch" "Y"
#    set_edition_information "apply_patch" "Y"
#    set_edition_information "finalize_patch" "Y"
#    set_edition_information "cutover_patch" "N"
#    set_edition_information "abort_patch" "N"
#    set_edition_information "edition_patch" "C X Y"
#  done
#  for edition_line in $(grep EDITION_STATUS $logdir/check_edition_environment.log|grep "!RUN!");do
#    node_info=$(echo $edition_line|awk -F"!" '{print $2":"$3}') 
#    cutover_run_info=$(echo $edition_line|awk -F"!" '{print $7}') 
#    cleanup_run_info=$(echo $edition_line|awk -F"!" '{print $8}') 
#    abort_run_info=$(echo $edition_line|awk -F"!" '{print $9}') 
#    edition_run_info=$(echo $edition_line|awk -F"!" '{print $10}') 
#    set_edition_information "cutover_run" "N"
#    set_edition_information "cleanup_run" "Y"
#    set_edition_information "abort_run" "N"
#    set_edition_information "edition_run" "C X Y"
#  done
#  for edition_line in $(grep EDITION_STATUS $logdir/check_edition_environment.log|grep "!INPROGRESS!");do
#    node_info=$(echo $edition_line|awk -F"!" '{print $2":"$3}') 
#    prepare_inpgrs_info=$(echo $edition_line|awk -F"!" '{print $4}') 
#    edition_inpgrs_info=$(echo $edition_line|awk -F"!" '{print $10}') 
#    set_edition_information "prepare_inpgrs" "N"
#    set_edition_information "edition_inpgrs" "C X Y"
#  done
#  node_info=$(grep FS_CLONE_STATUS $logdir/check_edition_environment.log|awk -F"!" '{print $2":"$3}')
#  fs_clone_info=$(grep FS_CLONE_STATUS $logdir/check_edition_environment.log|awk -F"!" '{print $4}') 
#  set_edition_information "fsclone_run" "C"
#  set_edition_information "fsclone_patch" "N"
#  set_edition_information "fsclone_inpgrs" "R"
#  #if ((!$edition_enabled))||((!$logon_trigger_enabled))||((!$patch_service_enabled))||(($dictionary_corrupted));then 
#  if ((!$edition_enabled))||((!$logon_trigger_enabled))||((!$patch_service_enabled));then 
#    adop_action=exit
#    edition_critical=1
#  fi
#  cleanup_mode=""
#  finalize_mode=""
#  case $patch_option in 
#    apply|rollback)    if (($prepare_patch_status))&&[[ $target_edition = PATCH ]];then
#                adop_action=exit
#                edition_type_error=EditionNotPrepared
#              elif ((!$prepare_patch_status))&&[[ $target_edition = RUN ]];then
#                adop_action=exit
#                edition_type_error=EditionNotCutover
#              fi;;  
#    *) if (($prepare_patch_status))&&[[ $target_edition = PATCH ]];then
#         adop_action=warning
#         edition_type_error=EditionNotPrepared
#       elif ((!$prepare_patch_status))&&[[ $target_edition = RUN ]];then
#         adop_action=warning
#         edition_type_error=EditionNotCutover
#       fi;;            
#  esac
#  edition_status=$(echo "$edition_critical $edition_warning + pq"|dc)
#  status_statement "Checking edition based requirements" $edition_status
#  if [[ $adop_action = exit ]];then 
#    xxecho
#		xxecho "   --------------------------  EDITION CRITICAL  ---------------------------"
#    if ((!$edition_enabled));then 
#      xxecho "      Database schemas have not been enabled for editioning!" 
#      xxecho "      Please ensure to enable schemas for editioning prior to applying patches!"
#      edition_type_error=BaselineEditionError
##    elif (($dictionary_corrupted));then 
##      xxecho "      Data dictionary corruption has been detected!" 
##      xxecho "      Please revert to backup immediatly in order to avoid corrupting database!"
##    elif ((!$logon_trigger_enabled));then
##      xxecho "      EBS_LOGON trigger has not been created/enabled!" 
##      xxecho "      Please ensure to enable EBS_LOGON trigger prior to applying patches!"
##      edition_type_error=BaselineEditionError
#    elif ((!$patch_service_enabled));then
#      xxecho "      Patching Service has not been created!" 
#      xxecho "      Please ensure to create patching service 'EBS_PATCH' prior to applying patches!"
#      edition_type_error=BaselineEditionError
#    elif [[ $edition_type_error = EditionNotPrepared ]];then
#      xxecho "      PATCH edition has not been created/existing!" 
#      case $patch_option in
#        apply|rollback)  xxecho "      Please ensure to run adop phase=prepare if you want to $patch_option"
#                xxecho "      patches on PATCH edition!"
#                xxecho
#                xxecho "      If you want to $patch_option patches on RUN edition, force the"
#                xxecho "      edition using -edition RUN";;
#      esac
#    elif [[ $edition_type_error = EditionNotCutover ]];then
#      xxecho "      PATCH edition is active and has not been cutover!" 
#      case $patch_option in
#        apply|rollback)  xxecho "      Please ensure to run adop phase=cutover/abort if you want to $patch_option"
#                xxecho "      patches on RUN edition in downtime/hotpatch mode!"
#                xxecho
#                xxecho "      If you want to $patch_option patches on PATCH edition, force the"
#                xxecho "      edition using -edition PATCH";;
#      esac
#    fi
# 		xxecho "   -------------------------------------------------------------------------"
# 		exit_program $edition_type_error
#  elif [[ $adop_action = warning ]];then 
#    xxecho
# 		xxecho "   --------------------------  EDITION WARNING  ----------------------------"
#		if [[ $edition_type_error = EditionNotPrepared ]];then
#      xxecho "      PATCH edition has not been created/existing!" 
#      xxecho "      However the PATCH edition has been sourced for $patch_option."
#      xxecho
#      xxecho "      If you want to $patch_option patches on RUN edition, force the"
#      xxecho "      edition using -edition RUN"
#		elif [[ $edition_type_error = EditionNotCutover ]];then
#      xxecho "      PATCH edition is active and has not been cutover!" 
#      xxecho "      However the RUN edition has been sourced for $patch_option."
#      xxecho
#      xxecho "      If you want to $patch_option patches on PATCH edition, force the"
#      xxecho "      edition using -edition PATCH"
#    fi
#		xxecho "   --------------------------  EDITION WARNING  ----------------------------"
#    xxecho
#    yes_no "   Do you wish to continue $patch_option on $target_edition edition? [N]: " "N" "ignore"
#    if (($?));then 
#      exit_program $edition_type_error
#    fi     
#    xxecho
#  fi
#fi
#}

function bsu_memory_change
{
bsu_script=$1
if [[ -f $bsu_script ]];then
  mem_args=$(grep "MEM_ARGS=" $bsu_script|grep -v "^#"|tail -1)
  if [[ $platform_name = linux ]];then
    max_mem="Xmx4096m"
  else
    max_mem="Xmx3072m"
  fi
  mem_args_new="MEM_ARGS=\"-Xms2048m -$max_mem -XX:+UseParallelGC\""
  if [[ ! -z $mem_args ]];then
    if [[ $(echo "$mem_args"|grep -c 'Xms2048m') -eq 0 ]]||[[ $(echo "$mem_args"|grep -c '$max_mem') -eq 0 ]]||[[ $(echo "$mem_args"|grep -c 'XX:+UseParallelGC') -eq 0 ]];then 
      mv $bsu_script ${bsu_script}_backup_mem_$LogDate
      cat ${bsu_script}_backup_mem_$LogDate|sed "s%$mem_args%$mem_args_new%g" > ${bsu_script}
      chmod 750 $bsu_script
    fi
  fi
fi

}

function runinstaller_memory_change
{
runinstaller_loc=$1
for param_file in $(echo "oraparam.ini oraparamsilent.ini");do
  runinstaller_param=$runinstaller_loc/$param_file
  if [[ -f $runinstaller_param ]]&&[[ $(grep -i "^JRE_MEMORY_OPTIONS" $runinstaller_param|grep 'mx2048m'|wc -l) -eq 0 ]];then 
    mv $runinstaller_param ${runinstaller_param}_backup_$LogDate 2>/dev/null
    echo "/^ *JRE_MEMORY_OPTIONS/ {" > $logdir/installer.sedf
    echo "a\\" >> $logdir/installer.sedf
    echo "JRE_MEMORY_OPTIONS=\" -mx2048m\"" >> $logdir/installer.sedf
    echo "/^ *JRE_MEMORY_OPTIONS/d" >> $logdir/installer.sedf
    echo "}" >> $logdir/installer.sedf
    cat ${runinstaller_param}_backup_$LogDate|sed -f $logdir/installer.sedf > ${runinstaller_param} 2>/dev/null
    chmod +rx $runinstaller_param
  fi
done
}


function yes_no
{
ignore_end=${3:-no}
while true;do
	xxecho "$1 " N
	xxecho "   Waiting for answer..." N
	$echo "$1 \c"
	if [[ $run_mode = normal ]];then
		read applypatch
		if [[ $applypatch = "" ]];then
			applypatch=$2
		fi
	else
		applypatch=$2
	fi
	case $applypatch in
	[Yy])	xxecho "   Answer supplied was 'Y'" N
			xxecho "" N
			break;;
	[Nn])	xxecho "   Answer supplied was 'N'" N
			xxecho "" N
			if [[ $batch_mode = single && $ignore_end = no ]];then
			  xxecho
				end_program
			else
				return 1
			fi;;
	*)	xxecho "   Answer '$answer' invalid" N
		xxecho "" N
		echo "   Please enter answer in format [Y/y/N/n]  "
		applypatch=""
	esac
done

}

function line_statement
{
if (($line_status));then
	xxecho
	xxecho " ============================================================================="
	xxecho
	line_status=0
fi
}

# Parameter 1 is the directory that is to be created
# Parameter 2 is the 'display name' of the directory
function create_dir
{
dir_name=$2
running_statement "Creation of $dir_name"
if [[ ! -d $1 ]]; then
	created_dir=Yes
	mkdir -p $1 > /dev/null 2>&1
	if (($?)); then
		format_statement "Creation of $dir_name" "failed  "
		xxecho
		xxecho "      Creation of directory failed!"
		xxecho "      Please ensure you have read and write rights on:"
		xxecho "      - $(dirname $1)"
		exit_program PermissionError
	else
		format_statement "Creation of $dir_name" "succeeded"
	fi
else
	format_statement "Creation of directory '$dir_name'" "skipped"
fi
}

function clear_update_var
{
r_found=0; s_found=0; found_r=0; found_error=0; f_found=0
((nf+=1))
}

function write_logfile
{
echo $line >> $logfile
clear_update_var
}

function press_return
{
line_statement
if [[ $run_mode = normal ]];then
	xxecho "    Press <return> to continue ..." N
	read anykey?"   Press <return> to continue ..."
	clear
	line_statement
fi
}


# SQL script creation function
# Parameter 1 is the userid/password (i.e. system/manager)
# Parameter 2 is the spool log name
# Parameter 3 is the SQL select statement
# Parameter 4 is 'OK' return code
# Parameter 5 (optional) is sqlplus run log
# Parameter 6 (optional) noexit/exit (default = exit)

function run_sql
{
return_code=0
ok_code=${4:-"0"}
ext_log=${5:-"$logdir/run_sql.adp"}
exit_setting=${6:-"exit"}
echo "connect $1" > $logdir/run_sql.sql
echo "set pages 999" >> $logdir/run_sql.sql
echo "set long 9999" >> $logdir/run_sql.sql
echo "set echo off" >> $logdir/run_sql.sql
echo "set verify off" >> $logdir/run_sql.sql
echo "set heading off" >> $logdir/run_sql.sql
echo "set NEWPAGE none" >> $logdir/run_sql.sql
echo "spool $logdir/$2" >> $logdir/run_sql.sql
echo "set linesize 300" >> $logdir/run_sql.sql
echo "$3" >> $logdir/run_sql.sql
echo "spool off" >> $logdir/run_sql.sql
echo "exit" >> $logdir/run_sql.sql
sqlplus -s /nolog @$logdir/run_sql.sql > $ext_log
cat $logdir/run_sql.sql|grep -v "$1" > $logdir/run_sql.sql_tmp 2>/dev/null
mv $logdir/run_sql.sql_tmp $logdir/run_sql.sql 2>/dev/null
for sqlline in $(cat $ext_log 2>/dev/null|egrep 'ORA|Not connected|unknown command|PLS');do
	if [[ $(echo $sqlline|grep 'ORA-01017' |wc -l) -gt 0 ]]; then
		# Check if apps username/password is valid
		return_code=1
		break
	elif [[ $(echo $sqlline|grep 'ORA-04043' |wc -l) -gt 0 ]];then
		# Check if table or view exists (describe table)
		return_code=2
		break
	elif [[ $(echo $sqlline|grep 'ORA-00904' |wc -l) -gt 0 ]];then
		# Invalid identifier (invalid column name)
		return_code=2
		break
	elif [[ $(echo $sqlline|grep 'ORA-06553' |wc -l) -gt 0 ]];then
		# Invalid argument (invalid column name)
		return_code=2
		break
	elif [[ $(echo $sqlline|egrep 'ORA-00942|ORA-00955|ORA-01418' |wc -l) -gt 0 ]];then
		# Check if table or view exists (create or drop table)
		return_code=3
		break
	elif [[ $(echo $sqlline|egrep 'ORA-12203|ORA-12224|ORA-12505|ORA-12154' |wc -l) -gt 0 ]];then
		# Check if listener is running
		return_code=4
		break
	elif [[ $(echo $sqlline|egrep 'ORA-01034|ORA-12197|ORA-01033|ORA-01507|ORA-01089|Not connected|SP2-0640' |wc -l) -gt 0 ]];then
		# Check if database is running
		return_code=5
		break
	elif [[ $(echo $sqlline|grep 'ORA-00020' |wc -l) -gt 0 ]];then
		# Check for maximum number of processes exceeded
		return_code=7
		break
	elif [[ $(echo $sqlline|grep 'PLS-00201' |wc -l) -gt 0 ]];then
		# Function declaration missing
		return_code=8
		break
	elif [[ $(echo $sqlline|grep 'ORA-04063' |wc -l) -gt 0 ]];then
		# Package invalid
		return_code=2
		break
	elif [[ $(echo $sqlline|grep 'ORA-28000' |wc -l) -gt 0 ]];then
		# Account locked
		return_code=9
		break
	fi
done
if ((!$return_code))&&[[ ! -f $logdir/$2 ]];then
	# Check if sql spool file was created
	return_code=6
fi

if [[ $return_code -ne $ok_code ]]&&[[ $exit_setting = exit ]];then
	if (($return_code));then 
		xxecho
		exit_case $return_code
		exit_program ConnectError
	fi
fi
return $return_code

}

# exit_case is used together with run_sql to display status
# Parameter 1 is the return_code from run_sql
function exit_case
{
case $1 in
0)	break;;
1)	xxecho
	xxecho "   Schema username/password is invalid.";;
2)	xxecho
	xxecho "   Table,view or column does not exist (describe).";;
3)	xxecho
	xxecho "   Table or view does not exist (create/drop).";;
4)	xxecho
	xxecho "   TNS listener is not running or listener setup is wrong."
	xxecho "   Please ensure that listener and database is up and running!";;
5)	xxecho
	xxecho "   Database is unavailable."
	xxecho "   Please ensure that listener and database is up and running!";;
6)	xxecho
	xxecho "   SQL log failed to generate."
	xxecho "   Please check read/write rights for log location and"
	xxecho "   sqlplus executable!";;
7)	xxecho
	xxecho "   Unable to connect to database."
	xxecho "   Maximum number of processes exceeded.";;
8)	xxecho
	xxecho "   Invalid function call."
	xxecho "   Function not defined.";;
9)	xxecho
	xxecho "   Schema / account is locked.";;
*)	break;;
esac
return $1
}

# wget_file
# Parameter 1 is http username
# Parameter 2 is http password
# Parameter 3 is bug number
# Parameter 4 is http action
# Parameter 5 is http log filename
# Parameter 6 is output file
# Parameter 7 is wait for connect [yes|no], default = yes
function wget_files
{
wget_user=$1
wget_pwd=$2
bug_number=$3
http_action=$4
wget_log=$5
output_file=${6:-$logdir/wget.out}
wait_for_connect=${7:-"yes"}
rm -f $logdir/protocol.adp > /dev/null 2>&1
rm -f $logdir/$wget_log > /dev/null 2>&1
rm -f $output_file > /dev/null 2>&1
lang_id="0,2,3,4,5,6,7,8,10,11,13,14,15,16,18,26,28,29,30,37,39,43,46,62,63,66,67,101,102,103,104,106,107,108,109,110,111,112,113,114,115,116,117,118,119,999"
ftp_pwd_string=""
if [[ $wget_password = new ]];then
	echo "user=$wget_user" > $logdir/.wgetrc
	echo "password=$wget_pwd" >>  $logdir/.wgetrc
else
	echo "http-user=$wget_user" > $logdir/.wgetrc
	echo "http-passwd=$wget_pwd" >>  $logdir/.wgetrc
	ftp_pwd_string="$wget_user:$wget_pwd@"
fi
if [[ $protocol = HTTP ]];then
	if [[ $WgetProxy = noproxy ]];then
		wget_command="$WGET --dns-timeout=15 --connect-timeout=15 --read-timeout=60 --tries=4  $certificate_command"
	else
		wget_command="$WGET --execute=https_proxy=$WgetProxy --execute=http_proxy=$WgetProxy $proxy_command --dns-timeout=15 --connect-timeout=15 --read-timeout=60 --tries=4 $certificate_command"
	fi
else
	wget_command="$WGET --execute=ftp_proxy=$WgetProxy $proxy_command --dns-timeout=15 --connect-timeout=15 --read-timeout=60 --tries=4 $certificate_command"
fi
echo "WGETRC=$logdir/.wgetrc" > $logdir/wget.sh
echo "export WGETRC" >> $logdir/wget.sh
if [[ $protocol = HTTP ]];then
	if [[ $http_action = list ]];then 
		echo "$wget_command \"https://$wget_url/ARULink/XMLAPI/query_patches?email=$wget_user&userid=$wget_user&bug=$bug_number&language=$lang_id&platform=$platform_id_list\" -o $logdir/$wget_log -O $output_file " >> $logdir/wget.sh
	elif [[ $http_action = connect ]];then
		echo "$wget_command \"https://$wget_url/\" -o $logdir/$wget_log -O $output_file" >> $logdir/wget.sh
	else
		if [[ $restricted_pwd != "" ]];then
			echo "$wget_command \"https://${wget_url}${http_action}$restricted_pwd\" -o $logdir/$wget_log -O $output_file" >> $logdir/wget.sh 
		else
			echo "$wget_command \"https://${wget_url}$http_action\" -o $logdir/$wget_log -O $output_file" >> $logdir/wget.sh
		fi	
	fi	
else
	if [[ $http_action = list ]];then 
		echo "$wget_command \"ftp://$ftp_pwd_string$wget_url/$bug_number/\" -o $logdir/$wget_log -O $output_file " >> $logdir/wget.sh
	elif [[ $http_action = connect ]];then
		echo "$wget_command \"ftp://$ftp_pwd_string$wget_url/\" -o $logdir/$wget_log -O $output_file" >> $logdir/wget.sh
	else
		echo "$wget_command \"ftp://$ftp_pwd_string${wget_url}$http_action\" -o $logdir/$wget_log -O $output_file" >> $logdir/wget.sh
	fi	
fi
chmod 755 $logdir/wget.sh
(retry_count=1
	while [[ $retry_count -le 3 ]];do 
		protocol_status=0
		$logdir/wget.sh > $logdir/$wget_log 2>&1
		wget_status=$?
		if (($wget_status))||[[ ! -s $output_file ]];then
			get_protocol_status $logdir/$wget_log 
			protocol_status=$?
		else 
			output_type=list
			if [[ $(echo $output_file|grep "\.zip"|wc -l) -gt 0 ]];then
				output_type=zip
				unzip -zqq $output_file >/dev/null 2>&1
				if (($?));then 
					protocol_status=14
					mv $output_file $logdir/$(basename $output_file).err
					output_file=$logdir/$(basename $output_file).err
				fi
			fi
			if (($protocol_status))||[[ $output_type = list ]];then
				get_protocol_status $output_file
				protocol_status=$?
			fi
		fi
		if [[ $protocol_status -eq 4 ]]||[[ $protocol_status -eq 5 ]];then
			((retry_count+=1))
			sleep 1
		else 
			retry_count=4
		fi
	done
	rm -f $logdir/.wgetrc
	rm -f $logdir/wget.sh > /dev/null 2>&1
	echo "STATUS $protocol_status" > $logdir/protocol.adp;) &
if [[ $wait_for_connect = yes ]];then
	while [[ ! -r $logdir/protocol.adp ]];do
		sleep 1
	done
fi
}

# ftp_files is used to ftp to/from an ftp site
# Parameter 1 is ftp username
# Parameter 2 is ftp password
# Parameter 3 is ftp directory
# Parameter 4 is ftp action
# Parameter 5 is ftp log filename
# Parameter 6 is optional connect only mode [yes/no]
# Parameter 7 is wait for completion [yes|no] default = yes
function ftp_files
{
ftp_log=$logdir/$5  
connect_only=${6:-"no"}
wait_for_connect=${7:-"yes"}
rm -f $logdir/protocol.adp > /dev/null 2>&1
rm -f $ftp_log > /dev/null 2>&1
rm -f $logdir/sftp.conf
if [[ $FtpProxy != noproxy ]];then
  get_wget_exe
  FtpProxyPort=$(echo $FtpProxy|awk -F":" '{print $2}')
  FtpProxyPort=${FtpProxyPort:-80}
  FtpProxy=$(echo $FtpProxy|awk -F":" '{print $1}')
  echo "ProxyCommand $NC_EXE -v -X connect -x $FtpProxy:$FtpProxyPort %h %p" >> $logdir/sftp.conf 
fi
echo "User $1" >> $logdir/sftp.conf 
echo "LogLevel Debug" >> $logdir/sftp.conf 
echo "NumberOfPasswordPrompts 1" >> $logdir/sftp.conf 
echo "ConnectTimeout 30" >> $logdir/sftp.conf 
case $(uname) in 
  SunOS)  ssh -o ServerAliveCountMax dummyhost > $logdir/ssh_test.lst 2>&1
          ssh -o ServerAliveInterval dummyhost >> $logdir/ssh_test.lst 2>&1
          servalivecount_not_ok=$(grep ServerAliveCountMax $logdir/ssh_test.lst|grep -c "unknown configuration")
          servaliveint_not_ok=$(grep ServerAliveInterval $logdir/ssh_test.lst|grep -c "unknown configuration");;
      *)  servalivecount_not_ok=0
          servaliveint_not_ok=0;;
esac
if ((!$servalivecount_not_ok));then
  echo "ServerAliveCountMax 3" >> $logdir/sftp.conf 
fi
if ((!$servaliveint_not_ok));then
  echo "ServerAliveInterval 10" >> $logdir/sftp.conf 
fi
echo "UserKnownHostsFile=/dev/null" >> $logdir/sftp.conf
echo "StrictHostKeyChecking=no" >> $logdir/sftp.conf
if [[ -f $sshkey ]];then
  sshkey_error=0
  if [[ ! -f $logdir/$sshkey_mod ]];then
    # Create password less identity key using password provided for account
    sshkey_mod=$(basename $sshkey)_mod
    cp $sshkey $logdir/$sshkey_mod 2>/dev/null
    chmod 600 $logdir/$sshkey_mod 2>/dev/null
    if [[ -f /usr/bin/ssh-keygen ]];then
      SSHKEYGEN_EXE=/usr/bin/ssh-keygen
    else
      SSHKEYGEN_EXE=$(which ssh-keygen)
    fi
    if [[ -f $SSHKEYGEN_EXE ]];then
      $SSHKEYGEN_EXE -p -P "$mlink_pwd" -N "" -f $logdir/$sshkey_mod >/dev/null 2>&1
      sshkey_error=$?
    else
      sshkey_error=1
    fi
  fi
  if (($sshkey_error));then
    sshkey=""
  else
    echo "PreferredAuthentications publickey" >> $logdir/sftp.conf
    echo "IdentityFile=$logdir/$sshkey_mod" >> $logdir/sftp.conf
    if [[ $connect_only = no ]];then
      echo "lcd $OPATCH_TOP" > $logdir/sftp.bat 
      if [[ -f $4 ]];then
        cat $4 |while read entry;do
          echo "$entry" >> $logdir/sftp.bat 
        done
      else
      	echo "cd $3" >> $logdir/sftp.bat 
    	  echo "$4" >>  $logdir/sftp.bat 
    	fi
    fi
    echo "bye" >>  $logdir/sftp.bat 
    echo "sftp -F $logdir/sftp.conf -b $logdir/sftp.bat $ftp_server" > $logdir/sftp.sh
  fi
fi
if [[ ! -f $sshkey ]];then
  echo "sftp -F $logdir/sftp.conf $ftp_server" > $logdir/sftp.sh
  echo "set timeout 30" >  $logdir/sftp.tcl
  echo "set count_pass 0" >>  $logdir/sftp.tcl
  echo "set log_name $ftp_log" >>  $logdir/sftp.tcl
  echo "log_file -noappend \$log_name" >>  $logdir/sftp.tcl
  echo "send -- "\n"" >>  $logdir/sftp.tcl
  echo "spawn $logdir/sftp.sh" >>  $logdir/sftp.tcl
  echo "expect {" >>  $logdir/sftp.tcl
  echo "\"(yes/no)?\" {send \"Yes\r\";exp_continue} " >>  $logdir/sftp.tcl
  echo "-re \".*Permanently added*\" {send \"\r\n\";exp_continue}" >>  $logdir/sftp.tcl
  echo "\"Password:\" {send  \"$2\r\";exp_continue }" >>  $logdir/sftp.tcl
  echo "\"sftp>\" {" >>  $logdir/sftp.tcl
  if [[ $connect_only = no ]];then
    echo "   set timeout 1200;" >>  $logdir/sftp.tcl
    echo "   send \"lcd $OPATCH_TOP\r\";" >>  $logdir/sftp.tcl
    if [[ -f $4 ]];then
      cat $4 |while read entry;do
        echo "   expect \"sftp>\";" >>  $logdir/sftp.tcl
        echo "   send \"$entry\r\";" >>  $logdir/sftp.tcl
      done
    else
      echo "   expect \"sftp>\";" >>  $logdir/sftp.tcl
    	echo "   send \"cd $3\r\";" >> $logdir/sftp.tcl
      echo "   expect \"sftp>\";" >>  $logdir/sftp.tcl
  	  echo "   send \"$4\r\";" >>  $logdir/sftp.tcl
  	fi
  fi
  echo "   expect \"sftp>\";" >>  $logdir/sftp.tcl
  echo "   send \"bye\r\";exit 0;close;" >>  $logdir/sftp.tcl
  echo "   }" >>  $logdir/sftp.tcl
  echo "  timeout {send_log \"Connection timed out\";exit 20}" >>  $logdir/sftp.tcl
  echo "}" >>  $logdir/sftp.tcl
  chmod 755 $logdir/sftp.tcl
fi 
chmod 755 $logdir/sftp.sh

(retry_count=1; \
 while [[ $retry_count -le 3 ]];do \
 if [[ -f $sshkey ]];then \
  $logdir/sftp.sh > $ftp_log 2>&1 ; \
 else \
  $expect_exe $logdir/sftp.tcl >/dev/null 2>&1 ; \
 fi;\
 get_protocol_status $ftp_log; \
 protocol_status=$?; \
 if [[ $protocol_status -eq 9 ]]||[[ $protocol_status -eq 12 ]];then \
 	((retry_count+=1)); \
else \
	retry_count=4; \
fi;\
done; \
rm -f $logdir/sftp.tcl > /dev/null 2>&1; \
rm -f $logdir/$sshkey_mod > /dev/null 2>&1; \
echo "STATUS $protocol_status" > $logdir/protocol.adp;) &
if [[ $wait_for_connect = yes ]];then
	while [[ ! -r $logdir/protocol.adp ]];do
		sleep 1
	done
fi
}


# get_protocol_status determines status of an ftp/http session
# Parameter 1 is the log file to check
function get_protocol_status
{
protocol_code=0
protocol_log=$1
protocol_grep "$protocol_log" "File or directory" 5
protocol_grep "$protocol_log" "Directory not found|Please provide valid parameters" 6
protocol_grep "$protocol_log" "Unknown host|Name or service not known|Host not found|host nor service provided" "1"
if (($protocol_code));then
	return $protocol_code
fi
protocol_grep "$protocol_log" "unreachable|Bad Gateway|unable to resolve host address|Failed reading proxy" 2
if (($protocol_code));then
	return $protocol_code
fi
protocol_grep "$protocol_log" "Not connected|refused|Connection timed out|Server Error|Server Response Error|Read error|Unable to establish SSL connection|handshakefailed" 3
if (($protocol_code));then
	return $protocol_code
fi
protocol_grep "$protocol_log" "Login failed|Authorization Required|Authorization failed|Unsupported scheme|Unknown authentication scheme|Forbidden" 4
if (($protocol_code));then
	return $protocol_code
fi
protocol_grep "$protocol_log" "remote file: Permission denied" 18
if (($protocol_code));then
	return $protocol_code
fi
protocol_grep "$protocol_log" "Permission denied" 7
if [[ $protocol = FTP ]];then
	protocol_grep "$protocol_log" "password protected|password entered is incorrect" 9
else
	protocol_grep "$protocol_log" "Access denied" 9
fi
protocol_grep "$protocol_log" "Service not available" 10
protocol_grep "$protocol_log" "Maximum number of clients" 12
protocol_grep "$protocol_log" "invalid command" 15
protocol_grep "$protocol_log" "URLBlockedMessage" 16
protocol_grep "$protocol_log" "nc: No such file|nc32: No such file|nc: Invalid argument|nc32: Invalid argument|nc: not found|nc32: not found|nc: cannot execute|nc32: cannot execute" "17"
if [[ $protocol = HTTP ]]&&[[ ! -f $WGET ]];then
	protocol_code=13
elif [[ ! -s $protocol_log ]]; then 
	protocol_code=11
fi
return $protocol_code
}

function protocol_grep
{
protocol_log=$1
grep_cmd=$2
protocol_return_code=$3
if [[ $(strings -a $protocol_log|egrep -i "$grep_cmd" 2>/dev/null|grep -v "<abstract>" |wc -l) -gt 0 ]]; then 
	protocol_code=$protocol_return_code
fi
}

function show_protocol_status
{
xxecho
protocol_code=$1
case $protocol_code in
	1|2|8) xxecho "      Transfer of patch failed: Host unknown or unreachable!"
		xxecho "      Please ensure that you have access to updates.oracle.com through"
		xxecho "      your firewall."
		protocol_tag=ProtocolConnectionError;;
	3)	xxecho "      Transfer of patch failed: Unable to connect to host!"
		xxecho "      Please ensure that you have access to updates.oracle.com through"
		xxecho "      your firewall."
		protocol_tag=ProtocolConnectionError;;
	4)	xxecho "      Transfer of patch failed: "
		xxecho "      Invalid username and/or password!"
		xxecho "      Please ensure that you provide a valid username and password."
		protocol_tag=ProtocolPasswordError;;
	5|6)	xxecho "      Transfer of patch failed: "
			xxecho "      Directory/file for patch $patchnumber does not exist"
			xxecho "      on $protocol server!"
			protocol_tag=InvalidPatchError;;
	7)	xxecho "      Transfer of patch failed: No write permissions in \$OPATCH_TOP."
		xxecho "      Please check read/write permissions in \$OPATCH_TOP."
		xxecho "      [OPATCH_TOP=$OPATCH_TOP]"
		protocol_tag=PermissionError;;
	9)	xxecho "      Transfer of patch failed: Patch is password protected."
		xxecho "      Please get patch password from support/ARU."
		protocol_tag=RestrictedPasswordError;;
	10)	xxecho "      Transfer of patch failed: Service not available."
			xxecho "      Please ensure that you have access to updates.oracle.com through"
			xxecho "      your firewall."
			protocol_tag=ProtocolConnectionError;;
	11)	xxecho "      Transfer of patch failed: Unknown reason."
			protocol_tag=UnknownError;;
	12)	xxecho "      Transfer of patch failed: Maximum number of clients exceeded."
			xxecho "      Please retry later or download patch manually."
			protocol_tag=ProtocolConnectionError;;
	13)	xxecho "      Transfer of patch failed: 'wget' executable not available"
		xxecho "      Please ensure that you have 'wget' utility installed";;
	14)	xxecho "      Transfer of patch failed: Invalid or corrupted zipfile"
		xxecho "      Please ensure valid patch is downloaded manually."
		protocol_tag=InvalidPatchError;;
	15) xxecho "      Transfer of patch failed: Invalid wget command."
			xxecho "      Please ensure to use compatible wget utility."
			protocol_tag=ProtocolExecutableError;;
	16) xxecho "      Transfer of patch failed: URL blocked on PROXY."
			xxecho "      Please ensure proxy is correctly setup to accept connection."
			protocol_tag=UrlBlockedOnProxy;;
	17) xxecho "      Transfer of patch failed: Missing executable /usr/bin/nc"
			xxecho "      Please ensure /usr/bin/nc is present in path."
			protocol_tag=NcExecutableNotInstalled;;
	18)	xxecho "      Transfer of patch failed: No read permissions on patch."
		xxecho "      Please download patch manually as ARU patch download"
		xxecho "      is not allowed."
		protocol_tag=PermissionError;;
esac
}

# Get an answer for question. If no answer returned, ask again.
# Parameter 1 is question
# Parameter 2 is 'silent' or no echo of response (i.e. password)
# Parameter 3 is 'answer requires input', default YES
# Answer is saved in response variable
function get_response
{
question=$1
if [[ $run_mode = silent ]];then
	response=""
else
	silent_mode=$2
	require_response=$3
	if [[ $silent_mode = silent ]];then
		stty -echo
	fi
	while true;do
		xxecho "   $question " N
		xxecho "   Waiting for answer..." N
		read response?"   $question "
		if test -z "$response"; then
			response=""
			if [[ $silent_mode = silent ]];then
				echo
			fi
			if [[ $require_response = no ]];then
				xxecho "   No answer provided" N
				xxecho "" N
				break
			fi
			xxecho "   Answer is not valid" N
			xxecho "" N
		else
			if [[ $silent_mode = silent ]];then
				xxecho "   Answer was <hidden>" N
			else
				xxecho "   Answer was $response" N
			fi
			xxecho "" N
			break
		fi
	done
	if [[ $silent_mode = silent ]];then
		stty echo
		echo
	fi
fi
}



function abort_program
{
if [[ $(stty |grep -c "\-echo") -gt 0 ]];then
  stty echo
  echo
fi
xxecho
xxecho "   You are about to terminate the program pre-maturely."
yes_no "   Do you wish to continue running the program ? [N]: " N
}

function end_program
{
exit_statement=${1:-"NoError"}
get_exit_code $exit_statement
xxecho
move_patch_log
show_logfiles
line_statement
if [[ -d $logdir ]];then
	if (($DeBug));then
		echo "Logfile:  $logdir"
	else
		rm -rf $logdir > /dev/null 2>&1
	fi
fi
unset appspwd systempwd
exit $exit_code
}

function exit_program
{
exit_statement=${1:-"UnknownError"}
get_exit_code $exit_statement
xxecho
move_patch_log
show_logfiles
xxecho
xxecho "   Exiting ..."
line_statement
if [[ -d $logdir ]];then
	if (($DeBug));then
		echo "Logfile:  $logdir"
	else
		rm -rf $logdir > /dev/null 2>&1
	fi
fi
unset appspwd systempwd
exit $exit_code
}

function get_exit_code
{
# Code < 10 are 'normal' expected codes
# Code 10 <= # < 20 environment related (APPLTOP, PATCHTOP)
# Code 20 <= # < 30 opatch.sh parameter errors (wrong usage)
# Code 30 <= # < 40 Sql/db connect related (passwords or sql connect) 
# Code 40 <= # < 50 Disk related errors (disk space or permission) 
# Code 50 <= # < 60 Patch zipfile related errors
# Code 60 <= # < 70 Merge patch error
# Code > 100  # Unknown errors 
case $1 in 
NoError)			exit_code=0;;
PatchFailedError)	exit_code=1;;
UnknownError)		exit_code=2;;
KillError)			exit_code=3;;
AdpatchRunningError) exit_code=4;;
PatchNotApplied)	exit_code=5;;
RestartError)		exit_code=6;;
InvalidBaseline)	exit_code=7;;
EnvironmentError)	exit_code=10;;
PatchTopError)		exit_code=11;;
AdConfigError)		exit_code=12;;
FileEditionError)	exit_code=13;;
SSHConnectError)	exit_code=14;;
BaselineEditionError) exit_code=15;;
PatchEditionError) exit_code=16;;
EditionNotPrepared) exit_code=17;;
EditionInProgressError) exit_code=18;;
EditionNotCloned) exit_code=19;;
ParameterError)		exit_code=20;;
InvalidBatchFileError)	exit_code=21;;
PatchConflictError)  exit_code=22;;
SubsetApplied)  exit_code=23;;
OpatchRunningError) exit_code=24;;
DatabaseRunningError) exit_code=25;;
PreviousAdopFailed)     exit_code=26;;
OtherAdopFailed) exit_code=27;;
OtherAdopFailedCrit) exit_code=28;;
ConnectError)		exit_code=30;;	
PasswordError)		exit_code=31;;
DiskSpaceError)		exit_code=40;;
PermissionError)	exit_code=41;;
UnzipError)			exit_code=50;;
ZipFileError)		exit_code=51;;
InvalidPatchError)	exit_code=52;;
ProtocolPasswordError)	exit_code=53;;
RestrictedPasswordError)	exit_code=54;;
ProtocolConnectionError)	exit_code=55;;
ProtocolExecutableError)	exit_code=56;;
UrlBlockedOnProxy)				exit_code=57;;
MergeError)			exit_code=60;;
*)					exit_code=100;;
esac
}

# Creates a temporary directory for autopatch.sh log and out files
function create_temp_log
{
if [[ ! -d $logdir ]];then
	xxecho "   Creating opatch temporary log directory..."
	create_dir $logdir "opatch temp log directory"
	xxecho
fi
}

function get_xml_file
{
XML_FILE="UNKNOWN"
if [[ -f $CONTEXT_FILE ]];then
	XML_FILE=$CONTEXT_FILE
elif [[ -f $INST_TOP/appl/admin/${ENV_NAME}_${HOST_NAME}.xml ]];then
	XML_FILE=$INST_TOP/appl/admin/${ENV_NAME}_${HOST_NAME}.xml
elif [[ -f $APPL_TOP/admin/${ENV_NAME}_${HOST_NAME}.xml ]];then
	XML_FILE=$APPL_TOP/admin/${ENV_NAME}_${HOST_NAME}.xml
elif [[ -f $ORACLE_HOME/appsutil/${ORACLE_SID}_${HOST_NAME}.xml ]];then
	XML_FILE=$ORACLE_HOME/appsutil/${ORACLE_SID}_${HOST_NAME}.xml
elif [[ -f $ORACLE_HOME/appsutil/${ORACLE_SID}.xml ]];then
	XML_FILE=$ORACLE_HOME/appsutil/${ORACLE_SID}.xml
fi	
XML_FILE_NAME=$(basename $XML_FILE)
}

function get_tier
{
get_xml_file
dbtier=0
appltier=0
iastier=0
wlstier=0
ohstier=0
if [[ -f $XML_FILE ]];then
	# Determine if database or APPL_TOP
	if [[ $(grep "s_isDB" $XML_FILE|grep -i "YES"|wc -l) -gt 0 ]];then
		dbtier=1
	else 
	  if [[ $(egrep "s_isForms" $XML_FILE|grep -i "YES"|wc -l) -gt 0 ]];then
	    formstier=1
	  fi
	  if [[ $(egrep "s_isWeb" $XML_FILE|grep -i "YES"|wc -l) -gt 0 ]];then
	    iastier=1
	  fi
	  if [[ $(grep s_fmw_home $XML_FILE|wc -l) -gt 0 ]];then
	    get_xml_value $XML_FILE s_fmw_home 
	    FMW_HOME=$xml_value
	  fi
	  if [[ $(grep s_wls_home $XML_FILE|wc -l) -gt 0 ]];then
	    get_xml_value $XML_FILE s_wls_home 
	    WLS_HOME=$xml_value
	  fi
	fi
else
	if [[ $(find $ORACLE_HOME/dbs/init$ORACLE_SID.ora 2>/dev/null|wc -l) -gt 0 ]];then
		dbtier=1
	elif [[ $ORACLE_SID != "" ]]&&[[ $ORACLE_HOME != "" ]];then
		dbtier=1
	elif  [[ $TARGET_ORACLE_HOME != "" && ! -z $TWO_TASK ]];then 
	  iastier=1 
	fi
fi	
if [[ -d $WLS_HOME || -d $WL_HOME ]];then  
  wlstier=1
fi
if [[ -d $FMW_HOME || -d $MW_HOME ]];then 
  fmwtier=1
  if [[ -d $FMW_HOME/oracle_common || -d $MW_HOME/oracle_common ]];then
    fmwcmntier=1
  fi 
  if [[ -d $FMW_HOME/webtier || -d $MW_HOME/webtier ]];then
    fmwwebtier=1
  fi 
  if [[ -d $FMW_HOME/ohs || -d $MW_HOME/ohs ]];then
    fmwohstier=1
  fi 
fi
if [[ $(find $TARGET_ORACLE_HOME/DISCO.env -user $WHOAMI 2>/dev/null|wc -l) -gt 0 ]];then
	iastier=1
fi
 
}



function get_patch_number
{
if [[ -z $patchnumber ]];then
	while true;do
		if [[ $merge_option = merge ]];then
			xxecho "   Enter comma sep. list or merge patches: " N
		else
			xxecho "   Enter patchnumber(s) (or 'special' for special driver): " N
		fi
		xxecho "   Waiting for answer ... " N
		if [[ $merge_option = merge ]];then
			read response?"   Enter comma sep. list or merge patches: "
		else
			read response?"   Enter patchnumber(s) (or 'special' for special driver): "
		fi
		if test -z "$response"; then
			xxecho "   Invalid answer" N
			xxecho "" N
			response=""
		else
			break
		fi
	done
	patchnumber=$response
	xxecho "   Answer was '$response'" N
fi
}

function get_tar_number
{
if [[ -z $tarnumber ]];then
	get_response "Please enter SR/RFC number (if applicable):" "" "no"
	tarnumber=$(echo $response|sed -e 's/\(^[0-9]\+\.[0-9][1-9]*\)0*$/\1/')
else
	xxecho "   SR/RFC number: $tarnumber"
fi
}

function set_base_dir
{
base_dir_set=${base_dir_set:-0}  
if ((!$base_dir_set));then
  patchdir=${patchnumber}_${tech_version}_$patch_ext
  patchdir_alt=${patchnumber}_${tech_version}_GENERIC
  PATCH_DIR=$OPATCH_TOP/$patchdir
  PATCH_DIR_ALT=$OPATCH_TOP/$patchdir_alt
  base_dir_set=1  
fi
}


function choose_patch
{
xxecho "   List of available patches..."
for missing_patch in $(cat $logdir/missing_patch.lst 2>/dev/null);do
	patchnumber=$(echo $missing_patch|awk -F"!" '{print $1}')
	set_base_dir
	update_lang_list $logdir/patch.lst
done
num_patches=$(cat $logdir/patch.lst 2>/dev/null|awk -F"!" '{print $1}'|sort -u|wc -l)
if [[ $num_patches -gt 1 ]]; then
	if [[ $run_mode = silent ]];then
		xxecho "      Not able to apply multiple patches in silent mode ..."
		exit_program ParameterError
	fi
	if [[ $patch_option = rollback ]];then
  	xxecho "      Please select patchnumber for the patch you wish to rollback"
  else
  	xxecho "      Please select patchnumber for the patch you wish to apply"
  fi
	xxecho "      from following list:"
	cat $logdir/patch.lst|awk -F"!" '{print $1}' 2>/dev/null|sort -u|while read list;do
		xxecho "      > $list"
	done
	while true;do
		xxecho
		xxecho "      Please enter patchnumber : " N
		xxecho "      Waiting for answer ..." N
		if [[ $opatch_type = opatch ]]&&[[ $patch_option != rollback ]];then
  		read patchnumber?"      Please enter patchnumber (or 'napply' to bundle patches): "
  	else 
  		read patchnumber?"      Please enter single patchnumber to apply: "
  	fi
		check_patch=$(grep "$patchnumber!$tech_version!" $logdir/patch.lst 2>/dev/null)
		xxecho "      Answer provided was '$patchnumber'" N
		if [[ $(echo $patchnumber|tr '[A-Z]' '[a-z]') = napply ]]&&[[ $opatch_type = opatch ]];then
			merge_option=merge
			get_merge_count
			break
		elif [[ $check_patch != "$patchnumber!$tech_version!" ]]; then
			patchnumber=""
			xxecho "      Please select a valid patchnumber !"
		else
			break
		fi
	done
	line_statement
elif [[ $num_patches -eq 1 ]];then
	patchnumber=$(cat $logdir/patch.lst 2>/dev/null|awk -F"!" '{print $1}'|sort -u)
	xxecho "      Only one remaining patch: $patchnumber"
	xxecho
else
	xxecho "      No remaining patches !"
	if [[ $run_mode = silent ]];then
		exit_program InvalidPatchError
	fi
	end_program
fi
}

function get_merge_count
{
count_merge_patches=0
merge_name=""

for patchnumber in $(cat $logdir/patch.lst 2>/dev/null|awk -F"!" '{print $1}'|sort -u);do
#for patchnumber in $(cat $logdir/patch_not_applied.lst 2>/dev/null|awk -F"!" '{print $1}'|sort -u);do
	if [[ $merge_name = "" ]];then
		((count_merge_patches+=1))
		merge_count=$patchnumber
		merge_name=$patchnumber
	else
		((count_merge_patches+=1))
		merge_count=$(echo "$merge_count $patchnumber + p q"|dc)
		merge_name=${merge_count}_${count_merge_patches}
	fi
done
if [[ $count_merge_patches -le 1 ]];then 
	merge_option=single
else
	patchnumber=$merge_name
	patchdir="${patchnumber}_${tech_version}"
fi
}

function check_tar_number
{
xxecho "   Checking SR/RFC number(s) for patch $patchnumber ($tech_version)..."
if [[ $(ls $patchlog/$patchdir/TAR#* 2> /dev/null|wc -l) -gt 0 ]]; then
		# TAR file(s) exists
	ls $patchlog/$patchdir/TAR#*|sed 's/TAR#//g'|while read tarnumber;do
		xxecho "      SR/RFC: $(basename $tarnumber)"
	done
else
	xxecho "      SR/RFC: No SR/RFC information found"
fi
}

function check_inventory
{
inventory_source=$1
patch_message=$2
inv_file=""
return_code=0
xxecho "   Checking and validating $patch_message inventory..." 
running_statement "Checking and validating inventory" 
for inventory_file in $(echo "$TARGET_ORACLE_HOME/oraInst.loc /etc/oraInst.loc /var/opt/oracle/oraInst.loc $(dirname $TARGET_ORACLE_HOME 2>/dev/null)/oraInst.loc");do
	if [[ -f $inventory_file ]];then
		inventory_location=$(grep "inventory_loc=" $inventory_file|grep -v "#"|awk -F"=" '{print $2}')
		if [[ $(grep $inventory_source $inventory_location/ContentsXML/inventory.xml 2>/dev/null|wc -l) -gt 0 ]];then
			inv_file=$inventory_file
		 	break
		fi
	fi
done
if [[ ! -f $inv_file ]];then
	group_id=$(id|awk -F"(" '{print $3}'|awk -F")" '{print $1}')
  if [[ -d $(dirname $TARGET_ORACLE_HOME 2>/dev/null)/ora11GR2Inventory ]];then
		echo "inventory_loc=$(dirname $TARGET_ORACLE_HOME)/ora11GR2Inventory" > $TARGET_ORACLE_HOME/oraInst.loc 2>/dev/null
		echo "inst_group=$group_id" >> $TARGET_ORACLE_HOME/oraInst.loc
		if [[ $(grep $inventory_source $(dirname $TARGET_ORACLE_HOME 2>/dev/null)/ora11GR2Inventory/ContentsXML/inventory.xml 2>/dev/null|wc -l) -gt 0 ]];then
			inv_file=$TARGET_ORACLE_HOME/oraInst.loc
		fi
	elif [[ -d $(dirname $TARGET_ORACLE_HOME 2>/dev/null)/oraInventory ]];then
		mv $TARGET_ORACLE_HOME/oraInst.loc $TARGET_ORACLE_HOME/oraInst.loc_$LogDate 2>/dev/null
		echo "inventory_loc=$(dirname $TARGET_ORACLE_HOME)/oraInventory" > $TARGET_ORACLE_HOME/oraInst.loc
		echo "inst_group=$group_id" >> $TARGET_ORACLE_HOME/oraInst.loc
		if [[ $(grep $inventory_source $(dirname $TARGET_ORACLE_HOME 2>/dev/null)/oraInventory/ContentsXML/inventory.xml 2>/dev/null|wc -l) -gt 0 ]];then
			inv_file=$TARGET_ORACLE_HOME/oraInst.loc
		fi
	fi
fi
# Check if inventory works
get_opatch_exe
if (($?));then
	status_statement "Checking and validating inventory" 1
	return 1
else
 	opatch_use_no_bugfix=$($opatch_exe lsinventory -h -oh $TARGET_ORACLE_HOME 2>/dev/null|grep "bugs_fixed"|wc -l)
  if (($opatch_use_no_bugfix));then
  	$opatch_exe lsinventory -invPtrLoc $inv_file -bugs_fixed -oh $TARGET_ORACLE_HOME > $logdir/patch_applied.adp 2>&1
	  inv_status=$?
  else
   	$opatch_exe lsinventory -invPtrLoc $inv_file -oh $TARGET_ORACLE_HOME > $logdir/patch_applied.adp 2>&1
	  inv_status=$?
	fi
	status_statement "Checking and validating inventory" $inv_status
	if ((!$inv_status));then
		if [[ -f	$ocm_exe ]]&&[[ ! -f $ocm_resp_file ]];then
			# Create responsefile if missing/required
			running_statement "Creating OCM response file" 
			touch $ocm_resp_file 2>/dev/null
      $opatch_exe util installOCM -ocmrf $ocm_resp_file -silent -oh $TARGET_ORACLE_HOME> $logdir/ocmresp_file.adp 2>&1
			status_statement "Creating OCM response file" $?
			((inv_status+=$?))
			if (($inv_status));then 
			  rm $ocm_resp_file 2>/dev/null
			fi
		fi
		inventory_check=0
	fi
	return $inv_status
fi
}

function get_opatch_exe
{
if [[ ! -f $opatch_exe ]];then
	opatch_version=0
	opatch_exe=""
	if [[ -f $TARGET_ORACLE_HOME/OPatch/opatch ]];then
		opatch_exe=$TARGET_ORACLE_HOME/OPatch/opatch
	elif [[ -f $(which opatch 2>/dev/null) ]];then
		opatch_exe=$(which opatch)
	elif [[ -f $TARGET_ORACLE_HOME/../OPatch/opatch ]];then
		opatch_exe=$TARGET_ORACLE_HOME/../OPatch/opatch
	fi
fi
if [[ -f $opatch_exe ]];then
	opatch_version=$($opatch_exe version|grep Version|awk '{print $3}'|sed 's%\.%%g')
	opatch_main_version=$(echo $opatch_version|cut -c 1-3)
	OPATCH_DIR=$(dirname $opatch_exe 2>/dev/null )
	if [[ -f $OPATCH_DIR/ocm/bin/emocmrsp ]];then
		ocm_exe=$OPATCH_DIR/ocm/bin/emocmrsp
		ocm_resp_file=$TARGET_ORACLE_HOME/ocm.rsp
		ocmrf="-ocmrf $ocm_resp_file"
	fi
	if [[ ! -f $(which fuser 2>/dev/null) ]];then 
	  if [[ -f /sbin/fuser ]];then 
	    PATH=$PATH:/sbin
	    export PATH
	  else 
	    OPATCH_NO_FUSER=TRUE
	    export OPATCH_NO_FUSER
	  fi
	fi
else
	return 1
fi	
		
}

function check_patch_applied
{
check_patchnumber=$1
patch_parent=$2
main_patch_check=${3:-yes}
patch_applied=no
return_status=0
if [[ $main_patch_check = yes ]];then
  patch_applied_log=$logdir/patch_applied.adp
  patch_applied_tmp=$logdir/patch_applied.tmp
else
  patch_applied_log=$logdir/patch_to_rollback.adp
  patch_applied_tmp=$logdir/patch_to_rollback.tmp
fi
if [[ ! -z $patch_parent ]];then 
  check_display="Checking patch $patch_parent [SUBPATCH $check_patchnumber]"
else 
  if [[ $tech_type = wls ]]&&[[ $tech_main_version -lt 1212 ]];then
    bsu_patch_id=$(grep $check_patchnumber $logdir/bsupatch.lst 2>/dev/null|awk -F":" '{print $2}')
  fi
  if [[ -z $bsu_patch_id ]];then
    check_display="Checking patch $check_patchnumber"
  else
    check_display="Checking patch $check_patchnumber [$bsu_patch_id]"
  fi
fi
running_statement "$check_display"
if [[ $tech_type = wls ]]&&[[ $tech_main_version -lt 1212 ]];then
  cd $BSU_LOC >/dev/null 2>&1
  if ((!$?));then
    check_bsu_patches "$check_patchnumber:$bsu_patch_id"
    cat $logdir/bsu_patch_list.adp 2>/dev/null|sort -u > $patch_applied_log
#    cat  $logdir/bsu_patch_list.adp 2>/dev/null|while read line;do
#      if [[ $(echo $line|grep "$check_patchnumber"|wc -l) -eq 0 ]];then
#        if [[ ! -z $bsu_patch_id ]]&&[[ $(echo $line |grep $bsu_patch_id|wc -l) -gt 0 ]];then
#          echo "$check_patchnumber:$bsu_patch_id" >> $patch_applied_log 2>&1
#        else
#          echo "$line" >> $patch_applied_log 2>&1
#        fi
#      else 
#        echo "$line" >> $patch_applied_log 2>&1
#      fi
#    done
  fi
  cd - >/dev/null 2>&1
  if [[ $patch_option = rollback ]];then
    cat $patch_applied_log 2>/dev/null >> $logdir/bsupatch.lst
  fi
elif (($inventory_check));then
 	opatch_use_no_bugfix=$($opatch_exe lsinventory -h -oh $TARGET_ORACLE_HOME 2>/dev/null|grep "bugs_fixed"|wc -l)
  if (($opatch_use_no_bugfix));then
  	$opatch_exe lsinventory -invPtrLoc $inv_file -bugs_fixed -oh $TARGET_ORACLE_HOME > $patch_applied_log 2>&1
	  inv_status=$?
  else
   	$opatch_exe lsinventory -invPtrLoc $inv_file -oh $TARGET_ORACLE_HOME> $patch_applied_log 2>&1
	  inv_status=$?
	fi
	if ((!$inv_status));then
		inventory_check=0
	fi
	return_status=$inv_status
fi
count_patch=$(grep $check_patchnumber $patch_applied_log 2>/dev/null|wc -l)
if (($count_patch));then
	patch_applied=yes
	# Determine patch list format 
 	rm $logdir/patch_applied.tmp 2>/dev/null
  if [[ $tech_type = wls ]]&&[[ $tech_main_version -lt 1212 ]];then 
    patchid=$(grep $check_patchnumber $patch_applied_log 2>/dev/null|awk -F":" '{print $2}')
    if [[ ! -z $patchid ]];then
      main_patch=$check_patchnumber
    fi
    echo "Patch $check_patchnumber [$patchid]" > $patch_applied_tmp
  else
  	old_format=$(grep ") Patch" $patch_applied_log 2>/dev/null|wc -l)
  	if (($old_format));then
  		cat $patch_applied_log 2>/dev/null|egrep "\) Patch|fixes"|while read line;do
  			if [[ $(echo "$line"|grep ") Patch"|wc -l) -gt 0 ]];then
  				main_patch=$(echo "$line"|awk '{print $3"!"$6" "$7" "$8" "$9" "$11}')
  			fi
  			if [[ $(echo "$line"|grep -w "$check_patchnumber"|wc -l) -gt 0 ]];then
  			  if [[ $(grep -c "$main_patch" $patch_applied_tmp 2>/dev/null) -eq 0 ]];then
    		    echo "$main_patch" >> $patch_applied_tmp
    		  fi
  			fi
  		done
  	else
  		cat $patch_applied_log 2>/dev/null|while read line;do
  			if [[ $(echo "$line"|grep -w "$check_patchnumber"| wc -l) -gt 0 ]];then
  				main_patch=$(echo "$line"|awk '{print $2"!"$3" "$4" "$5" "$6" "$8}')
  				if [[ $(grep -c "$main_patch" $patch_applied_tmp 2>/dev/null) -eq 0 ]];then
     				echo "$main_patch" >> $patch_applied_tmp
     			fi
  			fi
  		done
  	fi
  fi
	if [[ ! -f $patch_applied_log ]];then
		cp $patch_applied_log $patch_applied_tmp 2>/dev/null
	fi
  if [[ $patch_option = rollback ]];then
    if [[ $(cat $patch_applied_tmp 2>/dev/null|awk -F"!" '{print $1}'|grep $patchnumber|wc -l) -eq 0 ]];then
      format_statement "$check_display [SUB PATCH ONLY]" "not applied"
    else
    	format_statement "$check_display" "applied  "
    fi
  else
  	format_statement "$check_display" "applied  "
  fi
else
	format_statement "$check_display" "not applied"
fi
return $return_status	
}

function check_bsu_patches
{
bsu_check=$1 
bsu_check_patch=$(echo $bsu_check|awk -F":" '{print $1}') 
bsu_check_id=$(echo $bsu_check|awk -F":" '{print $2}') 
./bsu.sh -view -verbose -status=applied -prod_dir=$WLS_OHOME 2>/dev/null|egrep "^CR/BUG|^Patch ID|^Description" > $logdir/bsu_patch_list.tmp 2>&1
rm $logdir/bsu_patch_list.adp >/dev/null 2>&1
cat $logdir/bsu_patch_list.tmp 2>/dev/null|while read bsuline;do
  bsu_type=$(echo $bsuline|awk -F":" '{print $1}'|awk '{print $1}')
  bsu_data=$(echo $bsuline|awk -F":" '{print $2}'|sed 's%^ *%%g')
  if [[ $bsu_type = "Patch" ]];then
    bsu_number=$bsu_data
  fi
  if [[ $bsu_type = "CR/BUG" ]];then
    bsu_patch="$bsu_data" 
    if [[ $bsu_number =  $bsu_check_id ]]&&[[ -z $bsu_patch ]];then
      bsu_patch="$bsu_check_patch" 
    fi
  fi
  if [[ $bsu_type = "Description" ]];then
    if [[ $(echo $bsu_data|grep -ic "WLS PATCH SET UPDATE") -gt 0 ]];then
      bsu_ptype=PSU
    elif [[ $(echo $bsu_data|grep -ic "overlay") -gt 0 ]];then
      bsu_ptype=OVERLAY
      if [[ $(echo $bsu_patch|grep -c $bsu_check_patch) -gt 0 ]]&&[[ ! -z $bsu_check_id ]]&&[[ $bsu_check_id != $bsu_number ]];then
        continue
      fi
    elif [[ $(echo $bsu_data|grep -ic "MERGE") -gt 0 ]]||[[ $(echo $bsu_patch|sed 's%,% %g'|wc -w) -gt 1 ]];then
      bsu_ptype=MERGE
    else
      bsu_ptype=ONE-OFF
    fi
    if [[ $bsu_ptype = PSU || $bsu_ptype = OVERLAY ]];then
      echo "$bsu_patch:$bsu_number:$bsu_ptype:$db_version_name"|sed 's% %%g' >> $logdir/bsu_patch_list.adp
    else
      echo "$bsu_patch:$bsu_number:$bsu_ptype"|sed 's% %%g' >> $logdir/bsu_patch_list.adp
    fi
  fi
done
}

function check_patch_conflicts
{
check_patchnumber=$1
patch_applied=no
return_status=0
ORIG_OPATCH_NO_FUSER=$OPATCH_NO_FUSER
OPATCH_NO_FUSER=TRUE
export ORIG_OPATCH_NO_FUSER OPATCH_NO_FUSER
conflict_logfile=$patchlog/$patchdir/${opatch_type}_${patchnumber}_conflicts.log
if [[ -f $conflict_logfile ]];then
  mv $conflict_logfile $conflict_logfile.$LogDate >/dev/null 2>&1
fi
running_statement "Checking conflicts for patch $check_patchnumber"
opatch_use_conflicts=$($opatch_exe -h -oh $TARGET_ORACLE_HOME 2>/dev/null|grep "prereq"|wc -l)
if (($opatch_use_conflicts));then
  $opatch_exe prereq CheckConflictAgainstOH -phBaseDir $PATCH_DIR -invPtrLoc $inv_file -oh $TARGET_ORACLE_HOME > $logdir/patch_conflicts.adp 2>&1 
  return_status=$?
  count_conflict=$(grep -i checkConflictAgainstOH  $logdir/patch_conflicts.adp 2>/dev/null|grep -i "failed"|wc -l)
else 
  if [[ $opatch_apply_mode = napply ]];then
    rm $logdir/patch_conflicts.adp >/dev/null 2>&1
    find $PATCH_DIR -name etc -type d 2>/dev/null|while read patch_etc_dir;do
      PATCH_SUB_DIR=$(dirname $patch_etc_dir)
      PATCH_SUB_NAME=$(basename $PATCH_SUB_DIR)
      if [[ ! -z $opatch_patch_id ]]&&[[ $(echo $opatch_patch_id|grep $PATCH_SUB_NAME|wc -l) -gt 0 ]];then 
        running_statement "Checking conflicts for patch $check_patchnumber [SUBPATCH $PATCH_SUB_NAME]"
        $opatch_exe apply $PATCH_SUB_DIR -invPtrLoc $inv_file -silent -report -local $ocmrf -oh $TARGET_ORACLE_HOME>> $logdir/patch_conflicts.adp 2>&1
        ((return_status+=$?)) 
        if [[ $return_status -eq 1 ]];then return_status=0;fi
      fi
    done
  else
    $opatch_exe apply $PATCH_DIR -invPtrLoc $inv_file -silent -report -local $ocmrf -oh $TARGET_ORACLE_HOME > $logdir/patch_conflicts.adp 2>&1
    return_status=$? 
    if [[ $return_status -eq 1 ]];then return_status=0;fi
  fi
  count_conflict=$(grep -i "Conflicting patches" $logdir/patch_conflicts.adp 2>/dev/null|wc -l)
fi
count_subset=$(grep -i "Following patches are not required" $logdir/patch_conflicts.adp 2>/dev/null|grep "subset"|wc -l)
count_conflict_error=$(egrep 'OUI-67301|OUI-67124' $logdir/patch_conflicts.adp 2>/dev/null|wc -l)
count_conflict=$(echo "$count_conflict $count_conflict_error + pq"|dc)
conflict_output=$(grep "\-\-\-" $logdir/patch_conflicts.adp 2>/dev/null|wc -l)
conflict_output_2=$(grep "Summary of Conflict" $logdir/patch_conflicts.adp 2>/dev/null|wc -l)
conflict_output_3=$(grep "File Conflict" $logdir/patch_conflicts.adp 2>/dev/null|wc -l)
if (($count_conflict))&&[[ $count_conflict -gt $count_subset ]];then
	format_statement "Checking conflicts for patch $check_patchnumber" "conflicts  "
	xxecho
	xxecho "   ----------------------------------------------------------------------"
	if (($conflict_output));then
  	cat $logdir/patch_conflicts.adp|awk /---/,/^$/|grep -v "\-\-\-"|while read line;do
  		xxecho "   $line"
  	done
  elif (($conflict_output_2));then
    cat $logdir/patch_conflicts.adp|awk /Summary/,/OPatch/|egrep -v 'Summary of Conflict|OPatch'|while read line;do
  		xxecho "   $line"
  	done
  elif (($conflict_output_3));then
    cat $logdir/patch_conflicts.adp|awk /Conflicting/,/STOP/|egrep -v 'STOP'|while read line;do
  		xxecho "   $line"
  	done
  fi
	xxecho "   ----------------------------------------------------------------------"
	return_status=22
elif (($count_subset));then
	format_statement "Checking conflicts for patch $check_patchnumber" "subset"
	patch_applied=yes
	superset=$(grep "Bug SubSet" $logdir/patch_conflicts.adp|awk '{print $4}')
elif (($return_status));then
	status_statement "Checking conflicts for patch $check_patchnumber" $return_status
	xxecho
	xxecho "   ----------------------------------------------------------------------"
	cat $logdir/patch_conflicts.adp 2>/dev/null|while read line;do xxecho "   $line";done
	xxecho "   ----------------------------------------------------------------------"
	if [[ $(grep -c "ERROR: OPatch failed because of problems in patch area" $logdir/patch_conflicts.adp 2>/dev/null) -gt 0 ]];then
	  xxecho "      Please check read permissions on directories under:"
	  xxecho "      -> $PATCH_DIR"
	  xxecho "   ----------------------------------------------------------------------"
	  return_status=52
	  exit_program InvalidPatchError
	fi
else 
	format_statement "Checking conflicts for patch $check_patchnumber" "no conflicts"
fi
if [[ -f $logdir/patch_conflicts.adp ]];then
  cp $logdir/patch_conflicts.adp $conflict_logfile 2>/dev/null
fi
OPATCH_NO_FUSER=$ORIG_OPATCH_NO_FUSER
export OPATCH_NO_FUSER
return $return_status	
}

function check_valid_patch
{
patch_dir=$1
not_valid_patch=0
if [[ -d $patch_dir ]]&&[[ -r $patch_dir ]];then
  if [[ -f $logdir/bsupatch.lst ]];then
    bsu_driver_id=$(grep "$patchnumber" $logdir/bsupatch.lst|awk -F":" '{print $2}')
    if [[ ! -z $bsu_driver_id ]]&&[[ ! -f $patch_dir/${bsu_driver_id}.jar ]];then
    	not_valid_patch=1
  	fi
  fi
	if (($not_valid_patch));then
		format_statement "Checking patch directory for patch $patchnumber" "corrupted"
		patch_exists=1
		mv $patch_dir ${patch_dir}_CORRUPT 2>/dev/null
		if (($?));then
			xxecho 
			xxecho "   Unable to remove corrupted patch directory:"
			xxecho "   -> $patch_dir "
			xxecho
			xxecho "   Please remove corrupted directory manually !"
			exit_program PermissionError
		fi
		if [[ -d ${patch_dir}_CORRUPT ]];then
			rm -rf ${patch_dir}_CORRUPT 2>/dev/null &
		fi
	else
		format_statement "Checking patch directory for patch $patchnumber" "available"
		update_lang_list $logdir/missing_patch.lst
	fi	
else 
	not_valid_patch=1
fi
return $not_valid_patch
}


function check_patch_dir
{
# Test to see if patchdirectory exists
patch_exists=0
zip_exists=0
running_statement "Checking patch directory for patch $patchnumber"
check_valid_patch $PATCH_DIR
invalid_patch=$?
if (($invalid_patch));then
  check_valid_patch $PATCH_DIR_ALT
  invalid_patch=$?
  if ((!$invalid_patch));then
    PATCH_DIR=$PATCH_DIR_ALT
  fi
fi
if (($invalid_patch));then
	# Check if a 'standard' patch dir exists. If yes, move it to patchnumber_LANG
	if [[ -d $OPATCH_TOP/$patchnumber ]]; then
		move_patch_dir "$OPATCH_TOP/$patchnumber" "$PATCH_DIR"
		move_patch_error=$?
		if (($move_patch_error)); then
			xxecho 
			xxecho "   Unable to access patch directory '\$OPATCH_TOP/$patchnumber' or"
			xxecho "   patch content invalid !"
			xxecho "   Please remove patch directory '\$OPATCH_TOP/$patchnumber' manually !"
			exit_program PermissionError
		else
		  set_patch_dir nopermissions
		fi
	fi
  check_valid_patch $PATCH_DIR
  invalid_patch=$?
	if (($invalid_patch));then
		compressed_patch=""
		if [[ -f $PATCH_DIR.zip ]];then
			compressed_patch=zip
		elif [[ -f $PATCH_DIR.tar.Z ]];then
			compressed_patch=uncompress
		fi
		case $compressed_patch in 
		zip)	if [[ ! -f $(which unzip 2>/dev/null) ]];then
					patch_exists=1
				else
					unzip -ouCq $PATCH_DIR.zip -d $OPATCH_TOP 2>/dev/null
					if (($?))||[[ ! -d $PATCH_DIR ]];then
						format_statement "Checking patch directory for patch $patchnumber" "unavailable"
						patch_exists=1
					else
					  check_valid_patch $PATCH_DIR
            invalid_patch=$?
						set_patch_dir 
					fi
				fi;;
		uncompress)	if [[ -f $(which tar 2>/dev/null) ]]&&[[ -f $(which uncompress 2>/dev/null) ]];then
						uncompress $PATCH_DIR.tar.Z 2> /dev/null
						if (($?))||[[ ! -f $PATCH_DIR.tar ]];then
							format_statement "Checking patch directory for patch $patchnumber" "unavailable"
							patch_exists=1
						else
							cd $OPATCH_TOP > /dev/null 2>&1
							tar xf $PATCH_DIR.tar
							if (($?))||[[ ! -d $PATCH_DIR ]];then
								format_statement "Checking patch directory for patch $patchnumber" "unavailable"
								rm -rf $PATCH_DIR > /dev/null 2>&1
								patch_exists=1
							else
  	  				  check_valid_patch $PATCH_DIR
                invalid_patch=$?
								set_patch_dir
							fi
							cd - > /dev/null 2>&1
						fi
					else
						format_statement "Checking patch directory for patch $patchnumber" "unavailable"
						patch_exists=1
					fi;;
		*)	format_statement "Checking patch directory for patch $patchnumber" "unavailable"
			patch_exists=1;;
		esac
	fi
	if (($patch_exists))||(($invalid_patch));then
		running_statement "Checking for zip file for patch $patchnumber"
#		if [[ $tech_type = db ]];then
#			check_zipfile "ls $OPATCH_TOP/p${patchnumber}_${tech_version}*zip $OPATCH_STAGE/p${patchnumber}_${tech_version}*zip $OPATCH_STAGE_ZIP/p${patchnumber}_${tech_version}*zip 2>/dev/null"
#			zip_check=$?
#		else
			check_zipfile "ls $OPATCH_TOP/p${patchnumber}*.zip $OPATCH_STAGE/p${patchnumber}*.zip $OPATCH_STAGE_ZIP/p${patchnumber}*.zip 2>/dev/null"
			zip_check=$?
#		fi
		if (($zip_check));then
			format_statement "Checking for zip file for patch $patchnumber" "unavailable"
			zip_exists=1
		else
			format_statement "Checking for zip file for patch $patchnumber" "available"
		fi
	else
		if [[ $patch_option = download || $patch_option = patchdownload ]];then
			xxecho
			xxecho "      Skipping download of patch $patchnumber."
		fi
	fi
fi
return $zip_exists
}


# check_zipfile checks if zip file exists
# Parameter 1 is the list of possible zip files
function check_zipfile
{
rm -f $logdir/PZIPNAME > /dev/null 2>&1
zip_exists=1
patchzipname=""

if [[ $patch_option = patchdownload ]];then
  eval $(echo $1)|while read file; do
    patchzipname=$(basename $file)
    if [[ $(cat $logdir/patchzip.lst 2>/dev/null|grep -c $patchzipname) -gt 0 ]];then
      echo $patchzipname > $logdir/PZIPNAME
      break
    fi
  done
  if [[ -f $logdir/PZIPNAME ]];then
    patchzipname=$(cat $logdir/PZIPNAME)
    zip_exists=0
  fi
  return $zip_exists
fi
tv=$(echo $tech_version|awk '{print length}')
tvl=$(echo $tech_long_version|awk '{print length}')
tvbl=$(echo $tech_base_version|awk '{print length}')
tvdiff=$(echo "$tv $tvbl - pq"|dc)
if [[ $forced_tech_version = no ]];then
  stdzip="tv"
else
  stdzip="tvf"
fi
if [[ $forced_tech_version = yes ]]&&[[ -z $tech_long_version || $opatch_type = bsu ]];then
  ziporder="tvf"
elif [[ $tv -ge $tvl ]]||[[ $tvdiff -eq 0 && $tech_version -gt $tech_base_version ]];then
  if [[ $forced_tech_version = no ]];then
    ziporder="tv tvbl tvb tvm"
  else
    if [[ $tv -ge $tvbl ]];then
      if [[ $tvdiff -le 1 ]];then
        ziporder="$stdzip tvbl tvm tvb"
      else
        ziporder="$stdzip tvbl tvm"
      fi
    else
      ziporder="$stdzip tvbl tvb tvm"
    fi
  fi
elif [[ $tvl -gt $tvbl ]];then
  ziporder="tvl $stdzip tvbl tvb tvm"
else
  ziporder="tvl tvbl tvb $stdzip tvm"
fi
for ziptype in $(echo $ziporder);do
  if [[ -f $logdir/PZIPNAME ]];then
    patchzipname=$(cat $logdir/PZIPNAME)
    break
  fi
  case $ziptype in 
    tvl)  search_zip "$1" "*${tech_long_version}_*GENERIC.zip|*${tech_long_version}_*generic.zip|*${tech_long_version}_*Generic.zip|*${tech_long_version}_*$patch_ext.zip"
          if (($?));then
             search_zip "$1" "*${tech_long_version}_*$patch_ext2.zip"
          fi;;
    tvf)  search_zip "$1" "*${tech_version}_GENERIC.zip|*${tech_version}_generic.zip|*${tech_version}_Generic.zip|*${tech_version}_$patch_ext.zip"
          if (($?));then
            search_zip "$1" "*${tech_version}_$patch_ext2.zip"
            if (($?));then
              if ((!$tvdiff))&& [[ $tech_version -gt $tech_base_version ]];then
                # Base length and tech lengt is same and tech version is higher
                # Check if tech version has [0-9]
                search_zip "$1" "*${tech_version}[0-9]_GENERIC.zip|*${tech_version}[0-9]_generic.zip|*${tech_version}[0-9]_Generic.zip|*${tech_version}[0-9]_$patch_ext.zip"
                if (($?));then
                  search_zip "$1" "*${tech_version}[0-9]_$patch_ext2.zip"
                fi
              fi
            fi
          fi;;
    tv)   search_zip "$1" "*$tech_version*GENERIC.zip|*$tech_version*generic.zip|*$tech_version*Generic.zip|*$tech_version*$patch_ext.zip"
          if (($?));then
            search_zip "$1" "*$tech_version*$patch_ext2.zip"
          fi;;
    tvbl) search_zip "$1" "*${tech_base_version}[0-9]_GENERIC.zip|*${tech_base_version}[0-9]_generic.zip|*${tech_base_version}[0-9]_Generic.zip|*${tech_base_version}[0-9]_$patch_ext.zip"
          if (($?));then
            search_zip "$1" "*${tech_base_version}[0-9]_$patch_ext2.zip"
          fi;;
    tvb)  search_zip "$1" "*${tech_base_version}_GENERIC.zip|*${tech_base_version}_generic.zip|*${tech_base_version}_Generic.zip|*${tech_base_version}_$patch_ext.zip"
          if (($?));then
            search_zip "$1"  "*${tech_base_version}_$patch_ext2.zip"
          fi;;
    tvm)  search_zip "$1" "*${tech_main_version}_*GENERIC.zip|*${tech_main_version}_*generic.zip|*${tech_main_version}_*Generic.zip|*${tech_main_version}_*$patch_ext.zip"
          if (($?));then
          	search_zip "$1" "*${tech_main_version}_*$patch_ext2.zip"
          fi;;
  esac
done

#for ziptype in $(echo $ziporder);do
#  if [[ -f $logdir/PZIPNAME ]];then
#    patchzipname=$(cat $logdir/PZIPNAME)
#    break
#  fi
#  case $ziptype in 
#    tvl) eval $(echo $1)|while read file; do
#        	case $(echo $file) in
#        	*${tech_long_version}_*GENERIC.zip|*${tech_long_version}_*generic.zip|*${tech_long_version}_*Generic.zip|*${tech_long_version}_*$patch_ext.zip)	patchzipname=$(basename $file)
#        				echo $patchzipname > $logdir/PZIPNAME
#        				break;;
#        	*)			;;
#        	esac
#        done
#        if [[ ! -f $logdir/PZIPNAME ]];then
#        	eval $(echo $1)|while read file; do
#        		case $(echo $file) in
#        		*${tech_long_version}_*$patch_ext2.zip)	patchzipname=$(basename $file)
#        					echo $patchzipname > $logdir/PZIPNAME
#        					break;;
#        		*)			;;
#        		esac
#        	done
#        fi;;
#    tvf)  eval $(echo $1)|while read file; do
#          	case $(echo $file) in
#          	*${tech_version}_GENERIC.zip|*${tech_version}_generic.zip|*${tech_version}_Generic.zip|*${tech_version}_$patch_ext.zip)	patchzipname=$(basename $file)
#          				echo $patchzipname > $logdir/PZIPNAME
#          				break;;
#          	esac
#          done
#          if [[ ! -f $logdir/PZIPNAME ]];then
#          	eval $(echo $1)|while read file; do
#          		case $(echo $file) in
#          		*${tech_version}_$patch_ext2.zip)	patchzipname=$(basename $file)
#          					echo $patchzipname > $logdir/PZIPNAME
#          					break;;
#          		*)			;;
#          		esac
#          	done
#          fi
#          if [[ ! -f $logdir/PZIPNAME ]];then
#            if ((!$tvdiff))&& [[ $tech_version -gt $tech_base_version ]];then
#              # Base length and tech lengt is same and tech version is higher
#              # Check if tech version has [0-9]
#              eval $(echo $1)|while read file; do
#              	case $(echo $file) in
#              	*${tech_version}[0-9]_GENERIC.zip|*${tech_version}[0-9]_generic.zip|*${tech_version}[0-9]_Generic.zip|*${tech_version}[0-9]_$patch_ext.zip)	patchzipname=$(basename $file)
#              				echo $patchzipname > $logdir/PZIPNAME
#              				break;;
#              	esac
#              done
#            fi
#            if [[ ! -f $logdir/PZIPNAME ]];then
#            	eval $(echo $1)|while read file; do
#            		case $(echo $file) in
#            		*${tech_version}[0-9]_$patch_ext2.zip)	patchzipname=$(basename $file)
#            					echo $patchzipname > $logdir/PZIPNAME
#            					break;;
#            		*)			;;
#            		esac
#            	done
#            fi
#          fi;;
#    tv)   eval $(echo $1)|while read file; do
#          	case $(echo $file) in
#          	*$tech_version*GENERIC.zip|*$tech_version*generic.zip|*$tech_version*Generic.zip|*$tech_version*$patch_ext.zip)	patchzipname=$(basename $file)
#          				echo $patchzipname > $logdir/PZIPNAME
#          				break;;
#          	*)			;;
#          	esac
#          done
#          if [[ ! -f $logdir/PZIPNAME ]];then
#          	eval $(echo $1)|while read file; do
#          		case $(echo $file) in
#          		*$tech_version*$patch_ext2.zip)	patchzipname=$(basename $file)
#          					echo $patchzipname > $logdir/PZIPNAME
#          					break;;
#          		*)			;;
#          		esac
#          	done
#          fi;;
#    tvbl)  eval $(echo $1)|while read file; do
#          	case $(echo $file) in
#          	*${tech_base_version}[0-9]_GENERIC.zip|*${tech_base_version}[0-9]_generic.zip|*${tech_base_version}[0-9]_Generic.zip|*${tech_base_version}[0-9]_$patch_ext.zip)	patchzipname=$(basename $file)
#          				echo $patchzipname > $logdir/PZIPNAME
#          				break;;
#          	*)			;;
#          	esac
#          done
#          if [[ ! -f $logdir/PZIPNAME ]];then
#          	eval $(echo $1)|while read file; do
#          		case $(echo $file) in
#          		*${tech_base_version}[0-9]_$patch_ext2.zip)	patchzipname=$(basename $file)
#          					echo $patchzipname > $logdir/PZIPNAME
#          					break;;
#          		*)			;;
#          		esac
#          	done
#          fi;;
#    tvb)  eval $(echo $1)|while read file; do
#          	case $(echo $file) in
#          	*${tech_base_version}_GENERIC.zip|*${tech_base_version}_generic.zip|*${tech_base_version}_Generic.zip|*${tech_base_version}_$patch_ext.zip)	patchzipname=$(basename $file)
#          				echo $patchzipname > $logdir/PZIPNAME
#          				break;;
#          	*)			;;
#          	esac
#          done
#          if [[ ! -f $logdir/PZIPNAME ]];then
#          	eval $(echo $1)|while read file; do
#          		case $(echo $file) in
#          		*${tech_base_version}_$patch_ext2.zip)	patchzipname=$(basename $file)
#          					echo $patchzipname > $logdir/PZIPNAME
#          					break;;
#          		*)			;;
#          		esac
#          	done
#          fi;;
#    tvm)  eval $(echo $1)|while read file; do
#          	case $(echo $file) in
#          	*${tech_main_version}_*GENERIC.zip|*${tech_main_version}_*generic.zip|*${tech_main_version}_*Generic.zip|*${tech_main_version}_*$patch_ext.zip)	patchzipname=$(basename $file)
#          				echo $patchzipname > $logdir/PZIPNAME
#          				break;;
#          	*)			;;
#          	esac
#          done
#          if [[ ! -f $logdir/PZIPNAME ]];then
#          	eval $(echo $1)|while read file; do
#          		case $(echo $file) in
#          		*${tech_main_version}_*$patch_ext2.zip)	patchzipname=$(basename $file)
#          					echo $patchzipname > $logdir/PZIPNAME
#          					break;;
#          		*)			;;
#          		esac
#          	done
#          fi;;
#  esac
#done
if [[ -f $logdir/PZIPNAME ]];then
  patchzipname=$(cat $logdir/PZIPNAME)
  zip_exists=0
fi

return $zip_exists
}

function search_zip
{
search_command="$1"
search_param="$2"
if [[ ! -f $logdir/PZIPNAME ]];then
  eval $(echo $search_command)|while read file; do
  	case $(echo $file) in
  	$search_param)	patchzipname=$(basename $file)
  				echo $patchzipname > $logdir/PZIPNAME
  				break;;
  	*)			;;
  	esac
  done
fi  
if [[ ! -f $logdir/PZIPNAME ]];then
  return 1
fi 
  
}

function get_metalink_account
{
if (($MlinkSet));then
	if [[ $run_mode = silent ]];then
		exit_program ProtocolDownloadError
	else
		xxecho
		get_response "   Please enter $credential username:"
		mlink_uname=$response
		get_response "   Please enter $credential password:" "silent"
		mlink_pwd=$response
	fi
fi
xxecho
xxecho "   Downloading missing patch(es) from 'updates.oracle.com'..."

}

function get_restricted_password
{
if [[ $run_mode = silent ]];then
	exit_program RestrictedPasswordError
fi
xxecho
get_response "   Please enter restricted password for patch $patchnumber:"
restricted_pwd=$response
restricted_patch_name=$patchnumber
xxecho
xxecho "   Downloading missing patch(es) from 'updates.oracle.com'..."
}

function check_ftp_connection
{
if [[ $protocol_connection_check = NOTOK ]];then
	# Get updates.oracle.com entry
	get_metalink_account
	ftp_server=aru.us.oracle.com
	running_statement "FTP connection check [$ftp_server]"
	if [[ -z $FtpProxy ]];then
    if [[ $customer_type = opc ]];then
      proxy_line="noproxy omcs-proxy.oracleoutsourcing.com"
    else
      proxy_line="omcs-proxy.oracleoutsourcing.com noproxy"
    fi
	  if [[ ! -z $WgetProxy ]];then
      proxy_line="$WgetProxy $proxy_line"
    fi
  fi
	for FtpProxy in $(echo $proxy_line);do
  	ftp_files "$mlink_uname" "$mlink_pwd" "" "" "ftp_connect.adp" "yes" 
    protocol_status=$(grep STATUS $logdir/protocol.adp 2>/dev/null|awk '{print $2}')
	  case $protocol_status in
	    1|2|3) ;;
	    *)  break;;
    esac
	done
	check_protocol_status "FTP connection check [$ftp_server]"
	if (($protocol_status));then
	  if [[ $run_mode = silent ]];then
		  exit_program $protocol_tag
	  fi
  	if [[ $protocol_status = 4 ]];then
  		MlinkSet=1
  		rm -f $logdir/protocol.adp >/dev/null
  		check_ftp_connection
  	fi
  else
  	protocol_connection_check=OK
  fi
fi
}

function check_protocol_patch
{
if [[ ! -f $logdir/patch_download_list.lst ]];then
	cp  $logdir/patch_download.lst $logdir/patch_download_list.lst
fi

for patchnumber in $(cat $logdir/patch_download_list.lst 2>/dev/null|awk -F"!" '{print $1}'|sort -u);do
	if [[ -s $logdir/patch_download_list.lst ]];then
		running_statement "Getting patch list for patch $patchnumber"
		if [[ $protocol = FTP ]];then
			protocol_status=0
			ftp_files "$mlink_uname" "$mlink_pwd" "$patchnumber" "ls -l" "patchlist_$patchnumber.adp"
		else
			protocol_status=0
			wget_files "$mlink_uname" "$mlink_pwd" "$patchnumber" "list" "patch_$patchnumber.log" "$logdir/patchlist_$patchnumber.adp"
		fi
		check_protocol_status "Getting patch list for patch $patchnumber" 6 silent
		if (($protocol_status));then
 			if [[ $run_mode = silent ]];then
 			  if [[ $patch_option = rollback ]]&&[[ $protocol_status != 4 ]];then 
 			    protocol_status=0
 			    return 0
 			  fi
				exit_program $protocol_tag
			fi
			if [[ $protocol_status = 4 ]];then
				MlinkSet=1
				get_metalink_account
				rm -f $logdir/protocol.adp >/dev/null
				check_protocol_patch
			else
				update_lang_list $logdir/patch_download.lst "$patchnumber"
			fi
		else
			update_lang_list $logdir/patch_download_list.lst "$patchnumber"
			if [[ $protocol = FTP ]];then
				for line in $(cat $logdir/patchlist_$patchnumber.adp 2>/dev/null|grep "zip"|awk '{print $5"!"$9}'|sed 's%\r%%g');do
					size=$(echo "$line"|awk -F"!" '{print $1}')
					file_name=$(echo "$line"|awk -F"!" '{print $2}')
					if [[ $(echo $size|grep K|wc -l) -gt 0 ]];then
						size=$(echo $size|sed 's%K%%g')
						size=$(echo "$size 1024 * p q"|dc)
					elif [[	$(echo $size|grep M|wc -l) -gt 0 ]];then
						size=$(echo $size|sed 's%M%%g')
						size=$(echo "$size 1024 * 1024 * p q"|dc)
					fi
					patch_url="/$patchnumber/$file_name"
					echo "$file_name $size $patch_url 1 1" >>  $logdir/patchlist.adp 
				done	
			else
				count_patch=0
				if [[ $protocol = HTTP ]];then
					for line in $(cat $logdir/patchlist_$patchnumber.adp 2>/dev/null|sed 's% %#%g'|egrep "<file#name=|<size>|<patch_url>|<status>");do
						info_complete=0
						if [[ $(echo "$line"|grep "<status>"|wc -l) -gt 0 ]];then
							((count_patch+=1))
							url_count=0
							file_count=0
							release[$count_patch]=""
							status[$count_patch]=$(echo "$line"|awk -F">" '{print $2}'|awk -F"<" '{print $1}')	
							patch_url[$count_patch]=""
							file_name[$count_patch]=""
							size[$count_patch]=""
						elif [[ $(echo "$line"|grep "<release>"|wc -l) -gt 0 ]];then
							release[$count_patch]=$(echo "$line"|awk -F">" '{print $2}'|awk -F"<" '{print $1}')
						elif [[ $(echo "$line"|grep "<patch_url>"|wc -l) -gt 0 ]];then
							((url_count+=1))
							patch_url[$url_count]=$(echo "$line"|awk -F"[" '{print $3}'|awk -F"]" '{print $1}')
							if [[ ${patch_url[$url_count]} = "" ]]&&[[ $url_count -gt 0 ]];then
								((url_count-=1))
							fi
						elif [[ $(echo "$line"|grep "<file#name="|wc -l) -gt 0 ]];then
							((file_count+=1))
							file_name[$file_count]=$(echo "$line"|awk -F"=" '{print $2}'|sed 's%\"%%g'|awk -F">" '{print $1}')
						elif [[ $(echo "$line"|grep "<size>"|wc -l) -gt 0 ]];then
							size[$count_patch]=$(echo "$line"|awk -F">" '{print $2}'|awk -F"<" '{print $1}')
							info_complete=1
						fi
						if (($info_complete));then
							count_url=1
							while [[ $count_url -le $url_count ]]&&[[ $patch_url[$url_count] != "" ]];do
								echo "${file_name[$count_url]} ${size[$count_patch]} ${patch_url[$count_url]} ${status[$count_patch]} $url_count ${release[$count_patch]}" >>  $logdir/patchlist.adp 
								((count_url+=1))
							done
						fi
					done
				else
					for line in $(cat $logdir/patchlist_$patchnumber.adp 2>/dev/null|sed 's% %#%g');do
						file_name=$(echo "$line"|awk -F">" '{print $2}'|awk -F"<" '{print $1}')
						size=$(echo "$line"|sed 's%#%%g'|awk -F"]" '{print $3}')
						if [[ $(echo $size|grep K|wc -l) -gt 0 ]];then
							size=$(echo $size|sed 's%K%%g')
							size=$(echo "$size 1024 * p q"|dc)
						elif [[	$(echo $size|grep M|wc -l) -gt 0 ]];then
							size=$(echo $size|sed 's%M%%g')
							size=$(echo "$size 1024 * 1024 * p q"|dc)
						fi
						patch_url="/$patchnumber/$file_name"
						echo "$file_name $size $patch_url 1 1" >>  $logdir/patchlist.adp 
					done		
				fi		
			fi
			format_statement "Getting patch list for patch $patchnumber" "succeeded"
		fi
	fi
done

for ptchnumber in $(cat $logdir/patch_download.lst 2>/dev/null);do
	patchnumber=$(echo $ptchnumber|awk -F"!" '{print $1}')
	tech_version=$(echo $ptchnumber|awk -F"!" '{print $2}')
	running_statement "Checking availability on $protocol [patch $patchnumber ($tech_version)]"
	check_zipfile "grep p$patchnumber $logdir/patchlist.adp 2>/dev/null|awk '{print \$1}' 2> /dev/null"
	zip_status=$?
	if (($zip_status));then
		format_statement "Checking availability on $protocol server [patch $patchnumber ($tech_version)]" "unavailable"
		update_lang_list $logdir/patch_download.lst
		update_lang_list $logdir/patch_language.lst
		if [[ $merge_option = merge ]];then
			update_lang_list $logdir/patch_download.lst "!$lang_code!"
			update_lang_list $logdir/patch_language.lst "!$lang_code!"
		fi
	else
		format_statement "Checking availability on $protocol server [patch $patchnumber ($tech_version)]" "available"
		for pzipname in $(echo $patchzipname);do
			if [[ $(grep "$ptchnumber$pzipname!" $logdir/patch_download_zipname.lst 2>/dev/null|wc -l) -eq 0 ]];then
				echo "$ptchnumber$pzipname!" >> $logdir/patch_download_zipname.lst
			fi
		done
	fi
done
for ptchnumber in $(cat $logdir/patch_download_zipname.lst 2>/dev/null);do
	patchnumber=$(echo $ptchnumber|awk -F"!" '{print $1}')
	patchzipname=$(echo $ptchnumber|awk -F"!" '{print $4}')
	patch_lang=$(echo $lang_code| tr '[A-Z]' '[a-z]')
	if [[ ! -f $OPATCH_TOP/$patchzipname ]]&&[[ ! -f $OPATCH_STAGE/$patchzipname ]];then
		check_disk_space
		download_patch
	fi
done
}

function get_wget_exe
{
  if [[ -z $WGET ]];then
    if [[ -f $ODCODE_TOP/wget/bin/wget ]];then 
  	  WGET_TOP=$ODCODE_TOP/wget
  	fi
   	if [[ -f /usr/local/git/bin/wget ]];then
  		WGET=/usr/local/git/bin/wget
  	elif [[ -f $(which wget 2>/dev/null) ]];then
  		WGET=$(which wget)
  	elif [[ -f /usr/local/bin/wget ]];then
  		WGET=/usr/local/bin/wget
  	elif [[ -f $WGET_TOP/bin/wget ]];then
  		WGET=$WGET_TOP/bin/wget
  	else
  		WGET=UNKNOWN
  	fi
  	if [[ $(uname) = Linux ]]&&[[ $($WGET -V 2>/dev/null|grep GNU|grep "1.12"|wc -l) -gt 0 ]]&&[[ -f $WGET_TOP/bin/wget ]];then
  	  WGET=$WGET_TOP/bin/wget
  	  LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$WGET_TOP/lib64
  	  export LD_LIBRARY_PATH
  	fi
    if [[ $($WGET --help 2>/dev/null|grep "\-\-password"|wc -l) -gt 0 ]];then
    	wget_password=new
    	proxy_command="--proxy"
    else
    	wget_password=old
    	proxy_command="--proxy=on"
    fi
    if [[ $($WGET --help 2>/dev/null|grep "\-\-no-check-certificate"|wc -l) -gt 0 ]];then
    	certificate_command="--no-check-certificate"
    else
    	certificate_command=""
    fi
  fi
  if [[ -z $NC_EXE ]];then
  	if [[ -f /usr/bin/nc ]];then
  		NC_EXE=/usr/bin/nc
  	elif [[ -f $(which nc 2>/dev/null) ]];then
  		NC_EXE=$(which nc)
  	elif [[ -f $WGET_TOP/bin/nc ]];then
  		NC_EXE=$WGET_TOP/bin/nc
      if [[ $(uname -i) = i386 ]]&&[[ -f $WGET_TOP/bin/nc32 ]];then
        NC_EXE=$WGET_TOP/bin/nc32
      else
        NC_EXE=$WGET_TOP/bin/nc
      fi
  	else
  		NC_EXE=UNKNOWN
    fi
  fi
}

function check_wget_connection
{
if [[ $protocol_connection_check = NOTOK ]];then
	# Get updates.oracle.com entry
	get_metalink_account
	get_wget_exe
  if [[ $customer_type = opc ]]&&[[ -z $WgetProxy ]];then
	  if [[ -f /etc/profile.d/proxy.sh ]];then
  	  opc_proxy=$(grep "https_proxy=" /etc/profile.d/proxy.sh 2>/dev/null|awk -F"/" '{print $NF}')
  	elif [[ ! -z $https_proxy ]];then
  	  opc_proxy=$https_proxy
  	fi
	  if [[ ! -z $opc_proxy ]];then
	    WgetProxy="$opc_proxy"
      WgetInitProxy="$opc_proxy"
	  else
      WgetProxy=noproxy
      WgetInitProxy="noproxy"
	  fi
	fi

	if [[ $protocol = ARU ]];then
		url_list="aru.us.oracle.com:2121"
		if [[ $customer_type != opc ]]&&[[ -z $WgetInitProxy ]];then
  		#WgetInitProxy="www-proxy.oracleoutsourcing.com"
  	  WgetInitProxy="omcs-proxy.oracleoutsourcing.com"
  	fi
	else
		if [[ $(cat /etc/hosts 2>/dev/null|grep occn-updates.oracle-occn.com|grep -v "^#"|wc -l) -gt 0 ]];then 
			url_list="occn-updates.oracle-occn.com updates.oracle.com"
			if [[ -z $WgetProxy ]];then
				WgetInitProxy="noproxy"
			fi
		else
			url_list="updates.oracle.com occn-updates.oracle-occn.com"
			if [[ -z $WgetProxy ]];then
				#WgetInitProxy="www-proxy.oracleoutsourcing.com"
				WgetInitProxy="omcs-proxy.oracleoutsourcing.com"
			fi
		fi
	fi
	for wget_url in $(echo "$url_list");do
		WgetProxy=$WgetInitProxy
		running_statement "WGET connection check [$wget_url]"
		wget_files "$mlink_uname" "$mlink_pwd" "" "connect" "wget_connect.log" "$logdir/wget_connect.adp"
		protocol_status=$(grep STATUS $logdir/protocol.adp 2>/dev/null|awk '{print $2}')
		if [[ $protocol = HTTP ]];then
			if [[ $protocol_status = 1 ]]||[[ $protocol_status = 2 ]];then
				#Do a new check using std/noproxy
				if [[ $WgetInitProxy = noproxy ]];then
					#WgetProxy=www-proxy.oracleoutsourcing.com
					WgetProxy="omcs-proxy.oracleoutsourcing.com"
				else
					WgetProxy=noproxy
				fi	
				wget_files "$mlink_uname" "$mlink_pwd" "" "connect" "wget_connect.log" "$logdir/wget_connect.adp"
				protocol_status=$(grep STATUS $logdir/protocol.adp 2>/dev/null|awk '{print $2}')
			fi
		fi
		if [[ $protocol_status = 4 ]];then
			check_protocol_status "WGET connection check [$wget_url]"
			MlinkSet=1
			rm -f $logdir/protocol.adp >/dev/null
			check_wget_connection
		fi
		if ((!$protocol_status));then
			protocol_connection_check=OK
			break
		fi
	done
	check_protocol_status "WGET connection check [$wget_url]"
	if (($protocol_status))&&[[ $run_mode = silent ]];then
		exit_program $protocol_tag
	fi
fi
}

# Parameter 1 is ending status statement
# Parameter 2 is ok status code
# Parameter 3 is verbose or silent [default verbose]
function check_protocol_status
{
connect_statement=$1
ok_status=${2:-"0"}
display_mode=${3:-verbose}
while [[ ! -r $logdir/protocol.adp ]];do
	sleep 1
done
protocol_status=$(grep STATUS $logdir/protocol.adp 2>/dev/null|awk '{print $2}')
if [[ $protocol_status -gt 0 ]];then
	format_statement "$connect_statement" "failed  "
	if [[ $protocol_status != $ok_status ]];then
		show_protocol_status $protocol_status 
	fi
elif [[ $display_mode = verbose ]];then
	format_statement "$connect_statement" "succeeded"
fi
return $protocol_status
}

function check_disk_space
{
running_statement "Checking disk space requirements for patch $patchnumber ($tech_version)"
patch_size=$(grep $patchzipname $logdir/patchlist.adp 2>/dev/null|awk '{print $2}')
patch_count=$(grep $patchzipname $logdir/patchlist.adp 2>/dev/null|awk '{print $5}')
patch_size=$(echo "$patch_size $patch_count / p q"|dc)
get_free_disk
avail=$(cat $logdir/disk_space.adp 2>/dev/null|awk '{print $1}')
avail_size=$(echo "1000 $avail * p q"|dc)
if [[ $(echo "$patch_size $avail_size / p q"|dc) -gt 0 ]];then
	format_statement "Checking disk space requirements for patch $patchnumber ($tech_version)" "failed  "
	xxecho
	xxecho "      Not enough disk space available to download patch"
	exit_program DiskSpaceError
else
	format_statement "Checking disk space requirements for patch $patchnumber ($tech_version)" "OK      "
fi

}


function download_patch
{
if [[ $protocol = FTP ]];then
	patch_size=$(grep $patchzipname $logdir/patchlist.adp 2>/dev/null|head -1|awk '{print $2}')
	ftp_files "$mlink_uname" "$mlink_pwd" "$patchnumber" "get $patchzipname" "ftp_status.adp" "" "no"
else
	patch_size=$(grep $patchzipname $logdir/patchlist.adp 2>/dev/null|head -1|awk '{print $2}')
	file_count=$(grep $patchzipname $logdir/patchlist.adp 2>/dev/null|head -1|awk '{print $5}')
	patch_size=$(echo "$patch_size $file_count / p q"|dc)
	patch_url=$(grep $patchzipname $logdir/patchlist.adp 2>/dev/null|head -1|awk '{print $3}')
	wget_files "$mlink_uname" "$mlink_pwd" "$patchnumber" "$patch_url" "patch_$patchnumber.log" "$OPATCH_TOP/$patchzipname" "no"
fi

percent_size=0
download_start_time=$(date "+%T")
xxecho "      Download of zip file ($patchzipname) in progress" "N"
running_statement "Download of zip file ($patchzipname)"
while true;do
	sleep 1
	if [[ -r $OPATCH_TOP/$patchzipname ]];then
		current_size=$(ls -lrt $OPATCH_TOP/$patchzipname|awk '{print $5}')
		if [[ $current_size -gt $patch_size ]];then
			percent_size=100
		else
			percent_size=$(echo "100 $current_size * $patch_size / p q"|dc)
		fi
		typeset -L60 line="Download status ($patchzipname)"$space_line
		$echo "      ${line} $percent_size %      \r\c"
	fi
	if [[ -r $logdir/protocol.adp ]];then
		if [[ -r $OPATCH_TOP/$patchzipname ]];then
			$echo "      ${line} 100 %      \r\c"
			echo
		fi
		break
	fi
done
download_end_time=$(date "+%b %d %Y %T")
check_protocol_status "Download of zip file ($patchzipname)"
protocol_status=$?
if (($protocol_status));then
 	if [[ $run_mode = silent ]];then
		exit_program $protocol_tag
	fi
	if [[ $protocol_status = 4 ]];then
		MlinkSet=1
		get_metalink_account
		rm -f $logdir/protocol.adp >/dev/null
		download_patch
	elif [[ $protocol_status = 9 ]];then
		get_restricted_password
		rm -f $logdir/protocol.adp >/dev/null
		download_patch
	fi
else
	update_lang_list $logdir/patch_download.lst "$patchnumber!$lang_code!"
	update_lang_list $logdir/patch_download_zipname.lst "!$patchzipname!"
fi
}

function get_zip_file
{
patchzip_file=$OPATCH_TOP/$patchzipname
zip_loc=OPATCH_TOP
if [[ ! -f $patchzip_file ]];then 
	if [[ -f $OPATCH_STAGE/$patchzipname ]];then 
	  zip_loc=OPATCH_STAGE
		patchzip_file=$OPATCH_STAGE/$patchzipname
  elif [[ -f $OPATCH_STAGE_ZIP/$patchzipname ]];then 
		patchzip_file=$OPATCH_STAGE_ZIP/$patchzipname
	  zip_loc=OPATCH_STAGE_ZIP
	fi
fi
if [[ ! -f $patchzip_file ]];then
  return 1
fi
}

function unzip_patch
{
running_statement "Validating and unzipping $patchzipname"
get_zip_file
if [[ -r $patchzip_file ]];then
	if [[ ! -f $(which unzip 2>/dev/null) ]];then
		format_statement "Validating and unzipping $patchzipname" "failed   "
		xxecho
		xxecho "      Unzip utility can not be found or executed."
		xxecho "      Please ensure that a valid and executable unzip utility is in your path."
		exit_program UnzipError
	fi
  if [[ $(echo $patchzip_file|grep -ic "GENERIC.zip") -gt 0 ]];then
    PATCH_DIR=$PATCH_DIR_ALT
  fi
	unzip -ouCq $patchzip_file -d $PATCH_DIR 2>/dev/null
	if (($?)); then
		format_statement "Validating and unzipping $patchzipname" "failed   "
		xxecho
		xxecho "      Unzip returned error."
		xxecho "      Archive file (.zip) might be damaged or invalid,"
		xxecho "      or you might have run out of diskspace."
		xxecho "      Removing patch directory."
		if [[ $patch_lang = us ]];then
			rm -rf $OPATCH_TOP/$patchnumber > /dev/null 2>&1
		else
			rm -rf $PATCH_DIR > /dev/null 2>&1
		fi
		exit_program UnzipError
	else
		set_patch_dir
	fi
	format_statement "Validating and unzipping $patchzipname" "succeeded"
else
	format_statement "Validating and unzipping $patchzipname" "failed  "
	xxecho
	xxecho "      Zip file can not be read!"
	xxecho "      Please ensure that the the unix user '$unixuid' has read/write rights"
	xxecho "      on the file <$patchzip_file>!"
	exit_program ZipFileError
fi

# Validate if patchdir exists
check_valid_patch $PATCH_DIR
if (($?));then
	# Patch dir does not exist or is invalid
	xxecho
	xxecho "      Patch directory for patch $patchnumber does not exist."
	xxecho "      Please ensure that the patch or zip file is located in"
	xxecho "      the OPATCH_TOP directory!"
	xxecho "      - OPATCH_TOP=$OPATCH_TOP"
	exit_program InvalidPatchError
fi
}

function set_patch_dir
{
if [[ $skip_download = yes ]];then 
  return 0
fi  
permissions_check=${1:-permissions}
opatch_type=opatch
if [[ -d $PATCH_DIR_ALT && $PATCH_DIR != $PATCH_DIR_ALT ]];then
  PATCH_DIR=$PATCH_DIR_ALT
fi
if [[ $(ls $PATCH_DIR/patch-catalog_*xml 2>/dev/null|wc -l) -gt 0 ]];then 
  PATCH_DIR=$PATCH_DIR
  opatch_apply_mode=bsu
  opatch_type=bsu
elif [[ -d $PATCH_DIR/etc ]];then 
  PATCH_DIR=$PATCH_DIR
elif [[ -d $PATCH_DIR/oui/etc ]];then 
	PATCH_DIR=$PATCH_DIR/oui
elif [[ -d $PATCH_DIR/oui/$patchnumber/etc ]];then 
	PATCH_DIR=$PATCH_DIR/oui/$patchnumber
elif [[ -d $PATCH_DIR/opatch/etc ]];then 
	PATCH_DIR=$PATCH_DIR/opatch
elif [[ -d $PATCH_DIR/opatch/$patchnumber/etc ]];then 
	PATCH_DIR=$PATCH_DIR/opatch/$patchnumber
elif [[ -d $PATCH_DIR/$patchnumber/oui/etc ]];then 
	PATCH_DIR=$PATCH_DIR/$patchnumber/oui
elif [[ -d $PATCH_DIR/$patchnumber/oui/$patchnumber/etc ]];then 
	PATCH_DIR=$PATCH_DIR/$patchnumber/oui/$patchnumber
elif [[ -d $PATCH_DIR/$patchnumber/opatch/etc ]];then 
	PATCH_DIR=$PATCH_DIR/$patchnumber/opatch
elif [[ -d $PATCH_DIR/$patchnumber/opatch/$patchnumber/etc ]];then 
	PATCH_DIR=$PATCH_DIR/$patchnumber/opatch/$patchnumber
elif [[ -d $PATCH_DIR/Disk1 ]];then
   PATCH_DIR=$PATCH_DIR
elif [[ -d $PATCH_DIR/cd/Disk1 ]];then
   PATCH_DIR=$PATCH_DIR/cd
elif [[ -d $PATCH_DIR/$patchnumber/Disk1 ]];then
   PATCH_DIR=$PATCH_DIR/$patchnumber
elif [[ -d $PATCH_DIR/$patchnumber/cd/Disk1 ]];then
   PATCH_DIR=$PATCH_DIR/$patchnumber/cd
elif [[ $(ls $PATCH_DIR/*/etc 2>/dev/null|wc -l) -eq 1 ]];then 
	PATCH_DIR=$(dirname $PATCH_DIR/*/etc 2>/dev/null)
elif [[ $(ls $PATCH_DIR/*/ 2>/dev/null|grep etc|wc -l) -gt 1 ]];then 
	PATCH_DIR=$PATCH_DIR
	opatch_apply_mode=napply
elif [[ $(ls $PATCH_DIR/$patchnumber/*/ 2>/dev/null|grep etc|wc -l) -gt 1 ]];then 
	PATCH_DIR=$PATCH_DIR/$patchnumber
	opatch_apply_mode=napply
elif [[ $(ls $PATCH_DIR/*/*/ 2>/dev/null|grep etc|wc -l) -gt 1 ]];then 
	PATCH_DIR=$(eval echo $PATCH_DIR/* 2>/dev/null|awk '{print $1}')
	opatch_apply_mode=napply
elif [[ -d $PATCH_DIR/$patchnumber/etc ]];then 
	PATCH_DIR=$PATCH_DIR/$patchnumber
else	
	patch_location=$(dirname $(find $PATCH_DIR -type d -name etc) 2>/dev/null)
	PATCH_DIR=$patch_location
fi
if [[ ! -d $PATCH_DIR ]];then
  xxecho
  xxecho "   Invalid patch. No valid patch directory found!"
  xxecho "   Please consult README file for special installation instruction!"
  exit_program InvalidPatchError
fi
chmod 777 $PATCH_DIR > /dev/null 2>&1
if [[ $permissions_check = permissions ]];then
  chmod -R a+rx $PATCH_DIR/* > /dev/null 2>&1
fi
if [[ -f $PATCH_DIR/Disk1/stage/products.xml ]];then 
  # This is runInstaller patch
  runinstaller_base=$PATCH_DIR/Disk1 
  runinstaller_loc=$(dirname $(find $runinstaller_base -name runInstaller -type f 2>/dev/null|head -1)) 
  if [[ -d $runinstaller_loc ]];then
    chmod +x $runinstaller_loc/* 2>/dev/null
  fi
  runinstaller_xml=$runinstaller_base/stage/products.xml
  toplevel_component=$(grep "<COMP" $runinstaller_xml|awk -F"=" '{print $2}'|awk '{print $1}'|sed 's%\"%%g'|head -1)
  for installer_type in $(echo "PATCHSET PATCH COMP");do
    toplevel_component_version=$(grep "<$installer_type" $runinstaller_xml|grep "\"$toplevel_component\"" |awk -F"=" '{print $3}'|awk '{print $1}'|sed 's%\"%%g'|head -1)
    if [[ ! -z $toplevel_component_version ]];then
      toplevel_component_ver_num=$(echo "$toplevel_component_version"|sed 's%.%%g')
      break
    fi
  done
  for dependency_comp in $(grep "<COMP" $runinstaller_xml|awk -F"=" '{print $2}'|awk '{print $1}'|sed 's%\"%%g' |sort -u);do
    for installer_type in $(echo "PATCHSET PATCH COMP");do
      dep_component_version=$(grep "<$installer_type" $runinstaller_xml|grep "\"$dependency_comp\"" |awk -F"=" '{print $3}'|awk '{print $1}'|sed 's%\"%%g'|head -1)
      if [[ ! -z $dep_component_version ]]&&[[ $(echo " $dependency_list "|sed 's%,% %g'|grep " $dependency_comp:$dep_component_version "|wc -l) -eq 0 ]];then
        dependency_list="$dependency_list,$dependency_comp:$dep_component_version"
      fi
    done
  done
  dependency_list=$(echo $dependency_list|sed 's%,,*%,%g'|sed 's%^,%%g'|sed 's%,$%%g')
  opatch_type=runInstaller
fi

}

function create_patch_log
{
# Create patch log dir
xxecho "   Checking for patch log directory..."
if [[ -d $patchlog/$patchdir ]]; then
		# Patch log directory exists
		xxecho "      Patch log directory already exists."
else
	create_dir $patchlog/$patchdir "Patch log directory"
fi
if [[ ! $tarnumber = "" ]];then
	touch $patchlog/$patchdir/TAR#$tarnumber > /dev/null 2>&1
fi
}

function display_readme
{
rm -f $logdir/COUNTREADME > /dev/null 2>&1
readme_log=$logdir/rdme.txt
count_readme=0
echo "   Readme file(s) for patch $patchnumber ($tech_version):" > $readme_log
echo "" >> $readme_log
if [[ $(find $PATCH_DIR 2>/dev/null|grep -i readme|wc -l) -eq 0 ]]; then
	xxecho
	xxecho "   Readme file(s) for patch $patchnumber:"
	xxecho "      There are no available readme file(s) for patch $patchnumber!"
else
	find $PATCH_DIR 2>/dev/null|grep -i readme|sort -u|while read file; do
		((count_readme+=1))
		echo "   $count_readme) $(echo $file|sed s%$PATCH_DIR/%%g)" >> $readme_log
		echo $count_readme > $logdir/COUNTREADME
	done
	echo "   X) Don't display (more) readme files" >> $readme_log
	echo >> $readme_log
	count_readme=$(cat $logdir/COUNTREADME)
	while true;do
	line_statement
	cat $readme_log
	if [[ $count_readme -eq 1 ]]; then
		read_count="1"
	else
		read_count="1-$count_readme"
	fi
	xxecho "   Please select which readme file you would like to read [$read_count|X] ? " N
	xxecho "   Waiting for answer ..." N
	read select_readme?"   Please select which readme file you would like to read [$read_count|X] ? "
	case $select_readme in
	[Xx]) 	xxecho "   Answer provided was 'X'" N
			break;;
	[a-z|A-Z]) ;;
	*)	if [[ $select_readme -ge 1 ]]&&[[ $select_readme -le $count_readme ]];then
			xxecho "   Displaying readme number $select_readme" N 
			echo
			readme_file=$PATCH_DIR/$(cat $readme_log 2>/dev/null|grep "$select_readme)"|awk '{print $2}')
			if [[ $(echo $readme_file|grep .html|wc -l) -gt 0 ]];then
				line_statement
				# Check if LYNX is available on tier
				use_sed=N
				if [[ ! -f $(which lynx 2>/dev/null) ]];then
					if [[ -f /usr/bin/lynx ]];then
						LYNX=/usr/bin/lynx
					elif [[ -f /usr/sbin/lynx ]];then
						LYNX=/usr/sbin/lynx
					else
						LYNX=""
						use_sed=Y
					fi
				else
					LYNX=$(which lynx 2>/dev/null)
				fi
				if [[ -f $LYNX ]];then
					$LYNX -dump $readme_file| sed -e 's/[   ]*$//' > $logdir/html_readme
					if (($?))||[[ ! -f $logdir/html_readme ]];then
						use_sed=Y
					fi
				fi
				if [[ $use_sed = Y ]];then
						# Create a sed-file for removing HTML tags
						echo "/{/,/}/ {"  > $logdir/remove_tag.sed
						echo "d" >>  $logdir/remove_tag.sed
						echo "}" >>  $logdir/remove_tag.sed
						echo "s/<[^<]*>//g" >>  $logdir/remove_tag.sed
						echo "s/&nbsp//g" >>  $logdir/remove_tag.sed
						echo "s/[   ]*\$//g" >>  $logdir/remove_tag.sed
						echo "/.Ora/d" >>  $logdir/remove_tag.sed
						echo "s/\\r//g" >>  $logdir/remove_tag.sed
						sed -f $logdir/remove_tag.sed $readme_file|grep -v "^$" > $logdir/html_readme
				fi
				more $logdir/html_readme
			else
				more $readme_file
			fi
			xxecho
			xxecho "    Press <return> to continue ..." N
			read anykey?"   Press <return> to continue ..."
		fi;;
	esac
	clear
	done
fi
}

# Get versions
# Parameter 1 is current file including path
# Parameter 2 is new file including path
function get_versions
{
cur_version=0
new_version=0

for cur_version in $(strings -a $1|grep \$Header 2> /dev/null|grep -v header_string|awk '{print $5" "$4" "$3}');do
	if [[ $(echo $cur_version|egrep '115.|120.'|wc -l) -gt 0 ]];then
		cur_version_name=$cur_version
		cur_version_full=$cur_version
		break
	fi
done 
for new_version in $(strings -a $2|grep \$Header 2> /dev/null|grep -v header_string|awk '{print $5" "$4" "$3}');do
	if [[ $(echo $new_version|egrep '115.|120.'|wc -l) -gt 0 ]];then
		new_version_name=$new_version
		new_version_full=$new_version
		break
	fi
done 
if [[ $cur_version = "" ]];then 
	cur_version_name=UNKNOWN
	cur_version_full=0
fi
if [[ $new_version = "" ]];then 
	new_version_name=UNKNOWN
	new_version_full=1
fi


if [[ $cur_version_full = $new_version_full ]];then
	cur_version=0
	new_version=0
else
	count=1
	while [[ $count -le 10 ]];do
		nvalue[$count]=0
		cvalue[$count]=0
		((count+=1))
	done
	vcount=1
	for new_value in $(echo $new_version_full|sed 's%\.% %g');do
		nvalue[$vcount]=$new_value
		((vcount+=1))
	done
	vcount=1
	for cur_value in $(echo $cur_version_full|sed 's%\.% %g');do
		cvalue[$vcount]=$cur_value
		((vcount+=1))
	done
	count=1
	while [[ $count -le 10 ]];do
		if [[ ${nvalue[$count]} = ${cvalue[$count]} ]];then
			((count+=1))
		elif [[ ${nvalue[$count]} -gt ${cvalue[$count]} ]];then
			new_version=1
	    cur_version=0
	    break
	  elif [[ ${nvalue[$count]} -lt ${cvalue[$count]} ]];then
	  	new_version=0
	    cur_version=1
	    break
	  fi
	done
fi
}


# Parameter 1 is 'from' patchdir
# Parameter 2 is 'to' patchdir
# Parameter 3 is check of write permissions yes/no (no is default)
function move_patch_dir
{
check_perm=${3:-"no"}
from_dir=$(basename $1)
to_dir=$(basename $2)
running_statement "Moving patch directory from \$OPATCH_TOP/$from_dir to \$OPATCH_TOP/$to_dir"
# Move patch directory so that NLS patches are able to be applied noninteractively
if [[ -d $2 ]];then
	count_unknown=$(ls $2_UNKNOWN* 2>/dev/null|wc -l)
	((count_unknown+=1))
	mv $2 ${2}_UNKNOWN$count_unknown > /dev/null 2>&1
	move_error=$?
fi
mkdir -p $2 2>/dev/null
chmod 777 $2 2>/dev/null
chmod 777 $1 2>/dev/null
mv $1 $2/ > /dev/null 2>&1
move_error=$?
chmod -R a+rx $2/$from_dir/* 2>/dev/null
chmod 777 $2/$from_dir 2>/dev/null
if (($move_error)); then
	format_statement "Moving patch directory from \$OPATCH_TOP/$from_dir to \$OPATCH_TOP/$to_dir" "failed  "
	xxecho
	xxecho "   Unable to move patchdirectory from:"
	xxecho "   - $1"
	xxecho "   to:"
	xxecho "   - $2"
	xxecho
	xxecho "   Please check read/write permissions on directories."
	return 1
else
	format_statement "Moving patch directory from \$OPATCH_TOP/$from_dir to \$OPATCH_TOP/$to_dir" "succeeded"
fi

# Test to see if write permissions are OK
if [[ $check_perm = yes ]];then
	touch $2/$from_dir/opatch.test > /dev/null 2>&1
	if (($?));then
		xxecho
		xxecho "   Unable to create test file in patch directory."
		xxecho
		xxecho "   Please check read/write permissions on patch directory:"
		xxecho "   - $1"
		mv $2/$from_dir $1 > /dev/null 2>&1
		return 1
	else
		rm -f $2/$from_dir/opatch.test > /dev/null 2>&1
	fi
fi
}

function check_write_permissions
{
# Test to see if write permissions are OK
touch $1/opatch.test > /dev/null 2>&1
if (($?));then
	xxecho
	xxecho "   Unable to create test file in patch directory."
	xxecho
	xxecho "   Please check read/write permissions on patch directory:"
	xxecho "   - $1"
	return 1
else
	rm -f $1/opatch.test > /dev/null 2>&1
fi
}


function apply_patch
{
# Force to use noninteractive mode if running without tty on screen
if [[ $LogStatement = notty ]];then
	interactivemode=no
	restart_mode=y
fi
if [[ $interactivemode = yes ]];then 
  silent_mode=""
else 
  silent_mode="-silent"
fi 

line_statement
if [[ $opatch_type = bsu ]];then
  location_statement="   [BSU_LOC=$BSU_LOC]"
else
  location_statement="   [ORACLE_HOME=$TARGET_ORACLE_HOME]"
  id_statement=""
  if [[ $opatch_apply_mode = napply && ! -z $opatch_patch_id ]];then 
    id_statement="-id $opatch_patch_id"
  elif [[ $patch_option = rollback ]];then 
    if [[ -z $opatch_patch_id ]];then 
      opatch_patch_id=$patchnumber
    fi
    id_statement="-id $opatch_patch_id"
  fi
fi
logfile=$patchlog/$patchdir/${opatch_type}_${patchnumber}_${patch_option}.log
logname=$(basename $logfile)

if [[ $patch_option = rollback ]];then
  if [[ $opatch_apply_mode = napply ]];then 
    opatch_rollback_mode=nrollback
  else 
    opatch_rollback_mode=rollback
  fi
  apply_statement="   Rolling back patch $patchnumber ($tech_version) using $opatch_type..."
  xxecho "$apply_statement"
  xxecho "$location_statement"
  xxecho
  xxecho "   Patch is being rolled back with following parameters:" N
  if [[ $opatch_type = bsu ]];then 
    id=$(grep $patchnumber $logdir/bsu_patches.id 2>/dev/null|awk -F":" '{print $2}')
    xxecho "   id=$id" N
  else 
    xxecho "   rollback mode: $opatch_rollback_mode" N
    xxecho "   $id_statement" N
  fi
  xxecho "   patchtop=$PATCH_DIR" N
  xxecho "   logfile=$logname" N
  xxecho "   options=$patch_options" N
else  
  apply_statement="   Applying patch $patchnumber ($tech_version) using $opatch_type..."
  xxecho "$apply_statement"
  xxecho "$location_statement"
  xxecho
  xxecho "   Patch is being applied with following parameters:" N
  xxecho "   patchtop=$PATCH_DIR" N
  xxecho "   logfile=$logname" N
  xxecho "   options=$patch_options" N
  xxecho "   apply=$apply_mode" N
fi
echo "$$" > $patchlog/$patchdir/$$.pid
  if [[ -f $logfile ]];then
    mv $logfile $logfile.$LogDate >/dev/null 2>&1
  fi
  # We only check if patch is applied first as per user option
  if [[ $opatch_type = runInstaller ]];then 
    cd $runinstaller_loc >/dev/null 2>&1
    runinstaller_memory_change $runinstaller_loc
    if [[ ! -z $dependency_list ]];then
      dependency_cmd="DEPENDENCY_LIST=$(echo "{\"$dependency_list\"}"|sed 's%,%\",\"%g')"
    fi
    xxecho "   COMMAND: cd $runinstaller_loc" N
    if [[ $patch_option = rollback ]];then 
      runInstaller_type="-deinstall DEINSTALL_LIST='{\"$toplevel_component\",\"$toplevel_component_version\"}'"
    else
      runInstaller_type="TOPLEVEL_COMPONENT='{\"$toplevel_component\",\"$toplevel_component_version\"}'"
    fi
    if (($set_linux32));then
      LD_EMULATION=elf_i386
      export LD_EMULATION
      xxecho "   COMMAND: ./runInstaller $silent_mode -force -ignoreSysPrereqs -ignoreDiskWarning -invPtrLoc $inv_file \\" N
      xxecho "   FROM_LOCATION=\"$runinstaller_xml\" ORACLE_HOME=\"$TARGET_ORACLE_HOME\" ORACLE_HOME_NAME=\"$oh_name\" $runInstaller_type $dependency_cmd DECLINE_SECURITY_UPDATES=TRUE \\" N
      xxecho "   SELECTED_LANGUAGES={\"en\"} ACCEPT_LICENSE_AGREEMENT=true INSTALL_TYPE=\"Custom\"" N
      echo "./runInstaller $silent_mode -force -ignoreSysPrereqs -ignoreDiskWarning -invPtrLoc $inv_file FROM_LOCATION=\"$runinstaller_xml\" ORACLE_HOME=\"$TARGET_ORACLE_HOME\" ORACLE_HOME_NAME=\"$oh_name\" $runInstaller_type $dependency_cmd DECLINE_SECURITY_UPDATES=TRUE SELECTED_LANGUAGES={\"en\"} ACCEPT_LICENSE_AGREEMENT=true INSTALL_TYPE=\"Custom\"" > $patchlog/$patchdir/runInstall.sh
      echo "echo \"STATUS \$?\" > $patchlog/$patchdir/runinstaller_status.log" >> $patchlog/$patchdir/runInstall.sh
      #echo "exit" >>  $patchlog/$patchdir/runInstall.sh
      chmod 755 $patchlog/$patchdir/runInstall.sh
      linux32 $patchlog/$patchdir/runInstall.sh |tee -a $logfile
      retval=$(grep STATUS $patchlog/$patchdir/runinstaller_status.log|awk '{print $2}')
	  else
      xxecho "   COMMAND: ./runInstaller $silent_mode -force -ignoreSysPrereqs -ignoreDiskWarning -invPtrLoc $inv_file \\" N
      xxecho "   FROM_LOCATION=\"$runinstaller_xml\" ORACLE_HOME=\"$TARGET_ORACLE_HOME\" ORACLE_HOME_NAME=\"$oh_name\" $runInstaller_type $dependency_cmd DECLINE_SECURITY_UPDATES=TRUE \\" N
      xxecho "   SELECTED_LANGUAGES={\"en\"} ACCEPT_LICENSE_AGREEMENT=true INSTALL_TYPE=\"Custom\"" N
      ./runInstaller $silent_mode -force -ignoreSysPrereqs -ignoreDiskWarning -invPtrLoc $inv_file \
      FROM_LOCATION="$runinstaller_xml" ORACLE_HOME="$TARGET_ORACLE_HOME" ORACLE_HOME_NAME="$oh_name" $runInstaller_type $dependency_cmd DECLINE_SECURITY_UPDATES=TRUE SELECTED_LANGUAGES={"en"} ACCEPT_LICENSE_AGREEMENT=true INSTALL_TYPE="Custom" |tee -a $logfile
      retval=$?
    fi
    if ((!$retval));then
      retval=$(grep -c "^Error:" $logfile 2>/dev/null)
    fi
    cd - >/dev/null 2>&1
  elif [[ $opatch_type = bsu ]];then 
    cd $BSU_LOC >/dev/null 2>&1
    if ((!$?));then
      if [[ $patch_option != rollback ]];then 
        for file in $(ls $PATCH_DIR/*|grep -v README);do
          file_name=$(basename $file)
          if [[ ! -e $BSU_LOC/cache_dir/$file_name ]];then 
            cp -r $file $BSU_LOC/cache_dir/ 2>/dev/null
          fi
        done
        rm $BSU_LOC/cache_dir/README.txt 2>/dev/null
      fi
      for bsu_patch_info in $(grep $patchnumber $logdir/bsu_patches.id 2>/dev/null|sort -u);do
        bsu_patch_id=$(echo $bsu_patch_info|awk -F":" '{print $2}')
        bsu_log=$patchlog/$patchdir/${patch_option}_${patchnumber}_$bsu_patch_id.log
        while true;do
          rm $bsu_log  2>/dev/null
          xxecho "   COMMAND: cd $BSU_LOC" N
          if [[ $patch_option = rollback ]];then 
            xxecho "   COMMAND: ./bsu.sh -remove -patchlist=$bsu_patch_id -prod_dir=$WLS_OHOME -log=$bsu_log -log_priority=debug" N
            ./bsu.sh -remove -patchlist=$bsu_patch_id -prod_dir=$WLS_OHOME -log=$bsu_log -log_priority=debug 2> $logfile|tee -a $logfile
            retval=$?
          else
            xxecho "   COMMAND: ./bsu.sh -install -patch_download_dir=$BSU_LOC/cache_dir -patchlist=$bsu_patch_id -prod_dir=$WLS_OHOME -log=$bsu_log -log_priority=debug" N
          	./bsu.sh -install -patch_download_dir=$BSU_LOC/cache_dir -patchlist=$bsu_patch_id -prod_dir=$WLS_OHOME -log=$bsu_log -log_priority=debug 2> $logfile|tee -a $logfile 
            retval=$?
          fi
          # Check for conflicts 
          if [[ $(grep "Validation error found" $bsu_log 2>/dev/null|wc -l) -gt 0 ]];then
            conflict_patch_id=$(grep "Validation error found" $bsu_log|egrep 'exclusive|removed'|awk -F":" '{print $5}'|awk '{print $1}')
            if [[ ! -z $conflict_patch_id ]];then
              xxecho
              if [[ $run_option = force ]];then
                xxecho "   Following conflict patch(es) will be rolled back in order to $patch_option patch"
              else
                xxecho "   Following conflict patch(es) should be rolled back in order to $patch_option patch"
              fi
              xxecho "   $patchnumber ($bsu_patch_id):"
              for conflict_id in $(echo $conflict_patch_id|sed 's%,% %g'|sort -u);do
                conflict_patch=$(grep "$conflict_id" $logdir/patch_applied.adp)
                conflict_patch=${conflict_patch:-":$conflict_patch_id"}
                echo "$conflict_patch"  >> $logdir/conflict_patches.adp
                xxecho "   -> $conflict_patch"                 
              done  
              if [[ $run_option = force ]];then
                line_statement
                rollback_wls_conflict
                if (($?));then 
                  exit_program PatchConflictError
                else 
                  xxecho "$apply_statement"
                  xxecho "$location_statement"
                  xxecho
                fi
              else
                xxecho
                xxecho "   Conflict patch(es) can be rolled back by doing:"
                for conlict_patch in $(cat $logdir/conflict_patches.adp);do
                  conflict_number=$(echo $conlict_patch|awk -F":" '{print $1}')
                  xxecho "     $opatch_script_name -rollback $conflict_number -type $tech_type"
                done
                exit_program PatchConflictError
              fi
            fi
            required_patch_id=$(grep "Validation error found" $bsu_log 2>/dev/null|grep "requires"|awk -F":" '{print $5}'|awk '{print $1}')
            if [[ ! -z $required_patch_id ]];then
              xxecho
              xxecho "   Following required prereq patch should be applied prior to applying patch"
              xxecho "   $patchnumber ($bsu_patch_id):"
              xxecho "   -> $required_patch_id"   
              xxecho
              xxecho "   Required patch can be applied by doing:"
              xxecho "     $opatch_script_name -apply <patch_for_patch_id_$required_patch_id> -type $tech_type"
              exit_program PatchConflictError
            fi
            if [[  -z $required_patch_id && -z $conflict_patch_id ]];then 
              exit_program PatchConflictError
            fi
          else 
            break 
          fi
        done 
        if [[ $(grep "unrecognized patch ID" $logfile 2>/dev/null|wc -l) -gt 0 ]];then
          xxecho
          xxecho "   Unrecognized patch ID found [$bsu_patch_id]"
          xxecho "   Patch failed to apply"
          retval=1
          break
        fi
        if [[ $(grep "Result: Failure" $logfile 2>/dev/null|wc -l) -gt 0 ]];then
          xxecho
          xxecho "   Unknown failure. Patch failed to $patch_option"
          retval=1
          break
        fi
        if [[ $(grep "java.lang.OutOfMemoryError" $logfile 2>/dev/null|wc -l) -gt 0 ]]||[[ $(grep "java.lang.OutOfMemoryError" $bsu_log 2>/dev/null|wc -l) -gt 0 ]];then
          xxecho
          xxecho "   Memory failure. Patch failed to $patch_option"
          xxecho "   Possibly fix is to increase MEM_ARGS setting in \$BSU_LOC/bsu.sh"
          xxecho "   to higher values!"
          retval=1
          break
        fi
      done
    fi
    cd - >/dev/null 2>&1
  else
    if [[ $patch_option = rollback ]];then 
      if [[ -d $PATCH_DIR ]];then
        xxecho "   COMMAND: $opatch_exe $opatch_rollback_mode $id_statement -invPtrLoc $inv_file $silent_mode -oh $TARGET_ORACLE_HOME -ph $PATCH_DIR" N
     	  $opatch_exe $opatch_rollback_mode $id_statement -invPtrLoc $inv_file $silent_mode -oh $TARGET_ORACLE_HOME -ph $PATCH_DIR |tee -a $logfile
        retval=$?
      else 
        xxecho "   COMMAND: $opatch_exe $opatch_rollback_mode $id_statement -invPtrLoc $inv_file $silent_mode -oh $TARGET_ORACLE_HOME" N
     	  $opatch_exe $opatch_rollback_mode $id_statement -invPtrLoc $inv_file $silent_mode -oh $TARGET_ORACLE_HOME |tee -a $logfile
        retval=$?
      fi
    else
      opatch_use_subset=$($opatch_exe $opatch_apply_mode -h -oh $TARGET_ORACLE_HOME 2>/dev/null|grep "skip_subset"|wc -l)
      if (($opatch_use_subset));then
        xxecho "   COMMAND: $opatch_exe $opatch_apply_mode $id_statement $PATCH_DIR -invPtrLoc $inv_file $silent_mode -skip_subset -skip_duplicate $ocmrf -oh $TARGET_ORACLE_HOME $force_option" N
     	  $opatch_exe $opatch_apply_mode $id_statement $PATCH_DIR -invPtrLoc $inv_file $silent_mode -skip_subset -skip_duplicate $ocmrf -oh $TARGET_ORACLE_HOME $force_option|tee -a $logfile
        retval=$?
      else
        xxecho "   COMMAND: $opatch_exe $opatch_apply_mode $id_statement $PATCH_DIR -invPtrLoc $inv_file $silent_mode $ocmrf -oh $TARGET_ORACLE_HOME $force_option" N
       	$opatch_exe $opatch_apply_mode $id_statement $PATCH_DIR -invPtrLoc $inv_file $silent_mode $ocmrf -oh $TARGET_ORACLE_HOME $force_option|tee -a $logfile
        retval=$?
      fi
    fi
    if [[ $(grep "ERROR: OPatch" $logfile|wc -l) -gt 0 || $(grep "OPatch failed" $logfile|wc -l) -gt 0 ]]&& [[ $(grep "OPatch succeeded" $logfile|wc -l) -eq 0 ]];then 
      retval=1
    elif [[ $(grep "not needed since it has no fixes" $logfile|wc -l) -gt 0 ]];then
      retval=0
    fi
  fi
  # Confirm patch was applied successfully
#  check_patch_applied $patchnum

rm -f $patchlog/$patchdir/$$.pid 2>/dev/null
remove_log_status=1
return $retval
}

function rollback_wls_conflict
{
rollback_status=0
for bsu_rollback_info in $(cat $logdir/conflict_patches.adp 2>/dev/null);do
  rollback_patchnumber=$(echo $bsu_rollback_info|awk -F":" '{print $1}')
  rollback_patchid=$(echo $bsu_rollback_info|awk -F":" '{print $2}')
  rollback_patchnumber=${rollback_patchnumber:-UNKNOWN}
  xxecho "   Rolling back patch $rollback_patchnumber [$rollback_patchid]..."
  xxecho "   COMMAND: ./bsu.sh -remove -patchlist=$rollback_patchid -prod_dir=$WLS_OHOME -log=$patchlog/rollback_$rollback_patchid.log -log_priority=debug" N
  xxecho
  ./bsu.sh -remove -patchlist=$rollback_patchid -prod_dir=$WLS_OHOME -log=$patchlog/rollback_$rollback_patchid.log -log_priority=debug 2> $logfile|tee -a $logfile
  ((rollback_status+=$?))
  line_statement
done 
return $rollback_status
}

function show_logfiles
 {
target_home_set=0
if [[ ! -z $patchdir ]];then
  log_patch_dir="${patchlog}/$patchdir"
else
  log_patch_dir="${patchlog}"
fi  
if [[ $(echo $log_patch_dir|grep $TECH_LOG|wc -l) -gt 0 ]];then
	log_patch_dir=$(echo $log_patch_dir|sed s%$TECH_LOG%\$TECH_LOG%g)
	target_home_set=1
fi
xxecho "   -----------------------------  LOG FILES  -------------------------------"
xxecho "   Logfiles have been moved to:"
xxecho "   $log_patch_dir"
if [[ -f $patchlog/$patchdir/$LogName ]];then
	xxecho
	xxecho "   $opatch_script_name logfile:"
	xxecho "   -> $log_patch_dir/$LogName"
fi
if [[ -f $conflict_logfile ]];then 
	xxecho
	xxecho "   $opatch_type conflict check logfile:"
  xxecho "   -> $log_patch_dir/${opatch_type}_${patchnumber}_conflicts.log"
fi
if [[ -f $logfile ]];then 
	xxecho
	xxecho "   $opatch_type logfile:"
  xxecho "   -> $log_patch_dir/$(basename $logfile)"
fi
if (($target_home_set));then
  xxecho
  xxecho "   [TECH_LOG=$TECH_LOG]"
fi
if [[ -d $PATCH_DIR ]];then
  xxecho
  xxecho "   --------------------------  PATCH DIRECTORY  ----------------------------"
  xxecho "   Patch available at:"
  if [[ $(echo $PATCH_DIR|grep -c $OPATCH_TOP) -gt 0 ]];then
    opatch_loc=$(echo $PATCH_DIR|sed "s%$OPATCH_TOP/%%g")
    xxecho "   -> \$OPATCH_TOP/$opatch_loc"
    xxecho
    xxecho "   [OPATCH_TOP=$OPATCH_TOP]"
  else
    xxecho "   -> $PATCH_DIR"
  fi
fi
  
}

function move_patch_log
{
# Move logfiles to log/patchnumber
if (($patch_log_move_status));then
	xxecho "   Backing up logfiles (\$TECH_LOG/$patchdir)..."
	running_statement "Moving patch log files to \$TECH_LOG/$patchdir"
	if [[ ! -d $patchlog/$patchdir ]];then
		mkdir $patchlog/$patchdir 2>/dev/null
	fi
	if (($remove_log_status));then
		ls -F $patchlog|sed '/\//d'|while read file;do
			mv $patchlog/$file $patchlog/$patchdir > /dev/null 2>&1
		done
	else
		mv $LogFile $patchlog/$patchdir > /dev/null 2>&1
	fi
	LogFile=$patchlog/$patchdir/$LogName
	format_statement "Moving patch log files to \$TECH_LOG/$patchdir" "completed"
	xxecho
	patch_log_move_status=0
fi

}

function clean_files
{
	clean_error=0
	xxecho "   ------------------------  CLEAN OPATCH_TOP FILES  ------------------------"
	xxecho "   Cleaning up patches and patch directories..."
	if [[ -d $PATCH_DIR ]];then
		running_statement "Removing patch directory \$OPATCH_TOP/$patchdir"
		rm -rf $PATCH_DIR 2>/dev/null
		status_statement "Removing patch directory \$OPATCH_TOP/$patchdir" $?
		((clean_error+=$?))
	fi
	ls $OPATCH_TOP/p${patchnumber}*zip 2>/dev/null|egrep "GENERIC|generic|Generic|$patch_ext|$patch_ext2"|grep $tech_version|while read file;do
		zipfile=$(basename $file)
		running_statement "Removing zip file $zipfile"
		rm $file 2>/dev/null
		status_statement "Removing zip file $zipfile" $?
		((clean_error+=$?))
	done
	if (($clean_error));then
		xxecho 
		xxecho "   Unable to remove patch file(s)/dir(s)..."
		if [[ -d $PATCH_DIR ]];then
			xxecho "   - \$OPATCH_TOP/$patchdir"
		fi
		if [[ -f $OPATCH_TOP/$zipfile ]];then
			xxecho "   - \$OPATCH_TOP/$zipfile"
		fi
		xxecho
		xxecho "   Please remove file(s)/dir(s) manually !"
	fi	
}


# Function TimeCalc
# this function will calculate the duration given the start
# and end time....
# Parameter 1 is start time in format Mon DD YYYY HH:MM:SS
# Parameter 2 is end time in format Mon DD YYYY HH:MM:SS
# Parameter 3 is add or sub (add or subtract), default = sub
# Parameter 4 is cout or sout (standard or calculated output), default = sout
# Function will return HH Hours MM Minutes SS Seconds
# or HH:MM:SS
function TimeCalc
{
#StartTime="Nov 02 2006 20:41:41"
#DoneTime="Nov 02 2006 20:41:41"

StartTime=$1   #name of function
DoneTime=$2    #done time for a given function
DefaultDate=$(date "+%b %d %Y")
if [[ $StartTime = "" ]];then
	StartTime="$DefaultDate 00:00:00"
elif [[ $(echo $StartTime|wc -w) -eq 1 ]];then
	StartTime="$DefaultDate $StartTime"
fi
if [[ $DoneTime = "" ]];then
	DoneTime="$DefaultDate 00:00:00"
elif [[ $(echo $DoneTime|wc -w) -eq 1 ]];then
	DoneTime="$DefaultDate $DoneTime"
fi
TimeAction=${3:-sub}
TimeAction=$(echo $TimeAction | awk '{print tolower($1)}')
case $TimeAction in
	sub | add) ;;
	*) return 1;;
esac
TimeOutput=${4:-sout}
TimeOutput=$(echo $TimeOutput | awk '{print tolower($1)}')
case $TimeOutput in
	cout | sout) ;;
	*) return 1;;
esac                       

SYEAR=$(echo $StartTime|awk '{print $3}')
convert_month $(echo $StartTime|awk '{print $1}')
SMONTH=$month
SDAY=$(echo $StartTime|awk '{print $2}')
SHOUR=$(echo $StartTime|awk '{print $4}'|awk -F":" '{print $1}')
SMIN=$(echo $StartTime|awk '{print $4}'|awk -F":" '{print $2}')
SSEC=$(echo $StartTime|awk '{print $4}'|awk -F":" '{print $3}')

EYEAR=$(echo $DoneTime|awk '{print $3}')
convert_month $(echo $DoneTime|awk '{print $1}')
EMONTH=$month
EDAY=$(echo $DoneTime|awk '{print $2}')
EHOUR=$(echo $DoneTime|awk '{print $4}'|awk -F":" '{print $1}')
EMIN=$(echo $DoneTime|awk '{print $4}'|awk -F":" '{print $2}')
ESEC=$(echo $DoneTime|awk '{print $4}'|awk -F":" '{print $3}')

# convert time to seconds
((TSSEC=SHOUR*3600+SMIN*60+SSEC))
((TESEC=EHOUR*3600+EMIN*60+ESEC))

if [[ $TimeAction = add ]];then
	#
	#calculate sum of hours
	#
	TDSEC=$(((TESEC+TSSEC)))
else
	set_leapyear_var
	# calculate julian dates
	if leapyear $SYEAR;then
		((ju1=${mol[SMONTH]}+SDAY))
	else
		((ju1=${mos[SMONTH]}+SDAY))
	fi
	if leapyear $EYEAR;then
		((ju2=${mol[EMONTH]}+EDAY))
	else
		((ju2=${mos[EMONTH]}+EDAY))
	fi
	# possibly first lower the epoch year
	while ((epoch>SYEAR));do
		((epoch=epoch-1))
	done
	while ((epoch>EYEAR));do
		((epoch=epoch-1))
	done
	
	# convert year and julian dates to seconds
	((yr=epoch))
	while ((yr<SYEAR));do
		if leapyear $yr;then
			((TSSEC=TSSEC+secl))
		else
			((TSSEC=TSSEC+secy))
		fi
		((yr=yr+1))
	done
	((TSSEC=TSSEC+ju1*secd))
	((yr=epoch))
	while ((yr<EYEAR));do
		if leapyear $yr;then
			((TESEC=TESEC+secl))
		else
			((TESEC=TESEC+secy))
		fi
		((yr=yr+1))
	done
	((TESEC=TESEC+ju2*secd))
	
	# calculate difference in seconds
	((TDSEC=TESEC-TSSEC))
fi

#
#calculate elapsed hours
#

H=$(((TDSEC/3600)))

#
#calculate elapsed minutes
#
    HiS=$(((3600*H)))
    TMS=$(((TDSEC-HiS)))
    M=$(((TMS/60)))
#
#calculate elapsed seconds
#
    MiS=$(((M*60)))
    S=$(((TMS-MiS)))

for i in H M S;do
	if [[ $(eval echo '${#'$i''}) = 1 ]];then
		eval $i="0$(eval echo '$'$i'')"
	fi
done
case $TimeOutput in
	sout)   time_calc="$H Hours $M Minutes $S Seconds";;
	*)   time_calc="$H:$M:$S";;
esac
}

function convert_month
{
month=$1
case $month in
	Jan)	month=1;;
	Feb)	month=2;;
	Mar)	month=3;;
	Apr)	month=4;;
	May)	month=5;;
	Jun)	month=6;;
	Jul)	month=7;;
	Aug)	month=8;;
	Sep)	month=9;;
	Oct)	month=10;;
	Nov)	month=11;;
	Dec)	month=12;;
esac
}

# shell function to check for leap year
function leapyear
{
((l=1))
((r4=$1%4))
((r100=$1%100))
((r400=$1%400))
if ((r4==0));then
	if ((r100!=0));then
	((l=0))
	else
		if ((r400==0));then
			((l=0))
		fi
	fi
fi
return $l
}

function set_leapyear_var
{
# days preceding a month for standard and leap year
mos[1]=0     mol[1]=0
mos[2]=31    mol[2]=31
mos[3]=59    mol[3]=60
mos[4]=90    mol[4]=91
mos[5]=120   mol[5]=121
mos[6]=151   mol[6]=152
mos[7]=181   mol[7]=182
mos[8]=212   mol[8]=213
mos[9]=243   mol[9]=244
mos[10]=273  mol[10]=274
mos[11]=304  mol[11]=305
mos[12]=334  mol[12]=335

# seconds in a year, leapyear and day
((secy=365*24*60*60))
((secl=366*24*60*60))
((secd=24*60*60))

# maybe the epoch year needs to be lowered further on
epoch=2000
}

function create_patch_info
{
count_info=$(ls $patchlog/$patchdir/PatchInfo* 2> /dev/null|wc -l)
((count_info+=1))
echo "   -------------------------------------------------------------------------" > $patchlog/$patchdir/PatchInfo$count_info.log
if [[ $patch_option = rollback ]];then
  echo "    Patch $patchnumber ($tech_version) successfully rolled back on $ENV_NAME ($(hostname))!" >> $patchlog/$patchdir/PatchInfo$count_info.log
else
  echo "    Patch $patchnumber ($tech_version) successfully applied to $ENV_NAME ($(hostname))!" >> $patchlog/$patchdir/PatchInfo$count_info.log
fi
last_update_date=$(date "+%d-%b-%Y %T")
last_update_time=$(date "+%b %d %Y %T")
echo "      Date and time: $last_update_date" >> $patchlog/$patchdir/PatchInfo$count_info.log
tot_start_time="$opatch_start_time"
tot_end_time=""
TimeCalc "$opatch_start_time" "$download_end_time"
echo "      $time_calc .... Download and reading" >> $patchlog/$patchdir/PatchInfo$count_info.log
TimeCalc "$opatch_start_time" "$download_end_time" sub cout
download_time="$time_calc"
ptch_stime=$download_end_time
tot_end_time=$last_update_time
TimeCalc "$ptch_stime" "$tot_end_time"
echo "      $time_calc .... Total patch time" >> $patchlog/$patchdir/PatchInfo$count_info.log
tot_patch_time=$time_calc
TimeCalc "$ptch_stime" "$tot_end_time" sub cout
patch_time=$time_calc
TimeCalc "$download_time" "$patch_time" add
echo "      $time_calc .... Total application time" >> $patchlog/$patchdir/PatchInfo$count_info.log
echo "   -------------------------------------------------------------------------"  >> $patchlog/$patchdir/PatchInfo$count_info.log
echo "      SR/RFC  : $tarnumber" >> $patchlog/$patchdir/PatchInfo$count_info.log
echo >> $patchlog/$patchdir/PatchInfo$count_info.log
echo "      Initials: $initials" >> $patchlog/$patchdir/PatchInfo$count_info.log
echo "   -------------------------------------------------------------------------"  >> $patchlog/$patchdir/PatchInfo$count_info.log


if [[ ! -z $tarnumber ]];then
	# Create generic tar directory
	mkdir -p $patchlog/TAR > /dev/null 2>&1

	# Create tar file
	tarfile=$patchlog/TAR/$tarnumber
	if [[ ! -f $tarfile ]];then
		echo "   Patch timing information for SR/RFC $tarnumber" > $tarfile
	fi
	insert_next=no
	rm -rf $logdir/$tarnumber >/dev/null 2>&1
	if [[ $(grep -w $patchdir $tarfile|wc -l) -gt 0 ]];then
		# Do new file
		cat $tarfile|while read tarline;do
			if [[ $(echo $tarline|grep Patch|wc -l) -gt 0 ]];then
				echo "   $tarline" >> $logdir/$tarnumber
			else
				echo "      $tarline" >> $logdir/$tarnumber
			fi 
			if [[ $(echo $tarline|grep -w $patchdir|wc -l) -gt 0 ]];then
				insert_next=yes
			fi
			if [[ $(echo $tarline|grep -w "Date and time"|wc -l) -gt 0 ]];then
				if [[ $insert_next = yes ]];then
					echo "      $last_update_date	$tot_patch_time" >> $logdir/$tarnumber
					insert_next=no
				fi
			fi
		done
		mv $logdir/$tarnumber $tarfile >/dev/null 2>&1
	else
		echo >> $tarfile
		echo "   Patch: $patchdir" >> $tarfile
		echo "      Date and time:		Total patch time:" >> $tarfile
		echo "      $last_update_date	$tot_patch_time" >> $tarfile
	fi
fi
}



function xxecho
{
txt=$1
line_status=1
if [[ ! -f $LogFile ]];then
	xxechodate=$(echo $(date +%T%j%y|sed 's.:..g'))
	call_prog=$(basename $0)
	LogFile=$call_prog.$xxechodate
fi
event_logfile=$LogFile
if [[ $2 = [nN] ]];then
	$echo "$txt"|tee -a $event_logfile > /dev/null
elif [[ $LogStatement = notty ]];then
	$echo "$txt"|tee -a $event_logfile
else
	$echo "$txt"|tee -a $event_logfile > /dev/tty
fi

}


function check_running_opatch
{
# Check if another adpatch session is running and abort if true
count_running=$(ps -u $WHOAMI -o comm|grep $opatch_type|grep -v "opatch.sh"|grep -v grep|wc -l)
if (($count_running));then
	line_statement
	xxecho "   *********************************************************************"
	xxecho "      A running $opatch_type session has been discovered."
	xxecho "      Please ensure to complete the running $opatch_type session before"
	xxecho "      starting a new one !"
	xxecho "   *********************************************************************"
	exit_program "OpatchRunningError"
fi
}

function check_running_db
{
count_running=$(ps -fu $WHOAMI|grep pmon|grep -v grep|wc -l)
if (($count_running));then
	line_statement
	xxecho "   *********************************************************************"
	xxecho "      A running pmon session has been discovered."
	xxecho "      Please ensure to shutdown database before applying patch!"
	xxecho "   *********************************************************************"
	exit_program "DatabaseRunningError"
fi
}

function check_restart_mode_pre
{
restart_file=$TARGET_ORACLE_HOME/.patch_storage/patch_locked
newpatch=yes
if [[ $(grep $patchnumber $restart_file 2>/dev/null|wc -l) -gt 0 ]];then
	newpatch=no
fi
}		

function check_restart_mode
{
restart_file=$TARGET_ORACLE_HOME/.patch_storage/patch_locked
if [[ -f $restart_file ]]; then
  lock_patch=$(grep "Locked for patch" $restart_file|awk -F":" '{print $2}'|awk '{print $1}')
  lock_class=$(grep "Locked by class" $restart_file|awk -F":" '{print $2}'|awk '{print $1}')
fi
newpatch=yes
if [[ $drop_previous = yes ]];then
	if [[ -f $restart_file ]]; then
		line_statement
		xxecho "   *********************************************************************"
		xxecho "     You have specified to drop the previous opatch session:"
    xxecho "     -> Failed patch : $lock_patch"  
    xxecho "     -> Failed action: $lock_class"  
		xxecho "   *********************************************************************"
		xxecho
		yes_no "   Are you sure you wish to drop the previous patch session ? [N]: " N
		if [[ $(grep $patchnumber $restart_file 2>/dev/null|wc -l) -gt 0 ]];then
			newpatch=no
		fi
		rm -f $restart_file > /dev/null 2>&1
	fi
fi
# Check if a previous patch failed (from restart files in restart dir)
if [[ -f $restart_file ]]; then
	line_statement
	# Check if failed patch is the same as patch being applied or not.
	# Then ask if patch should be reapplied.
	if [[ $(grep $patchnumber $restart_file 2>/dev/null|wc -l) -gt 0 ]];then
  	xxecho "   A previous opatch session failed for patch $patchnumber ($tech_version)."
  	yes_no "   Do you wish to continue applying patch $patchnumber ? [Y]: " Y
		newpatch=no
		interactivemode=yes
		restart_mode=yes
	else
		line_statement
	  xxecho "   A previous opatch session failed."
	  xxecho
		xxecho "   *********************************************************************"
		xxecho "     The patch you are about to apply is NOT the same patch as has"
		xxecho "     previously failed:					  "
    xxecho "     -> Failed patch : $lock_patch"  
    xxecho "     -> Failed action: $lock_class"  
		xxecho "   *********************************************************************"
		xxecho
		yes_no "   Do you wish to drop the previous patch session? [N]: " "N" "yes"
		if (($?));then
		  xxecho
		  xxecho "   Previous patch session can be dropped by removing lock file:"
		  xxecho "   -> \$TARGET_ORACLE_HOME/.patch_storage/patch_locked"
		  xxecho
		  xxecho "   [\$TARGET_ORACLE_HOME=$TARGET_ORACLE_HOME]"
			end_program RestartError
		fi
		rm -f $restart_file > /dev/null 2>&1
		line_statement
	fi
fi

}



# Get database version
function get_db_version
{
if [[ $db_connect != no ]];then	
	run_sql "system/$systempwd" "db_version.lst"  "set linesize 80
		select 'DB_VERSION '||version from v\$instance;
		select 'CLUSTER_DB '||lower(value) from v\$parameter 
		where name='cluster_database';"
	rac_enabled=$(grep CLUSTER_DB $logdir/db_version.lst|awk '{print $2}')
else
	db_version_name=$(grep "oracle.patchset.db" $TARGET_ORACLE_HOME/inventory/ContentsXML/comps.xml|grep "<PATCHSET"|awk '{print $3}'|sort -n|awk -F"=" '{print $2}'|sed 's%\"%%g'|tail -1)
	if [[ -z $db_version_name ]];then
		db_version_name=$(grep "oracle.rdbms" $TARGET_ORACLE_HOME/inventory/ContentsXML/comps.xml|grep "<PATCH"|awk '{print $3}'|sort -n|awk -F"=" '{print $2}'|sed 's%\"%%g'|tail -1)
		if [[ -z $db_version_name ]];then
			db_version_name=$(grep "oracle.rdbms" $TARGET_ORACLE_HOME/inventory/ContentsXML/comps.xml|grep "<COMP"|awk '{print $3}'|sort -n|awk -F"=" '{print $2}'|sed 's%\"%%g'|tail -1)
		fi
	fi
fi
tech_type=db
db_version_name=$(cat $logdir/db_version.lst|grep DB_VERSION|awk '{print $2}')
db_main_version=$(echo $db_version_name|awk -F"." '{print $1}')
db_version_number=$(echo $db_version_name|awk -F"." '{print $1$2$3$4}')
if [[ $forced_tech_version = no ]];then
  tech_version=$db_version_number
  tech_main_version=$(echo $db_version_name|awk -F"." '{print $1$2$3}')
else
  if [[ $db_main_version -lt 10 ]];then 
    tech_main_version=$(echo $tech_version|cut -c1-3)
  else
    tech_main_version=$(echo $tech_version|cut -c1-4)
  fi
fi
tech_long_version=$(echo $db_version_name|sed 's%\.%%g')
tech_base_version=$db_version_number
export db_version_number
}

function get_oracle_version
{
O_HOME=${1:-$TARGET_ORACLE_HOME}
db_version_name=""
db_main_version=""
db_sub_version=""
db_version_number=""
if [[ -f $O_HOME/bin/dis51ws ]];then
	disco_tier=1
fi
if [[ $tech_type = wls ]];then
  if [[ -f $BSU_LOC/bsu.sh ]];then
	  bsu_memory_change $BSU_LOC/bsu.sh
	fi
  if [[ -f $WLS_OHOME/server/bin/setWLSEnv.sh ]];then
	  cd $WLS_OHOME >/dev/null 2>&1
    . $WLS_OHOME/server/bin/setWLSEnv.sh >/dev/null 2>&1
    db_version_name=$(java weblogic.version 2>/dev/null|grep "WebLogic Server"|awk '{print $3}'|egrep '^12|^11|^10|^9'|head -1)
		wls_status=$?
		java weblogic.version 2>/dev/null|grep "Patch for" > $logdir/weblogic_patches.lst
 		cd - >/dev/null 2>&1
 elif [[ -f $BSU_LOC/bsu.sh ]];then
	  cd $BSU_LOC >/dev/null 2>&1
		./bsu.sh -report 2>/dev/null|egrep 'WebLogic Server|Product Version|WLS PATCH SET'|grep -v "Description" > $logdir/wls_version.lst 2>&1
		cd - >/dev/null 2>&1
		wls_status=$?
		db_version_name=$(grep "WLS PATCH SET" $logdir/wls_version.lst|awk '{print $5}')
		if [[ -z $db_version_name ]];then 
		  db_version_name=$(awk "/WebLogic Server/","/Product Version/" $logdir/wls_version.lst|grep "Product Version"|awk '{print $3}')".0"
		fi
	else
		wls_status=1
	fi
	if ((!$wls_status));then
		db_main_version=$(echo $db_version_name|awk -F"." '{print $1}')
		db_sub_version=$(echo $db_version_name|awk -F"." '{print $2}')
		db_check_version=$(echo $db_version_name|awk -F"." '{print $1$2$3}')
		db_version_number=$(echo $db_version_name|awk -F"." '{print $1$2$3$4$5}')
		if [[ ${db_check_version} -ge 1212 ]];then 
  		db_version_number=$(echo $db_version_name|awk -F"." '{print $1$2$3$4}')
		  opatch_type=opatch 
		else 
		  opatch_type=bsu 
		fi
	fi
elif [[ -f $O_HOME/inventory/ContentsXML/comps.xml ]];then
  ohswls=0
  ohsfmw=0
  ohsweb=0
  ohsoth=0
  component_name=$(grep "COMP" $O_HOME/inventory/ContentsXML/comps.xml|awk -F"=" '{print $2}'|awk '{print $1}'|head -1|sed 's%\"%%g')
  case $component_name in
    oracle.developer.server)  ohsfrm=1;;
    oracle.as.common.top)     ohscommon=1;;
    oracle.as.webtiercd.top)  ohsfmw=1;;
    oracle.as.j2ee.top|oracle.iappserver) ohsoas=1;;
    WebLogic)  ohswls=1;;
    oracle.server)  dbtier=1;;
    *)  ohsoth=1;;
  esac
  
#  if [[ $tech_type = oas ]];then 
#    ohsoas=$(grep "oracle.iappserver"  $O_HOME/inventory/ContentsXML/comps.xml|grep -v "security"|egrep "<PATCHSET|<PATCH|<COMP"|wc -l)
#    if ((!$ohsoas));then 
#      ohsfmw=$(grep "oracle.as.webtiercd.top"  $O_HOME/inventory/ContentsXML/comps.xml|egrep "<PATCHSET|<PATCH|<COMP"|wc -l)
#    fi
#  elif [[ $tech_type = common ]];then 
#	  ohscommon=$(grep "oracle.as.common.top"  $O_HOME/inventory/ContentsXML/comps.xml|egrep "<PATCHSET|<PATCH|<COMP"|wc -l)
#  elif [[ $tech_type = fmw ]];then 
#	  ohsfmw=$(grep "oracle.as.webtiercd.top"  $O_HOME/inventory/ContentsXML/comps.xml|egrep "<PATCHSET|<PATCH|<COMP"|wc -l)
#	else
#    ohsoas=$(grep "oracle.iappserver"  $O_HOME/inventory/ContentsXML/comps.xml|grep -v "security"|egrep "<PATCHSET|<PATCH|<COMP"|wc -l)
#    if ((!$ohsoas));then 
#      ohswls=$(grep "oracle.apps.ebs"  $O_HOME/inventory/ContentsXML/comps.xml|egrep "<PATCHSET|<PATCH|<COMP"|wc -l)
#      if ((!$ohswls));then 
# 	      ohsfmw=$(grep "oracle.as.webtiercd.top"  $O_HOME/inventory/ContentsXML/comps.xml|egrep "<PATCHSET|<PATCH|<COMP"|wc -l)
#  	    if ((!$ohsfmw));then 
#          ohscommon=$(grep "oracle.as.common.top"  $O_HOME/inventory/ContentsXML/comps.xml|egrep "<PATCHSET|<PATCH|<COMP"|wc -l)
#  	    fi
#      fi
#    fi
#	fi
	db_version_name=$(grep "${component_name}" $O_HOME/inventory/ContentsXML/comps.xml|grep "<PATCHSET"|awk '{print $3}'|sort -n|awk -F"=" '{print $2}'|sed 's%\"%%g'|tail -1)
	if [[ -z $db_version_name ]];then
		db_version_name=$(grep "${component_name}" $O_HOME/inventory/ContentsXML/comps.xml|grep "<PATCH"|awk '{print $3}'|sort -n|awk -F"=" '{print $2}'|sed 's%\"%%g'|tail -1)
		if [[ -z $db_version_name ]];then
			db_version_name=$(grep "${component_name}" $O_HOME/inventory/ContentsXML/comps.xml|grep "<COMP"|awk '{print $3}'|sort -n|awk -F"=" '{print $2}'|sed 's%\"%%g'|tail -1)
		fi
	fi
	db_main_version=$(echo $db_version_name|awk -F"." '{print $1}')
	db_sub_version=$(echo $db_version_name|awk -F"." '{print $2}')
	db_version_number=$(echo $db_version_name|awk -F"." '{print $1$2$3$4}')
fi
tech_long_version=$(echo $db_version_name|sed 's%\.%%g')
if [[ $forced_tech_version = no ]];then
  tech_version=$db_version_number
  tech_main_version=$(echo $db_version_name|awk -F"." '{print $1$2$3}')
else
  tech_base_version=$db_version_number
  if [[ $db_main_version -lt 10 ]];then 
    tech_main_version=$(echo $tech_version|cut -c1-3)
  else
    tech_main_version=$(echo $tech_version|cut -c1-4)
  fi
fi
if [[ -z $db_version_name ]];then 
  db_version_name=UNKNOWN
  return 1
fi
export db_version_number
}

# Parameter 1 is password to encrypt/decrypt
function encrypt_pwd
{
crypt_pwd=$1	
crypt_account=$2
if [[ ! -z $crypt_pwd ]];then
  if [[ -f $(which openssl 2>/dev/null) ]];then
    crypt_pwd=$(echo $crypt_pwd|openssl enc -rc4 -a -salt -pass env:ENV_NAME 2>/dev/null)
    crypt_status=$?
    if [[ ! -z $crypt_account ]];then
      echo "$crypt_account $crypt_pwd" >> $ep_file
    fi
  elif  [[ -f $(which crypt 2>/dev/null) ]];then
    if [[ ! -z $crypt_account ]];then
      echo "$crypt_account $(echo $crypt_pwd|crypt $ENV_NAME)" >> $ep_file
      crypt_status=$?
    else
      crypt_pwd=$(echo $crypt_pwd|crypt $ENV_NAME)
      crypt_status=$?
    fi
  fi
fi
return $crypt_status
}

function decrypt_pwd
{
crypt_pwd=$1
crypt_account=$2
crypt_key=${3:-$ENV_NAME}
export crypt_key
	
if [[ ! -z $crypt_pwd || ! -z $crypt_account ]];then
  if [[ -f $(which openssl 2>/dev/null) ]];then
    if [[ ! -z $crypt_account ]];then
      crypt_pwd=$(grep $crypt_account $ep_file 2>/dev/null|awk '{print $2}')
    fi
    crypt_pwd=$(echo $crypt_pwd|openssl enc -rc4 -a -d -salt -pass env:crypt_key 2>/dev/null)
    crypt_status=$?
  elif  [[ -f $(which crypt 2>/dev/null) ]];then
    if [[ ! -z $crypt_account ]];then
      crypt_pwd=$(cat $ep_file 2>/dev/null|grep $crypt_account|awk '{print $2}'|crypt $crypt_key|awk '{print $1}'|head -1)
      crypt_status=$?
    else
      crypt_pwd=$(echo $crypt_pwd|crypt $crypt_key|awk '{print $1}'|head -1)
      crypt_status=$?
    fi
  else
    crypt_status=1
  fi
  if (($crypt_status));then 
    crypt_pwd="unknown"
  elif [[ $platform_name = solaris ]]&&[[ $(echo "$crypt_pwd"|sed 's%[ -~]%%g'|wc -c) -gt 1 ]];then
    crypt_pwd="unknown"
  elif [[ $(echo "$crypt_pwd"|tr -d '[:print:]\t\r\n'|wc -c) -gt 0 ]];then 
    crypt_pwd="unknown"
  fi
fi
echo $crypt_pwd
}

function get_customer_type
{
get_whoami
set_platform

if [[ $platform_name = linux ]];then
  osdomain=$(hostname -d 2>/dev/null)
else
  osdomain=$(domainname -d 2>/dev/null)
fi
if [[ -z $osdomain ]];then
  osdomain=$(cat /etc/resolv.conf 2>/dev/null|grep search|sed 's%search %%g')
fi
if [[ $(echo $osdomain|egrep 'oracleoutsourcing.com|oracle.com|oraclesrdc.com|oraclevcn.com'|wc -l)  -gt 0 ]];then
  if [[ $unixuid = oracle ]];then
    customer_type=opc 
  else
    customer_type=ondemand 
  fi
elif [[ $(echo $osdomain|egrep 'oraclecloud.internal'|wc -l) -gt 0 ]];then
  customer_type=opc 
fi
if [[ -z $customer_type ]];then
	host_location=$(echo $HOST_NAME|cut -c1-2)
	host_type=$(echo $HOST_NAME|cut -c3-5)
	if [[ $(echo $host_location|egrep 'au|rm|vh|vm|ll|sl|sr'|wc -l) -eq 0 ]]||[[ $(echo $host_type|egrep 'ohs|pod|poh|sod|som|rod'|wc -l) -eq 0 ]];then
		customer_type=customer
	else
		customer_type=ondemand	
	fi
fi
}

# PROGRAM

#115.77 pkr

get_tier

# Setup default parameters
set_defaults 

if [[ $(echo $command_line|grep notty|wc -l) -gt 0 ]];then
	LogStatement=notty
else
	clear
fi
if [[ $(echo $command_line|grep "\-encryptpwd"|wc -l) -gt 0 ]];then
	encrypt_password=yes
fi
xxecho
xxecho " ============================================================================="
xxecho "   OPATCH SCRIPT - For applying/checking 'opatch' or 'bsu' tech stack patches"
xxecho " ============================================================================="
xxecho
if [[ $(echo $command_line|egrep "\-apass|\-mpass|\-spass"|wc -l) -gt 0 ]];then
	command=""
	next_param=""
	#Remove passwords from line
	for param in $(echo $command_line);do
		if [[ $next_param = "****" ]];then
			command="$command ****"
			next_param=""
		else
			if [[ $(echo $param|egrep "\-apass|\-mpass|\-spass"|wc -l) -gt 0 ]];then
				next_param="****"
			fi
			command="$command $param"
		fi
	done
	command_line=$command
fi
xxecho "   Command used: $opatch_script_name $command_line" N
xxecho "" N
# Trap cntrl-c
trap abort_program INT
# Remove extra long options
opatch_options_line=""
if [[ $(echo $options_line|egrep "\-sshkey |\-oh "|wc -l) -gt 0 ]];then
	next_param=""
	#Remove passwords from line
	for param in $(echo $options_line);do
		if [[ $next_param = "ssh" ]];then
		  sshkey=$param
      if [[ ! -f $sshkey ]];then
        xxecho "   Invalid key location specified!"
        xxecho "   -> $sshkey"
        exit_program ProtocolConnectionError
      fi
      protocol=FTP
      credential=ARU
			next_param=""
		elif [[ $next_param = "oh" ]];then
	    target_oracle_home=$param
      if [[ ! -d $target_oracle_home ]];then 
        xxecho "   Invalid ORACLE_HOME provided."
        xxecho "   ORACLE_HOME: $target_oracle_home"
        xxecho "   Does not exist."
        exit_program EnvironmentError
      else 
        TARGET_ORACLE_HOME=$target_oracle_home
        export TARGET_ORACLE_HOME
      fi		 
			next_param=""
		else
			if [[ $(echo $param|grep -cw "sshkey") -gt 0 ]];then
				next_param="ssh"
			elif [[ $(echo $param|grep -cw "oh") -gt 0 ]];then
				next_param="oh"
			else
			  opatch_options_line="$opatch_options_line $param"
			fi
		fi
	done
else
  opatch_options_line=$options_line
fi

Options="a%,c%,d%,r%,p%,v%,rollback%,conflict%,merge:-,info%,tarinfo%,b:+,force:-,s:,h,drop:-,options:+,test:-,tar:+,noconnect:-,interactive:-,backup:+,mname:+,mpass:+,clean,spass:+,apass:+,wpass:+,notty:,zipname:+,tech:+,version:+,skipinventory:,platform:+,protocol:+,sshkey:+,proxy:+,encryptpwd:-,type:+,edition:+,oh:+"
while GetOptions $Options opt U wrong_syntax $opatch_options_line;do
	case $opt in
	a)	patchnumber=$NextArg
		  patch_option=apply;;
	c)	patchnumber=$NextArg
		patch_option=check;;
	d)	patchnumber=$NextArg
		patch_option=download;;
	r)	patchnumber=$NextArg
		patch_option=readonly;;
	v)	patch_option=verify
			patchnumber=$NextArg;;
	p)	patch_option=patchdownload
    	forced_platform_version=yes
			db_connect=no
			skip_inventory=yes
			patchlist=$NextArg;;
	rollback)	patch_option=rollback
			patchnumber=$NextArg;;
	merge)	merge_option=merge;;
	options)	apply_options=$NextArg;;
	test)	apply_mode=n;;
	tar)	tarnumber=$(echo $NextArg|sed -e "s/\(^[0-9]\+\.[0-9][1-9]*\)0*$/\1/");;
	info)	patchnumber=$NextArg
		patch_option=info;;
	tarinfo)	tarnumber=$(echo $NextArg|sed -e "s/\(^[0-9]\+\.[0-9][1-9]*\)0*$/\1/")
		patch_option=tarinfo;;
	s)	run_mode=silent;;
	force)	run_option=force
	        force_option="-force";;
	drop)	drop_previous=yes;;
	noconnect)	db_connect=no;;
	interactive)	interactivemode=yes
					restart_mode=yes;;
	b)	batchfile=$NextArg
		batch_mode=batch
		echo "   BATCH MODE HAS NOT BEEN IMPLEMENTED YET"
		end_program ParameterError
		if [[ ! -f $batchfile ]];then
			xxecho "   Invalid batch file specified!"
			xxecho
			xxecho "   Please ensure batch file has full path and is read/writeable !"
			exit_program InvalidBatchFileError
		fi;;
	backup)	patch_backup_dir=$NextArg
			if [[ ! -w $patch_backup_dir ]];then
				xxecho "   Not able to write to patch backup directory:"
				xxecho "   - $patch_backup_dir"
				xxecho
				xxecho "   Please ensure read/write rights are correct and that directory exists !"
				exit_program PermissionError
			fi;;
	mname)	mlink_uname=$NextArg
			MlinkSet=0;;
	mpass)	if [[ $encrypt_password = yes ]];then
					mlink_pwd=$(decrypt_pwd $NextArg)
				else
					mlink_pwd=$NextArg
				fi
			MlinkSet=0;;
	encryptpwd)	;;
	clean)	CleanPatch=1;;
	spass)	if [[ $encrypt_password = yes ]];then
					spwd=$(decrypt_pwd $NextArg)
				else
					spwd=$NextArg
				fi
				;;
	apass)	if [[ $encrypt_password = yes ]];then
					apwd=$(decrypt_pwd $NextArg)
				else
					apwd=$NextArg
				fi
				;;
	wpass)	if [[ $encrypt_password = yes ]];then
					wpwd=$(decrypt_pwd $NextArg)
				else
					wpwd=$NextArg
				fi
				;;
	notty)	LogStatement=notty;;
	version|tech)	forced_tech_version=yes
								tech_version=$NextArg
								skip_inventory=yes;;
	type) 	tech_type=$NextArg
	        case $tech_type in 
	          fmw|fmw_*|oas|ias|db|forms|wls) ;;
	          *)  xxecho "   Invalid patch type selected [$tech_type]."
							xxecho "   Valid patch types are:"
							xxecho "   wls|fmw_web|fmw_ohs|fmw_common|fmw_*|oas|ias|forms|db."
							exit_program InvalidPatchError;;
						esac;;						
	skipinventory)	skip_inventory=yes;;
	h)	USAGE;;
#115.77 pkr
	zipname)		patchzipname=$NextArg;;
	platform)		forced_platform_version=yes
							patch_ext=$NextArg
							db_connect=no
							skip_inventory=yes;;
	protocol)	protocol=$(echo $NextArg|tr '[a-z]' '[A-Z]')
						case $protocol in 
							FTP|ARU)	credential=ARU;;
							HTTP)	credential=MOS;;
							*)	xxecho "   Invalid protocol option specified!"
							xxecho
							xxecho "   Valid protocol options are:"
							xxecho "   ftp or http."
							exit_program InvalidPatchError;;
						esac;;
	proxy)	WgetProxy=$NextArg;;
	sshkey)	sshkey=$NextArg
          if [[ ! -f $sshkey ]];then
            xxecho "   Invalid key location specified!"
            xxecho "   -> $sshkey"
            exit_program ProtocolConnectionError
          fi
          protocol=FTP
          credential=ARU;;  	
	edition)  target_edition=$(echo $NextArg|tr '[a-z]' '[A-Z]')
	          case $target_edition in
	            RUN|PATCH)  ;;
	            *)  xxecho "   Invalid edition selected."
							xxecho "   Valid editions are:"
							xxecho "   run|patch."
							exit_program PatchEditionError;;
						esac;;
	oh) 			target_oracle_home=$NextArg
	          if [[ ! -d $target_oracle_home ]];then 
	            xxecho "   Invalid ORACLE_HOME provided."
	            xxecho "   ORACLE_HOME: $target_oracle_home"
	            xxecho "   Does not exist."
	            exit_program EnvironmentError
	          else 
	            TARGET_ORACLE_HOME=$target_oracle_home
	            export TARGET_ORACLE_HOME
	          fi;;		 
	esac
done


if [[ -z $tech_type ]];then 
  if (($dbtier));then 
    tech_type=db
  elif (($formstier));then 
    tech_type=forms
  elif (($iastier));then 
    tech_type=ias
  elif (($fmwwebtier));then 
    tech_type=fmw_web
  elif (($fmwohstier));then 
    tech_type=fmw_ohs
  elif (($fmwcmntier));then 
    tech_type=fmw_common
  elif (($wlstier));then 
    tech_type=wls
  else 
    tech_type=oracle
  fi
fi

get_xml_file
set_environment_path
tech_type_uc=$(echo $tech_type|tr '[a-z]' '[A-Z]')

if [[ $edition_based = no ]];then
 	db_connect=no
fi

# Checks ORACLE_HOME, ORACLE_SID, OPATCH_TOP, onlinedef.txt and more
if [[ $tech_type = db ]];then
	if [[ -z "$TARGET_ORACLE_HOME" || -z "$ORACLE_SID" ]];then
		xxecho "   ORACLE environment has not been setup."
		xxecho "   Make sure that ORACLE environment file has been run."
		exit_program EnvironmentError
	fi
else 
  if (($iastier));then
  	if [[ -z "$TARGET_ORACLE_HOME" || -z "$TWO_TASK" ]]&&[[ -z $target_oracle_home ]];then
  		xxecho "   ORACLE_HOME environment has not been setup."
  		xxecho "   Make sure that environment file has been run."
  		exit_program EnvironmentError
  	fi
  fi
fi	

if [[ -z $mlink_uname || -z $mlink_pwd ]];then
	if ((!$MlinkSet));then
		xxecho "   You need to specify both -mname and -mpass if providing metalink"
		xxecho "   account information ..."
		xxecho "   - $opatch_script_name ... -mname <metalink username> -mpass <metalink password>"
		exit_program ParameterError
	fi
fi 
if [[ -z $mlink_uname && -z $mlink_pwd ]];then
  crypt_name=$(eval echo '$'${crypt_type}_crypt_name)
  crypt_pass=$(eval echo '$'${crypt_type}_crypt_pass)
  mlink_uname=$(decrypt_pwd "$crypt_name" "" "omcs_hash")
  mlink_pwd=$(decrypt_pwd "$crypt_pass" "" "omcs_hash")
fi
if [[ ! -z $mlink_uname && ! -z $mlink_pwd ]];then
	MlinkSet=0
fi

create_temp_log
check_environment


if [[ $(echo $patchnumber|grep ":"|wc -l) -gt 0 ]];then
  pnumlist="" 
  for bsu_patch in $(echo $patchnumber|sed 's%,% %g');do
    pnum=$(echo $bsu_patch|awk -F":" '{print $1}')
    if [[ -z $pnumlist ]];then 
      pnumlist=$pnum
    else 
      pnumlist="$pnumlist,$pnum"
    fi
    echo "$bsu_patch" >> $logdir/bsupatch.lst
  done
  patchnumber=$pnumlist
fi
if [[ $patch_option = patchdownload ]];then
  for patchzip in $(echo $patchlist|sed 's%,% %g');do
    pnum=$(echo $patchzip|awk -F"_" '{print $1}'|sed 's%^p%%g')
    pver=$(echo $patchzip|awk -F"_" '{print $2}')
    ptech=$(echo $patchzip|awk -F"_" '{print $NF}'|sed 's%.zip%%g')
    if [[ -z $pnumlist ]];then 
      pnumlist=$pnum
    else 
      pnumlist="$pnumlist,$pnum"
    fi
    echo "$patchzip" >> $logdir/patchzip.lst
    echo "$pnum!$pver!$ptech" >> $logdir/patch.lst
  done
  patchnumber=$pnumlist
fi
if [[ $batch_mode = single ]];then
	if [[ $patch_option = tarinfo ]];then
		get_tar_number
	else
		get_patch_number
	fi
fi

# Different text, whether using read only mode or not
line_statement
case $patch_option in
readonly)	if [[ ! -z $target_oracle_home ]];then
            skip_inventory=no
          fi
    			if [[ $merge_option = merge ]];then
    				xxecho "   Merging patches $patchnumber"
    			else
    				xxecho "   Displaying readme files for patch $patchnumber ($tech_version)"
    			fi;;
download|patchdownload)	xxecho "   Downloading patch $patchnumber";;
apply)		xxecho "   Applying patch $patchnumber"
          skip_inventory=no;;
rollback)	xxecho "   Rollback of patch $patchnumber"
          skip_inventory=no;;
verify)	xxecho "   Checking conflicts for patch $patchnumber"
          skip_inventory=no;;
check)		xxecho "   Checking if patch $patchnumber has previously been applied"
          skip_inventory=no;;
info)			xxecho "   Checking patch information for patch $patchnumber";;
tarinfo)	xxecho "   Checking timing information for patches applied against SR/RFC $tarnumber";;
esac
if [[ $skip_inventory = no ]];then
  xxecho
  xxecho "   Getting $tech_type_uc version..."
  running_statement "Getting $tech_type_uc version"
  if [[ $tech_type = db ]] && [[ $db_connect = yes ]];then
  	get_db_version
  else
  	get_oracle_version
  	version_status=$?
  fi
  format_statement "Getting $tech_type_uc version" "$db_version_name"
fi
xxecho
if [[ $tech_type = wls ]]&&[[ $tech_main_version -lt 1212 ]];then 
  skip_inventory=yes 
  if [[ $patch_option = rollback || $patch_option = check ]];then 
    skip_download=yes
  elif [[ $patch_option = verify ]];then
    xxecho "   Checking for conflicts in WebLogic versions less than 12.1.2"
    xxecho "   is not supported!"
    exit_program ParameterError
  fi
  if (($version_status));then
    xxecho "   Unable to determine WLS version"
    exit_program EnvironmentError
  fi
fi
if [[ $skip_inventory = no ]]&&[[ ! -f $opatch_exe || ! -f $inv_file ]];then
	check_inventory $TARGET_ORACLE_HOME $tech_type_uc
	if (($?));then
	  xxecho "   Invalid inventory!"
	  exit_program EnvironmentError
	fi
	xxecho
fi

if [[ $forced_platform_version = no ]];then 
	get_patch_extension
fi	
if [[ $(uname) = Linux ]];then 
  case $(uname -i) in
		x86-64|x86_64|ia64)	if [[ $(file $TARGET_ORACLE_HOME/bin/tnsping 2>/dev/null|grep "32-bit"|wc -l) -gt 0 ]];then
            					    set_linux32=1
					                OPATCH_PLATFORM_ID=46
					                export OPATCH_PLATFORM_ID
					              fi;;
  esac 
fi
case $patch_option in
rollback|readonly|patchdownload|download|tarinfo|apply|check|verify)	;;
*)	xxecho "   Invalid combination of parameters !"
	xxecho "   Option '-noconnect' can only be used together with following options:"
	xxecho "   -d:       Download"
	xxecho "   -r:       Readme"
	xxecho "   -tarinfo: Tar information"
	exit_program ParameterError;;
esac
if [[ $patch_option != patchdownload ]];then
  for pname in $(echo $patchnumber|sed 's%,% %g');do
  	echo "$pname!$tech_version!" >> $logdir/patch.lst
  done
fi
first_shot=yes
sort -u $logdir/patch.lst|awk -F"!" '{print $1}'|while read pname;do
if [[ $first_shot = yes ]];then
		patch_list=$pname
		first_shot=no
	else
		patch_list="$patch_list,$pname"
	fi
	echo $patch_list > $logdir/patch_list
done
patch_list=$(cat $logdir/patch_list)
rm -rf $logdir/invalid_tier.lst 2>/dev/null
case $patch_option in
apply|rollback|verify)	opatch_start_time=$(date "+%b %d %Y %T")
		xxecho "   Checking for previous application of patch ${patchnumber}..."
		for ptchnumber in $(cat $logdir/patch.lst  2>/dev/null);do
			patchnumber=$(echo $ptchnumber|awk -F"!" '{print $1}')
			patchdir=${patchnumber}_${tech_version}
			check_patch_applied $patchnumber 
			if [[ $patch_option = apply || $patch_option = verify ]];then
  			case $patch_applied in
  			yes)	if [[ $run_option != force ]];then
  						update_lang_list $logdir/patch.lst
  					fi;;
  			U)		format_statement "Checking patch ${patchnumber}" "unknown";;
  			esac
  		else
  			case $patch_applied in
  			no)   if [[ $skip_download = yes ]];then 
  			        update_lang_list $logdir/patch.lst
  			      fi;;
  			yes)	if [[ $(cat $logdir/patch_applied.tmp|awk -F"!" '{print $1}'|grep $patchnumber|wc -l) -eq 0 ]];then
    						update_lang_list $logdir/patch.lst
    					fi;;
  			U)		format_statement "Checking patch ${patchnumber}" "unknown";;
  			esac
  		fi
		done
		xxecho;;
check)	applied_check=no
			for ptchnumber in $(cat $logdir/patch.lst  2>/dev/null);do
				patchnumber=$(echo $ptchnumber|awk -F"!" '{print $1}')
  			patchdir=${patchnumber}_${tech_version}
				xxecho "   Checking for previous application of patch ${patchnumber}..."
				check_patch_applied $patchnumber
				xxecho
				case $patch_applied in
				no)   if [[ $skip_download = yes ]];then 
				        xxecho "   Not applied to $ENV_NAME ($HOST_NAME)."
				        update_lang_list $logdir/patch.lst 
				      fi;; 
				yes)	if [[ -r $logdir/patch_applied.tmp ]];then
  							if [[ $(grep "Patch $patchnumber" $logdir/patch_applied.tmp|wc -l) -gt 0 ]];then
  								xxecho "   Applied to $ENV_NAME ($HOST_NAME)."
  							else
  								xxecho "   Applied to $ENV_NAME ($HOST_NAME) as part of patch(es):"
  								xxecho "   Patch:                                       Date:"
  								xxecho "   -------------------------------------------- ------------------------"
  								cat $logdir/patch_applied.tmp 2>/dev/null|sort -u|while read patch;do
  									applied_patch=$(echo $patch|awk -F"!" '{print $1}')" "
  									typeset -L44 line=$applied_patch"...................................................."
  									xxecho "   $line $(echo $patch|awk -F"!" '{print $2}')"
  								done
  							fi
  						else
  							xxecho "   Applied to $ENV_NAME ($HOST_NAME)."
  						fi
  						applied_check=yes
  						update_lang_list $logdir/patch.lst
  						if [[ $opatch_type = bsu ]];then
  						  bsu_ptype=$(grep $patchnumber $logdir/bsu_patch_list.adp 2>/dev/null|awk -F":" '{print $3}')
        				if [[ $bsu_ptype = PSU ]];then
  						    bsu_patch_id=$(grep $patchnumber $logdir/bsu_patch_list.adp 2>/dev/null|awk -F":" '{print $2}')
        				  overlay_found=$(grep -c "OVERLAY:$db_version_name" $logdir/bsu_patch_list.adp 2>/dev/null)
                  if (($overlay_found));then
              	    xxecho
              	    xxecho "   Following OVERLAY patches are applied on top of patch $patchnumber [$bsu_patch_id - $bsu_ptype]: "
              	    for bsu_overlay_info in $(grep "OVERLAY:$db_version_name" $logdir/bsu_patch_list.adp 2>/dev/null|sort -u);do
              	      overlay_found=1 
                      overlay_patch=$(echo $bsu_overlay_info|awk -F":" '{print $1}')
              	      overlay_id=$(echo $bsu_overlay_info|awk -F":" '{print $2}')
              	      overlay_version=$(echo $bsu_overlay_info|awk -F":" '{print $4}')
              	      xxecho "      -> OVERLAY: $overlay_patch [$overlay_id] - $overlay_version"
              	    done
                  fi
                fi
              fi;;
				U)	xxecho "   Unable to detect if patch has been applied.";;
				esac
				xxecho
			done
			if [[ $skip_download = yes ]];then
  			if [[ $applied_check = no ]];then
  				exit_program PatchNotApplied
  			else
  				end_program 
  			fi
  		fi;;
download)	
			if [[ $skip_inventory = no ]];then
				lang_list=$(cat $logdir/LANGLIST 2>/dev/null)
				xxecho "   Checking for previous application of patch ${patch_list}..."
				for ptchnumber in $(cat $logdir/patch.lst  2>/dev/null);do
					patchnumber=$(echo $ptchnumber|awk -F"!" '{print $1}')
			    patchdir=${patchnumber}_${tech_version}
					check_patch_applied $patchnumber
					case $patch_applied in
					yes)	if [[ $run_option != force ]];then
								update_lang_list $logdir/patch.lst
							fi;;
					U)		format_statement "Checking patch ${patchnumber}" "unknown";;
					esac
				done
				xxecho
			fi
			;;
info)	for ptchnumber in $(cat $logdir/patch.lst  2>/dev/null);do
			patchnumber=$(echo $ptchnumber|awk -F"!" '{print $1}')
			set_base_dir
			check_patch_info
		done
		end_program;;
tarinfo)	line_statement
			patchdir=TAR
			if [[ -f $patchlog/TAR/$tarnumber ]];then
				cat $patchlog/TAR/$tarnumber
				cat $patchlog/TAR/$tarnumber|while read line;do
					xxecho "   $line" N
				done
			else
				xxecho "   No available patch timing information for SR/RFC $tarnumber!"
			fi
			end_program;;
esac

download_list=""
if [[ $skip_download = no ]];then
  cp $logdir/patch.lst $logdir/missing_patch.lst 2>/dev/null
fi
cp $logdir/patch.lst $logdir/patch_not_applied.lst 2>/dev/null
patch_list=""
for patchnumber in $(cat $logdir/patch.lst 2>/dev/null|awk -F"!" '{print $1}'|sort -u);do
	if [[ $patch_list = "" ]];then
		patch_list="$patchnumber"
	else
		patch_list="$patch_list,$patchnumber"
	fi
done
if [[ $patch_list = "" ]];then
	xxecho "   No more patches in patch list"
	end_program
fi
if [[ $skip_download = no ]];then
  xxecho "   Checking patch availability for patch $patch_list..."
  for ptchnumber in $(cat $logdir/patch.lst 2>/dev/null);do
  	patchnumber=$(echo $ptchnumber|awk -F"!" '{print $1}')
  	tech_version=$(echo $ptchnumber|awk -F"!" '{print $2}')
  	tech_ext=$(echo $ptchnumber|awk -F"!" '{print $3}')
  	patch_ext=${tech_ext:-$patch_ext}
  	base_dir_set=0
  	set_base_dir
  	check_patch_dir
  	if (($?));then
  		check_ftp=1
  		download_list="$download_list $patchnumber!$tech_version!$patch_ext!"
  	fi
  done
  for patchnum in $(echo $download_list);do
  		echo "$patchnum" >> $logdir/patch_download.lst
  done
  if (($check_ftp));then
  	if [[ $run_mode = silent ]];then
  		if [[ -z $mlink_uname || -z $mlink_pwd ]];then
  			xxecho
  			xxecho "   In order to download patches in silent mode, please provide metalink"
  			xxecho "   account information on command line as follows:"
  			xxecho "   - $opatch_script_name ... -mname <metalink username> -mpass <metalink password>"
  			exit_program ParameterError
  		fi
  	fi
  		protocol_status=0
 		  get_expect_exe
  		if [[ $protocol = FTP ]];then
  			check_ftp_connection
  		else
  			check_wget_connection
  		fi
  		if ((!$protocol_status));then
  			check_protocol_patch
  		fi
  fi
  
  if [[ $patch_option = download || $patch_option = patchdownload ]];then 
  	xxecho
  	if (($protocol_status));then
  		xxecho "   Download failed !"
  		exit_program InvalidPatchError
  	else
  		xxecho "   Download completed"
  		get_zip_file
  		if ((!$?));then
  		  xxecho
  		  xxecho "   Patch zipfile available at:"
  		  xxecho "      -> \$$zip_loc/$patchzipname"
  		  xxecho
  		  xxecho "   [$zip_loc=$(eval echo '$'$zip_loc)]"
  		fi
  		end_program
  	fi
  fi
  if [[ $run_mode = silent ]]&&(($protocol_status));then
    case $protocol_status in
  	  1|2|3|8|10|16) 	xxecho
  	                  xxecho "   Download failed !"
                      exit_program ProtocolConnectionError;;
  	esac 
  fi
  for ptchnumber in $(cat $logdir/missing_patch.lst 2>/dev/null);do
  	patchnumber=$(echo $ptchnumber|awk -F"!" '{print $1}')
  	xxecho
  	xxecho "   Checking missing patch availability for patch $patchnumber..."
  	set_base_dir
  	check_patch_dir
  	if (($?));then
  		update_lang_list $logdir/patch.lst
  	elif [[ ! -d $PATCH_DIR ]];then
  		unzip_patch
  	fi
  done
fi
  
xxecho
#get_merge_count
if [[ $opatch_type != opatch ]]||[[ $patch_option = rollback ]];then merge_option=single;fi
if [[ $merge_option != merge ]];then 
	choose_patch
fi

if [[ $merge_option = merge ]];then
	xxecho
	# Check each patch directory is available
	xxecho "   Checking destination directory and content..."
	running_statement "Checking for destination directory ${merge_name}"
	if [[ -d $OPATCH_TOP/${merge_name}_${tech_version} ]];then
		format_statement "Checking for destination directory ${merge_name}" "available"
		running_statement "Checking for valid directories"
		if [[ $(ls $OPATCH_TOP/${merge_name}_${tech_version}/*/etc 2>/dev/null|wc -l) -gt 0 ]];then
			format_statement "Checking for valid directories" "available"
			patchnumber=$merge_name
			patchdir=${merge_name}_${tech_version}_$patch_ext
			PATCH_DIR=$OPATCH_TOP/$patchdir
			merge_avail=yes
		else
			format_statement "Checking for valid directories" "unavailable"
		fi
	else
		format_statement "Checking for destination directory ${merge_name}_${tech_version}" "unavailable"
		running_statement "Creating destination directory ${merge_name}_${tech_version}"
		mkdir -p $OPATCH_TOP/${merge_name}_${tech_version}
		chmod -R 777 $OPATCH_TOP/${merge_name}_${tech_version}
		status_statement "Creating destination directory ${merge_name}_${tech_version}" $?
		if (($?));then
			xxecho
			xxecho "   Failed to create destination directory ${merge_name}_${tech_version}"
			xxecho "   Please check read/write rights in \$OPATCH_TOP"
			rm -rf $OPATCH_TOP/${merge_name}_${tech_version} 2>/dev/null 
			exit_program PermissionError
		fi
	fi
	if [[ $merge_avail != yes ]];then
		xxecho
		xxecho "   Status of patch availability for bundling..."
		merge_failed=0
		egrep_statement=$(echo !$tech_version!|sed 's%_%!|!%g')
		if [[ $egrep_statement = "" ]];then egrep_statement=" *";fi
		for ptchnumber in $(cat $logdir/patch.lst 2>/dev/null|egrep $egrep_statement);do
			patchnumber=$(echo $ptchnumber|awk -F"!" '{print $1}')
    	set_base_dir
			if [[ -d $PATCH_DIR_ALT && $PATCH_DIR != $PATCH_DIR_ALT ]];then
			  PATCH_DIR=$PATCH_DIR_ALT
			fi
			format_statement "Patch $patchnumber" "available" 
		done
		for ptchnumber in $(cat $logdir/missing_patch.lst 2>/dev/null|egrep $egrep_statement);do
			patchnumber=$(echo $ptchnumber|awk -F"!" '{print $1}')
			format_statement "Patch $patchnumber" "unavailable" 
			merge_failed=1
		done
		if (($merge_failed));then
			xxecho
			xxecho "   One or more bundle patches not available in \$OPATCH_TOP!"
			rm -rf $OPATCH_TOP/${merge_name}_${tech_version} 2>/dev/null 
			exit_program MergeError
		fi
		xxecho
		xxecho "   Creating bundle patch directory..."
		link_failed=0
		for patchnumber in $(echo $patch_list|sed 's%,% %g');do
      set_base_dir
			if [[ -d $PATCH_DIR_ALT && $PATCH_DIR != $PATCH_DIR_ALT ]];then
			  PATCH_DIR=$PATCH_DIR_ALT
			fi
			PATCH_DIR=$PATCH_DIR/$patchnumber
			running_statement "Creating link for patch '$patchdir'"
			ln -s $PATCH_DIR $OPATCH_TOP/${merge_name}_${tech_version}/$patchdir
			status_statement "Creating link for patch '$patchdir'" $?
			((link_failed+=$?))
		done
		if (($link_failed));then
			xxecho
			xxecho "   One or more links failed to be created in \$OPATCH_TOP/${merge_name}_${merge_lang}!"
			xxecho "   Please check read/write rights in \$OPATCH_TOP"
			rm -rf $OPATCH_TOP/${merge_name}_${tech_version} 2>/dev/null 
			exit_program PermissionError
		fi
		# Need to add admrgpch command here
		patchdir=${merge_name}_${tech_version}_$patch_ext
		PATCH_DIR=$OPATCH_TOP/$patchdir
		patchnumber=$merge_name
		xxecho
		xxecho "   Bundling of patches successfully completed !"
		xxecho "      Name of bundle directory: ${merge_name}_${tech_version}"		
	fi
	opatch_type=opatch
	opatch_apply_mode=napply
else
	xxecho "   Only one valid patch in patch request:"
	xxecho "      Patchnumber: $patchnumber "
	merge_option=single
  set_base_dir
	set_patch_dir nopermissions
fi
if [[ $opatch_type = bsu ]];then
  if [[ $skip_download = no ]];then
    for bsu_patch_file in $(ls $PATCH_DIR/*jar);do
      bsu_patch_id=$(echo $(basename $bsu_patch_file)|awk -F"." '{print $1}')
      echo "$patchnumber:$bsu_patch_id" >> $logdir/bsu_patches.id
    done 
  else
    for bsu_patch_id in $(grep "$patchnumber" $logdir/bsupatch.lst|sort -u);do
      echo "$bsu_patch_id" >> $logdir/bsu_patches.id
    done
  fi
fi
if [[ $patch_option = check || $patch_option = verify || $patch_option = apply || $patch_option = rollback ]];then 
 	line_statement
  if [[ $opatch_type = opatch ]];then
  # Check for conflicts
  	conflict_status=0
 	  opatch_patch_id=""
    count_applied=0
  	if [[ $(basename $PATCH_DIR) != $patchnumber && $(basename $PATCH_DIR) != oui && $opatch_apply_mode = apply ]]||[[ $opatch_apply_mode = napply ]];then
    	xxecho "   Checking if subset patches are applied..."
		  count_subpatch=0
		  for patch_etc_dir in $(find $PATCH_DIR -name etc -type d);do
        PATCH_SUB_DIR=$(dirname $patch_etc_dir)
        PATCH_SUB_NAME=$(basename $PATCH_SUB_DIR)
        ((count_subpatch+=1))
        check_patch_applied "$PATCH_SUB_NAME" "$patchnumber"
        if [[ $patch_applied = yes ]];then
          ((count_applied+=1))
          if [[ $patch_option = rollback ]];then
            opatch_patch_id="$opatch_patch_id,$PATCH_SUB_NAME"
          fi
        else 
          if [[ $patch_option != rollback ]];then
            opatch_patch_id="$opatch_patch_id,$PATCH_SUB_NAME"
          fi
        fi
		  done
		  opatch_patch_id=$(echo $opatch_patch_id|sed 's%,,*%,%g'|sed 's%^,%%g'|sed 's%,$%%g')
		  if [[ $patch_option = rollback ]];then
		    if ((!$count_applied));then 
		      end_program PatchNotApplied
		    fi
		  elif [[ -z $opatch_patch_id && $run_option != force ]];then
		    if [[ $patch_option = check ]];then 
		      xxecho "   All subpatches for patch $patchnumber are applied to $ENV_NAME ($HOST_NAME)."
		    fi
				end_program SubsetApplied
		  fi
      xxecho
		elif [[ $patch_option = rollback && $patch_applied = no ]];then
    	xxecho "   Checking if subset patches are applied..."
		  xxecho "      No subset patches found."
  		xxecho
  		xxecho "   Rollback of patch $patchnumber from $ENV_NAME ($HOST_NAME) is not required."
	    end_program PatchNotApplied 
		fi
		if [[ $patch_option = check ]];then 
		  if [[ $patch_applied = no || $count_applied -lt $count_subpatch ]];then
  		  if (($count_applied));then
    		  xxecho "   Patch $patchnumber is only partially applied to $ENV_NAME ($HOST_NAME)."
    		else 
    		  xxecho "   Patch $patchnumber is not applied to $ENV_NAME ($HOST_NAME)."
    		fi
  	    end_program PatchNotApplied 
  	  else
  	    end_program
  	  fi
		fi
		if [[ $patch_option = apply || $patch_option = verify ]];then
    	xxecho "   Checking for patch conflicts..."
    	check_patch_conflicts $patchnumber 
    	((conflict_status+=$?))
    	if (($conflict_status))&&[[ $run_option != force ]]&&[[ $patch_option = apply ]];then
    	  xxecho
    	  yes_no "   Do you wish to force apply patch $patchnumber? [N]: " "N" "ignore"
    	  if (($?));then
      		xxecho
      		exit_program PatchConflictError
      	else 
      	  run_option=force
      	  force_option="-force"
      	fi
    	fi
    	if [[ $patch_option = verify ]];then
    		end_program
    	fi
    	if [[ $patch_applied = yes ]];then
    	  # Patch is a subset of already applied
    	  xxecho
    	  if [[ ! -z $superset ]];then
					xxecho "   Applied to $ENV_NAME ($HOST_NAME) as part of superset patch(es):"
          for suppatch in $(echo $superset|sed 's%,% %g');do
            xxecho "      Patch: $suppatch"
          done
				else
					xxecho "   Applied to $ENV_NAME ($HOST_NAME) as part of superset patch."
				fi
    	  end_program SubsetApplied
    	fi
    fi
  elif [[ $opatch_type = runInstaller ]];then
  	if [[ $patch_option = verify ]];then
  		xxecho "   Checking for conflicts for runInstaller is not supported"
  		exit_program ParameterError 
  	fi
    # Check if patchset is installed
  	xxecho "   Checking if patchset is installed..."
  	install_comp=0
# 	  toplevel_installed=$(grep "<COMP" $TARGET_ORACLE_HOME/inventory/ContentsXML/comps.xml 2>/dev/null|grep "\"$toplevel_component\"" |awk -F"=" '{print $2}'|awk '{print $1}'|sed 's%\"%%g'|head -1)
#    for installer_type in $(echo "PATCHSET PATCH COMP");do
#      toplevel_installed_version=$(grep "<$installer_type" $TARGET_ORACLE_HOME/inventory/ContentsXML/comps.xml  2>/dev/null|grep "\"$toplevel_component\"" |awk -F"=" '{print $3}'|awk '{print $1}'|sed 's%\"%%g'|head -1)
#      if [[ ! -z $toplevel_installed_version ]];then
#        toplevel_installed_ver_num=$(echo "$toplevel_installed_version"|sed 's%.%%g')
#        break
#      fi
#    done

  	for dependency_comp_param in $(echo $dependency_list|sed 's%,% %g');do
  	  dependency_comp=$(echo $dependency_comp_param|awk -F":" '{print $1}')
  	  component_version=$(echo $dependency_comp_param|awk -F":" '{print $2}')
  	  component_ver_num=$(echo $component_version|sed 's%.%%g')
    	running_statement "Checking for $dependency_comp version [$component_version]"
    	component_installed_version=""
    	component_invalid=1
      for installer_type in $(echo "PATCHSET PATCH COMP");do
        component_installed_version=$(grep "<$installer_type" $TARGET_ORACLE_HOME/inventory/ContentsXML/comps.xml  2>/dev/null|grep "\"$dependency_comp\""| awk -F"=" '{print $3}'|awk '{print $1}'|sed 's%\"%%g'|head -1)
        if [[ ! -z $component_installed_version ]];then
          component_invalid=0
          component_inst_ver_num=$(echo "$component_installed_version"|sed 's%.%%g')
          break
        fi
      done
     	if (($component_invalid));then
        format_statement "Checking for $dependency_comp version [$component_version]" "not installed"
        ((install_comp+=1))
      else
     	  if [[ $component_ver_num -gt $component_inst_ver_num ]];then
        	format_statement "Checking for $dependency_comp version [$component_version]" "not installed"
        	((install_comp+=1))
        elif [[ $component_inst_ver_num -ge $component_ver_num ]];then
        	format_statement "Checking for $dependency_comp version [$component_version]" "installed"
      	else
        	format_statement "Checking for component version [$component_version]" "unknown   "
        	xxecho
          xxecho "   Unable to determine if $patchnumber is applied to $ENV_NAME"
        	xxecho "      Patch version [$toplevel_component]: $component_version"
        	exit_program UnknownVersion
        fi
      fi
    done
    if ((!$install_comp));then
      xxecho
      xxecho "   Patchset $patchnumber or later already applied to $ENV_NAME"
    	xxecho "      Patchset version [$toplevel_component]: $toplevel_component_version"
    	if [[ $patch_option = apply || $patch_option = check ]];then
      	end_program
      fi
    elif [[ $patch_option = rollback ]];then
      xxecho
   		xxecho "   Rollback of patchset $patchnumber from $ENV_NAME ($HOST_NAME) is not required."
	    end_program PatchNotApplied 
	  elif [[ $patch_option = check ]];then
 		  xxecho
 		  xxecho "   Patchset $patchnumber is not applied to $ENV_NAME ($HOST_NAME)."
	    end_program PatchNotApplied 
	  fi
  elif [[ $opatch_type = bsu ]];then
   	if [[ $patch_option = verify ]];then
  		xxecho "   Checking for conflicts for WebLogic bsu is not supported"
  		exit_program ParameterError 
  	fi
   	xxecho "   Checking if patch $patchnumber is applied..."
   	running_statement "Checking patch $patchnumber"
   	patch_installed=0
    cd $BSU_LOC >/dev/null 2>&1
    if ((!$?));then
      bsu_patch_id=$(grep $patchnumber $logdir/bsu_patches.id 2>/dev/null|awk -F":" '{print $2}'|sort -u)
     	bsu_patch_id=${bsu_patch_id:-unknown}
      check_bsu_patches "$patchnumber:$bsu_patch_id"
      for bsu_patch_info in $(grep "$patchnumber" $logdir/bsu_patches.id 2>/dev/null|sort -u);do
       	running_statement "Checking patch $patchnumber [$bsu_patch_id]"
      	#patch_installed=$(egrep "$bsu_patch_id|$patchnumber" $logdir/bsu_patchlist.tmp)
      	patch_installed=$(egrep "$bsu_patch_id|$patchnumber" $logdir/bsu_patch_list.adp 2>/dev/null)
       	patchid_installed=$(echo $patch_installed|grep "$bsu_patch_id"|wc -l)
       	patchnum_installed=$(echo $patch_installed|grep "$patchnumber"|wc -l)
      	if (($patchid_installed));then
      	  bsu_ptype=$(echo $patch_installed|awk -F":" '{print $3}')
      	  format_statement "Checking patch $patchnumber [$bsu_patch_id - $bsu_ptype]" "applied  "
       	else
       	  format_statement "Checking patch $patchnumber [$bsu_patch_id]" "not applied"
       	fi
      done
      if (($patchid_installed))||(($patchnum_installed));then
        overlay_found=0 
        if [[ $patch_option != rollback ]];then
          xxecho
          xxecho "   Patch $patchnumber already applied to $ENV_NAME"
      	  end_program
      	elif [[ $bsu_ptype = PSU ]];then
      	  running_statement "Checking overlay patches for $patchnumber [$bsu_patch_id - $bsu_ptype]"
      	  overlay_found=$(grep -c "OVERLAY:$db_version_name" $logdir/bsu_patch_list.adp 2>/dev/null)
      	  if (($overlay_found));then
      	    format_statement "Checking overlay patches for $patchnumber [$bsu_patch_id - $bsu_ptype]" "found   "
          else
       	    format_statement "Checking overlay patches for $patchnumber [$bsu_patch_id - $bsu_ptype]" "not found"
          fi
          xxecho
          xxecho "   Patch $patchnumber applied to $ENV_NAME"
          if (($overlay_found));then
      	    xxecho
      	    xxecho "   Following OVERLAY patches are applied on top of patch $patchnumber [$bsu_patch_id - PSU]: "
      	    for bsu_overlay_info in $(grep "OVERLAY:$db_version_name" $logdir/bsu_patch_list.adp 2>/dev/null|sort -u);do
      	      overlay_found=1 
              overlay_patch=$(echo $bsu_overlay_info|awk -F":" '{print $1}')
      	      overlay_id=$(echo $bsu_overlay_info|awk -F":" '{print $2}')
      	      overlay_version=$(echo $bsu_overlay_info|awk -F":" '{print $4}')
      	      xxecho "      -> OVERLAY: $overlay_patch [$overlay_id] - $overlay_version"
      	    done
      	    xxecho
            yes_no "   Do you wish to force rollback all overlay patches? [Y]: " Y
            run_option=force
          fi
      	fi
      elif [[ $patch_option = rollback ]];then
		    end_program PatchNotApplied
  	  elif [[ $patch_option = check ]];then
   		  xxecho
   		  xxecho "   Patch $patchnumber is not applied to $ENV_NAME ($HOST_NAME)."
  	    end_program PatchNotApplied 
	    fi
    fi
    cd - >/dev/null 2>&1
  fi
fi
if [[ $patch_option = apply ]]||[[ $patch_option = rollback ]];then
	check_running_opatch
  if [[ $opatch_type = opatch ]]&&(($dbtier));then
    check_running_db
  fi
	check_restart_mode_pre
fi
if [[ $newpatch = yes ]];then
  if [[ $run_mode = normal ]]&&[[ $patch_option != rollback ]];then
  	display_readme
  fi
  if [[ $patch_option = readonly ]];then end_program;fi
  line_statement

  if [[ $patch_option = rollback ]];then
    yes_no "   Do you wish to rollback patch $patchnumber on $ENV_NAME now ? [Y]: " Y
  else 
    yes_no "   Do you wish to apply patch $patchnumber on $ENV_NAME now ? [Y]: " Y
  fi
  xxecho

  get_tar_number
  line_statement
fi

#check_ad_level
create_patch_log
if [[ $skip_download = no ]];then
  check_write_permissions $PATCH_DIR
  if (($?));then exit_program PermissionError;fi
fi
download_end_time=$(date "+%b %d %Y %T")
check_restart_mode
apply_patch
patch_status=$?
line_statement
move_patch_log
log_status=$?
if (($patch_status))||(($log_status)); then
	xxecho
	xxecho " *****************************************************************************"
	xxecho " *   !!! PATCH ACTION HAS FAILED !!!                                         *"
	xxecho " *****************************************************************************"
	xxecho
	xxecho "     Patch action failed, please rerun patch action when problem has been fixed!"
	xxecho "     Please check logfiles for errors at:"
	xxecho "     $patchlog/$patchdir"
	xxecho
	xxecho " *****************************************************************************"
	xxecho
	exit_program PatchFailedError
else
	#If patch has previously failed, remove old restart files
	line_statement
	if [[ $tarnumber = "" ]];then
		tarnumber="NO-SR"
	fi
	if [[ $initials = "" ]];then
		initials="Unknown"
	fi
	create_patch_info
	cat $patchlog/$patchdir/PatchInfo$count_info.log 2>/dev/null|while read line;do
		xxecho "   $line" N
	done
	cat $patchlog/$patchdir/PatchInfo$count_info.log 2>/dev/null
	line_status=1
	line_statement
	if (($CleanPatch));then
		clean_files
		xxecho
	fi
	end_program
fi

