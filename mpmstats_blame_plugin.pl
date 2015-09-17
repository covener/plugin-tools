#!/usr/bin/perl
# Parse log files recommended by 'mpmtats enhanced module timings' to see what
# % the WAS Plugin took for responses whose response time was > 1 second

while(<>) { 
    if (/TRH=mod_was_ap22_http.c:(\d+)ms.*?(\d+)$/) { 
      my $plg = $1 * 1000;
      my $total = $2;
      if ($total > 1*1000*1000) { 
        my $percent =($plg/$total)*100 ;
        printf "%03.2f %s\n",  $percent, $_;
      }
    }
}


