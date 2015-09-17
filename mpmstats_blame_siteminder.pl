#!/usr/bin/perl
# Parse log files recommended by 'mpmtats enhanced module timings' to see what
# % siteminder took for static files whose response time was > 1 second

# 1.2.3.4 - - [16/Sep/2015:09:32:51 -0400] "GET /foo.js HTTP/1.1" 200 17180 TRH=core.c:6ms TCA=mod_sm22.cpp:1236ms TCU=- TPR=0ms TAC=- 1244085
while(<>) { 
    if (/mod_sm22.cpp:(\d+)ms.*?(\d+)$/) { 
      my $sm = $1 * 1000;
      my $total = $2;
      if ($total > 1*1000*1000) { 
        my $percent =($sm/$total)*100 ;
        printf "%03.2f %s\n",  $percent, $_;
      }
    }
}


