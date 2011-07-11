#!/usr/bin/perl
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


# Parse a plugin log for STATS entries.
use strict;
use HTTP::Date; # part of LWP
use Getopt::Std;
use Statistics::Descriptive;

my %entries = ();
my %byprocess = ();
my %totalbyserver = ();
my %affinitybyserver = ();
my %nonaffinitybyserver = ();
my ($r, $pid, $tid, $time, $timestr, $uri, $begin, $end);
my $file = $ARGV[0];
my $ln;
my $logFile="/tmp/plgstats.log";
open(LOGFILE, ">$logFile") || die "Error opening $logFile $!\n";

my $cmdlineok = 1;
my %options;

getopts("s:p:", \%options) or $cmdlineok = 0;
if (scalar(@ARGV) < 1) {
  $cmdlineok = 0;
}

if (!$cmdlineok) {
  usage();
}

print "\n See $logFile to cross-check the results, and make sure you only compare servers in the same ServerCluster.\n";

while(<>) { 
  $ln++;
  chomp();
  if ($ln % 200000 == 0) { 
    print STDERR "reading line $ln...\n";
  }

  if (/\[(.*?)\] (\w+) (\w+)/) { 
    $timestr = $1;
    $pid = $2;
    $tid = $3;
  }
  else { 
    next; 
  }


  if (/serverSetFailoverStatus: Server (\w+) : pendingRequests (\d+) failedRequests (\d+) affinityRequests (\d+) totalRequests (\d+)/) { 
     $time = str2time($timestr);
     my $server = $1;
     my $pending = $2;
     my $failed = $3;
     my $affinity = $4;
     my $total = $5;
     if (!defined($options{'s'}) || $server =~ /$options{'s'}/) { 
       if (!defined($options{'p'}) || $pid =~ /$options{'p'}/) { 
         $entries{$server . $pid} = { name => $server, total => $total, affinity => $affinity, pid => $pid }  
       # later entries for the same server in the same pid overwrite earlier ones
       }
     }
  }
}

my ($k, $v, $kk, $vv);
while (($k, $v) = each(%entries)) { 
   printf LOGFILE "server %s in pid %s total %d affinity %d net LB %d\n", 
           $v->{'name'},  $v->{'pid'} , $v->{'total'}, $v->{'affinity'}, $v->{'total'} - $v->{'affinity'};
  # add entries from N PID's together under the same server name, 
  $totalbyserver{$v->{'name'}} += $v->{'total'};
  $affinitybyserver{$v->{'name'}} += $v->{'affinity'};
  $nonaffinitybyserver{$v->{'name'}} += $v->{'nonaffinity'};
  $byprocess{$v->{'pid'}} += $v->{'total'} - $v->{'affinity'};
}

print "\n\n";
print "Cross-process totals\n";
while (($k, $v) = each(%totalbyserver)) { 
   printf "  Server %s over all processes total %s affinity %s non-affinity %s\n", 
          $k, $v, $affinitybyserver{$k}, $v - $affinitybyserver{$k};

}

printf "  std deviation for total requests cross-proc is %s\n", stddev(values(%totalbyserver));
printf "  std deviation for affinity requests cross-proc is %s\n", stddev(values(%affinitybyserver));
printf "  std deviation for non-affinity requests cross-proc is %s\n", stddev(values(%nonaffinitybyserver));
print "\n\n";

while (($k, $v) = each(%byprocess)) { 
   my @pidtotal;
   printf "Totals for proc %s\n", $k;
   while (($kk, $vv) = each(%entries)) { 
     if ($vv->{'pid'} eq $k) { 
       push @pidtotal, $vv->{'total'} - $vv->{'affinity'};
       printf "  Server %s total %s affinity %s non-affinity %s\n", 
                 $vv->{'name'}, $vv->{'total'} , $vv->{'affinity'},  $vv->{'total'} - $vv->{'affinity'};
     }
   }
   printf "  std deviation for total connections across all servers in pid %s is %d\n", $k, stddev(@pidtotal);
}

sub usage() { 
  print STDERR <<END;
Usage: $0 [options]... /path/to/http_plugin.log

         -s server-regexp              regexp to match server names.
         -p pid-regexp                 regexp to match hex pid.
END
  exit 1;
}

sub stddev() { 
  my $stat = Statistics::Descriptive::Full->new();
  $stat->add_data(@_);
  return $stat->standard_deviation();
}
