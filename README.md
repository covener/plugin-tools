Short tools related to the WebSphere WebServer Plug-in
in WebSphere Application Server.

  * scanplugin.pl

    With LogLevel "TRACE", Report on exceptional requests (slow, marked down,
    bad status code).

  * plgstats.pl

    With any LogLevel up-to-and-including "STATS", report cross-process 
    statistics for affinity/non-affinity requests.

  * countchunks.pl

    With LogLevel "TRACE", Add up the chunks written by the plugin, you must
    filter the input to be a single request yourself.

  * linux_prereq.sh

    Grab 32-bit and 64-bit prerequisites on RHEL.

  * wsptp.pl

    Summarize Java Proxy logs usage of mem2mem partition tables

  * retrievesigner.jar

    This now has a new home (as certutil) at https://github.com/covener/certutil

  * genPluginConfig-restConnector.sh

    Shell script demonstrating how to generate plugin-cfg.xml over the Liberty
    restConnector (JMX over HTTP)

  * mpmstats_blame*.pl

    Basic/starter parsers of 'mpmext' logformat logs http://publib.boulder.ibm.com/httpserv/ihsdiag/mpmstats_module_timing.html

  * new_install_root

    A short script that allows a driving z/OS system to relink an IHS 
    instance/server/rw/config directory into a final path that may not 
    exist yet.

  * list_ca_details.sh

    Dumps a KDB's CA contents in plain text so it can be searched or
    post-processed.
       
  * imifixhelper.sh
  
    Example/Sample script to drive IIM command line fix install/list/removal   

  * ihsinstall.sh

    Example/Sample script to download/update IIM and install IHS/PlG/WCT v9

  * plugingen.war
  
    Example/Sample web module to generate plugin-cfg.xml without jconsole.
    Source and more info here: https://github.com/covener/plugingen_sample_app
    
  * simplepct
   
    Perform a basic config of the WAS Plugin to IHS/Apache. Note: Not for use with the IHS
    archive install where this is pre-configured for you.
    
