#!/bin/sh


action=$1

# If the action is invalid, display error.

if [ $# -eq 0  -o "$action" == "" -o "$action" != "rollback" -a "$action" != "install" ] ; then
        echo "Invalid input. Value should be either rollback or install.
Usage: . ./bsu_update.sh <install or rollback>
Example: . ./bsu_update.sh install"
        exit 1 
fi

# If the action is install, copy the updated jar to modules". 
if [ $action == "install" ] ; then

echo "Installing...
Updating bsu modules"
/bin/cp -f bsu_update/Patch/com.bea.cie.comdev_6.1.3.1.jar ../../modules
/bin/cp -f bsu_update/Patch/com.bea.cie.patch-client_3.3.0.0.xml ../../modules/features
/bin/cp -f bsu_update/Patch/com.bea.cie.patch-client_3.3.0.0.jar ../../modules/features
if [ $? -eq 0 ];then
   echo "Update was successful."
else
   echo "Install failed"
fi
fi

# If the action is rollback, copy the GA version jar to modules. 
if [ $action == "rollback" ] ; then
echo "Rollback...
Updating bsu modules"
/bin/rm -f ../../modules/com.bea.cie.comdev_6.1.3.1.jar
/bin/cp -f bsu_update/GA/com.bea.cie.patch-client_3.3.0.0.xml ../../modules/features
/bin/cp -f bsu_update/GA/com.bea.cie.patch-client_3.3.0.0.jar ../../modules/features
if [ $? -eq 0 ];then
   echo "Rollback was successful."
else
   echo "Rollback failed"
fi
fi

