@echo off & setlocal

SET action=%1

SET result=false

REM "If the action is install, copy the updated jar to modules."

if "%action%"=="install" (
echo Updating bsu modules
copy bsu_update\Patch\com.bea.cie.comdev_6.1.3.1.jar ..\..\modules
copy bsu_update\Patch\com.bea.cie.patch-client_3.3.0.0.jar ..\..\modules\features
copy bsu_update\Patch\com.bea.cie.patch-client_3.3.0.0.xml ..\..\modules\features
SET result=true
)

REM "If the action is rollback, copy the GA version jar to modules."

if "%action%"=="rollback" (
echo Restoring bsu modules
del ..\..\modules\com.bea.cie.comdev_6.1.3.1.jar
copy bsu_update\GA\com.bea.cie.patch-client_3.3.0.0.jar ..\..\modules\features
copy bsu_update\GA\com.bea.cie.patch-client_3.3.0.0.xml ..\..\modules\features
SET result=true
)

REM "If the action is invalid, display error."

if "%result%" == "false" (
echo Error - Invalid input. Value should be either rollback or install
echo Usage - bsu_update.bat install/rollback
echo Example - bsu_update.bat install
)