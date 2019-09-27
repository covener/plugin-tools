@echo off
REM This script is an alternative to PCT for basic IHS + Liberty.
REM Changes to this file will not be preserved.

set WEBSERVER_NAME=webserver1
set SR=%~dp0..
IF %SR:~-1%==\ SET SR=%SR:~0,-1%
set PLG_ROOT=%~1

if "%~1" == "" (
  @echo Parameter must be Plug-in install root
  exit /B 1
)
if not exist "%PLG_ROOT%" (
  @echo %PLG_ROOT% not found
  exit /B 1
)

set PLG_BIN=%PLG_ROOT%\bin\32bits

if not exist "%PLG_BIN%\mod_was_ap24_http.dll" (
  @echo %PLG_BIN% does not look like a plugin install root
  exit /B 1
)

set CONFIG_FILE=%SR%\conf\httpd.conf

mkdir "%PLG_ROOT%\logs\%WEBSERVER_NAME%" 2> NUL
mkdir "%PLG_ROOT%\config\%WEBSERVER_NAME%" 2> NUL

findstr mod_was_ap24_http.dll "%CONFIG_FILE%"  > NUL
if NOT ERRORLEVEL 1 (
  @echo already configured
  exit /B 1
)

echo. >> %CONFIG_FILE%
echo ^<IfFile "%PLG_ROOT%/config/%WEBSERVER_NAME%/plugin-cfg.xml"^>                 >>  "%CONFIG_FILE%"
echo LoadModule was_ap24_module "%PLG_BIN%/mod_was_ap24_http.dll"                   >> "%CONFIG_FILE%"
echo WebSpherePluginConfig "%PLG_ROOT%/config/webserver1/plugin-cfg.xml"            >> "%CONFIG_FILE%"
echo ^</IfFile^>                                                                    >> "%CONFIG_FILE%"

if not exist "%PLG_ROOT%\config\%WEBSERVER_NAME%\plugin-key.kdb" copy "%PLG_ROOT%\etc\plugin-key.*" "%PLG_ROOT%\config\%WEBSERVER_NAME%\"

echo To continue, configure your server.xml with ^<pluginConfiguration pluginInstallRoot="%PLG_ROOT%" /^>, 
echo.
echo ... then transfer your usr/servers/server-name/logs/state/plugin-cfg.xml to 
echo.
echo '%PLG_ROOT%\config\%WEBSERVER_NAME%\plugin-cfg.xml'


