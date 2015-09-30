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

    Tiny java utility to grab the root CA from a port and either dump it to a
    file or directly add it to plugin-key.kdb.  This is useful for fixing the most
    common forms of GSKit 414 errors, where the WAS root CA is simply not present
    in plugin-key.kdb.  Note: If you subsequently propagate the same keystore from
    the dmgr to the webserver (which is the preferred way to ensure the right CAs
    are trusted) any changes from this tool will be lost.

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
       
     
