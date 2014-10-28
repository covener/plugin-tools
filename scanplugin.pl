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

# Parse a plugin log for response times and noteworthy errors.  
# Summarizes 1GB in about 70 seconds
# TODO: it would be nice if it knew how to track requests that used the same backend socket.

use strict;
use HTTP::Date; # part of LWP
use Getopt::Std;

my %threads= ();
my @requests = ();
my ($r, $i, $pid, $tid, $time, $timestr, $begin, $end);
my $ln;
my $bld1;
my @errorArray = ();
my @sessionIDArray = ();
my @statsArray = ();
my $bldcnt;
my $sessionID;
my $webserver;
my $interleavedline;
my $reloads = 0;

my %options = ();
getopts("da", \%options) or die "invalid options";

my $file = $ARGV[0];
if(!defined($file)) { 
  print "scanplugin.pl [options] http_plugin.log\n";
  print "\t-d debug to stderr\n";
  print "\t-a summarize all requests, not just interesting ones\n";
  exit 1;
}

my $opt_debug = $options{d};
my $opt_all = $options{a};

open (OVERWRITE, ">scanplugin.log") or die "Error opening logfile $!\n";

$bld1 = "Not Reported";
$webserver = "Not Reported";

sub my_str2time { 
   my $timestr = $_[0];
   my $rv = str2time($timestr);
                     # 05/Oct/2014:21:55:30.99166
   if ($timestr =~ /(.*)\.(\d{5})$/) { 
       $rv = str2time($1);
       # add fractional seconds 
       
       print "my_str2time full second part is $rv 2=$2 " . $2/100000 . "str= $timestr\n";
       $rv += $2/100000;
   }
   print "my_str2time return $rv for timestring $timestr\n";
   return $rv;
}

sub readpidtid() { 
  my $line = $@;
   # Always grab the pid/tid and timestr
    if (/\[(.*?(?:\.\d{5}))?\] (\w+) (\w+)/) { 
        $timestr = $1;
        $pid = $2;
        $tid = $3;
    }
    elsif ( /\[(.*?)(?:\.\d{5})?\] \d+\/QTMHHTTP\/\w+ (\d+) (\d+)/) { 
        $timestr = $1;
        $pid = $2;
        $tid = $3;
    }
}

# Read the next line, but look for a concatenated/buffered line.  8.0 and earlier
# has a quirk where the newlines are not written in the same call to write()
# so they may get interleaved with other processes' work.
sub nextline() { 
    my $line = undef;
    if (defined($interleavedline)) { 
        $line = $interleavedline;
        $interleavedline = undef;
    }
    else { 
        $line = <>;
    }
    $_ = $line;
    if (/^(\[(?:.*?)(?:\.\d{5})?\] \w+ \w+.*)(\[(?:.*?)(?:\.\d{5})?\] \w+ \w+.*$)/) { 
        $line = $_ = $1;
        $interleavedline = $2 
    }
    return $line;
}

my $lastline;
while(nextline()) { 
    $lastline = $_;
    $ln++;
    chomp();
    if ($ln % 20000 == 0) { 
        print STDERR "reading line $ln...\n";
    }


    # Loading ErrorArray with unique Error Messages
    if (/ERROR: (.*)/){
        my $itercnt = 1;
        my $addVal = 1;
        my $bldError = "ERROR: $1";
        foreach $i (@errorArray){
            if ($i eq $bldError){
                $addVal = 0;
            }
            $itercnt++;
        }
        push (@errorArray, $bldError) if ($addVal == 1);
    }

    ##### Don't break if/elsif below ###

    # Getting Bld version.
    if (/PLUGIN: Bld version: (\w+).(\w+).(\w+).(\w+)/){
        $bldcnt++;
        $bld1 = "$1.$2.$3.$4";
    }
    elsif (/Config was successfully reloaded/) { 
       $reloads++;
    }
    elsif (/HTTP\/1.\d (\d+) (?!Continue)\w+/) {
        readpidtid();
        if(defined $threads{$pid . $tid}) { 
            $threads{$pid . $tid}->{'respcode_stop'} = my_str2time($timestr);
            
            printf LOGFILE "got a HTTP response, $_, esipending=%d?\n", defined $threads{$pid . $tid}->{'esipending'};
            if (!defined $threads{$pid . $tid}->{'esipending'}) {
                $threads{$pid . $tid}->{'read_response_end'} = my_str2time($timestr);
                $threads{$pid . $tid}->{'status'} = $1;
            }
            else {
                finish_esi_request($pid, $tid, 0); 
            }
        }
    }

    # Getting Webserver type
    elsif (/PLUGIN: Webserver: (.*)/){
        $webserver = $1
    }

    elsif (/DETAIL:    Cache-Control: (.*)/){
        readpidtid();
        my $var = $1;
        chomp($var);
        $var =~ s/\r//g;
        $threads{$pid . $tid}->{'cachecontrol'} = $var;
        if ($var =~ m/no-cache="?Set-Cookie/i) { 
            $threads{$pid . $tid}->{'cachecontrolsetcookie'} = 1;
        }
        if ($var =~ m/no-cache/i) { 
            $threads{$pid . $tid}->{'cachecontrolnocache'} = 1;
        }
    }
    elsif (/DETAIL:    Expires: (.*)/){
        readpidtid();
        my $var =  $1;
        chomp($var);
        $var =~ s/\r//g;
        $threads{$pid . $tid}->{'expires'} = $var;
    }
    # Loading SessionIDArray with Session SetCookie info
    elsif (/DETAIL:    Set-Cookie: (.*)/){
        readpidtid();
        my $var =  $1;
        chomp($var);
        $var =~ s/\r//g;
        my $itercnt = 1;
        my $addVal = 1;
        my $sessionID = "Set-Cookie: $var";
        if (!defined($threads{$pid . $tid}->{'setcookies'})) { 
            $threads{$pid . $tid}->{'setcookies'} = ($var);
        }
        else { 
            $threads{$pid . $tid}->{'setcookies'} = ($threads{$pid . $tid}->{'setcookies'}, $var);
        }
        foreach $i (@sessionIDArray){
            if ($i eq $sessionID){
                $addVal = 0;
            }
            $itercnt++;
        }
        push (@sessionIDArray, $sessionID) if ($addVal == 1);
    }
    # Loading Stats Array with Stats info
    elsif (/(.*) - STATS: ws_server: serverSetFailoverStatus: Server (.*)/){
        readpidtid();
        my $itercnt = 0;
        my $addVal = 1;
        my $statsInfo = "$1 - STATS: ws_server: serverSetFailoverStatus: Server $2";
        my $aSize = length(@statsArray);
        for my $i (@statsArray) {
            my $colon = index($i, " : ");                                 #Looking for this value which designates the server name
            my $bracket = index($i, "]");                                 #Looking for the end of the Timestamp entry
            my $process = substr($statsInfo, ($bracket + 1), ($bracket + 9));
            my $server = substr($statsInfo, ($bracket + 10), ($colon - $bracket));
            my $sub_str = substr($statsInfo, ($bracket + 1), ($colon - $bracket));
            my $arrayItem = (index($i, $process) + index($i, $server));
            if ($arrayItem < 0){
                splice @statsArray, $itercnt, 1;                           #Removes existing entry
                    push (@statsArray, $statsInfo);                            #Replaces with new entry
                    $addVal = 0;
                last;
            }
            $itercnt++;
        }
        push (@statsArray, $statsInfo) if ($addVal == 1);              #Add new entry
    }
    elsif (/ws_handle_request: Handling WebSphere request/){ 
        readpidtid();
        if ($opt_debug) { 
            printf STDERR "Begin new req $ln: $_\n";
        }
        if (defined($threads{$pid . $tid})) { 
            #printf STDERR "  dup ws_handle at line %d, old beginning line was %d\n", $ln, $threads{$pid . $tid}->{'begin'};
        }
        else { 
            $time = my_str2time($timestr);
            $threads{$pid . $tid} = { time => $time, begin => $ln };  # start tracking this request
            $threads{$pid . $tid}->{'pidtid'} = "$pid $tid";
        }
    }

    elsif (/websphere(?:Begin|Handle)Request: Request is:.*uri='([^']*)'/) { 
        readpidtid();
        if (!defined($threads{$pid . $tid})) { 
            # This is a DETAIL message. If they didn't have DEBUG/TRACE, we'll never see the
            # 'ws_handle_request: Handling WebSphere request' above.
            if ($opt_debug) {
                printf STDERR "Begin new req (alt) $ln: $_\n";
            }
            $time = my_str2time($timestr);
            $threads{$pid . $tid} = { time => $time, begin => $ln };  # start tracking this request
            $threads{$pid . $tid}->{'pidtid'} = "$pid $tid";
        }
        else { 
            if ($opt_debug) {
                printf STDERR "Continue new req (alt) $ln: $_\n";
            }
            $threads{$pid . $tid}->{'uri'} = $1;  
        }
        
    }
    elsif (/websphereEndRequest: Ending the request/) { 
        readpidtid();
        if ($opt_debug) { 
            printf STDERR "End req $ln: $_\n";
        }
        if (!defined($threads{$pid . $tid}->{'time'})) { 
            if ($opt_debug) { 
               print STDERR " didn't see start of req that's ending at line $ln: $_\n"; 
            }
        }
        else { 
            my $hr;
            $time = my_str2time($timestr);
          
            $hr =  { delta => sprintf("%.3f", $time - $threads{$pid . $tid}->{'time'}),  
                uri => $threads{$pid . $tid}->{'uri'} ,
                pidtid => "$pid $tid", 
                begin_line =>  $threads{$pid . $tid}->{'begin'},
                end_time => $timestr,
                end_line => $ln,
                markdowns=> $threads{$pid . $tid}->{'markdowns'},
                esidone  => $threads{$pid . $tid}->{'esidone'},
                posterror=> $threads{$pid . $tid}->{'posterror'},
                miscerror=> $threads{$pid . $tid}->{'miscerror'},
                WSFO => $threads{$pid . $tid}->{'WSFO'},
                clusterdown=> $threads{$pid . $tid}->{'clusterdown'},
                writeerror=> $threads{$pid . $tid}->{'writeerror'},
                status   => $threads{$pid . $tid}->{'status'},
                cachecontrol => $threads{$pid . $tid}->{'cachecontrol'},
                cachecontrolsetcookie => $threads{$pid . $tid}->{'cachecontrolsetcookie'},
                cachecontrolnocache => $threads{$pid . $tid}->{'cachecontrolnocache'},
                setcookies=> $threads{$pid . $tid}->{'setcookies'},
            };
            if (defined($threads{$pid . $tid}->{'read_response_end'})) { 
                $hr->{'appserverdelay'} = sprintf("%.2f", $threads{$pid . $tid}->{'read_response_end'} -  
                    $threads{$pid . $tid}->{'read_response_start'});
            }
            else { 
                $hr->{'appserverdelay'} = -1;
            }

            if (defined($threads{$pid . $tid}->{'waitforcontinue'})) { 
                $hr->{'appserverdelaycontinue'} = sprintf("%.2f", $threads{$pid . $tid}->{'gotcontinue'} -  
                    $threads{$pid . $tid}->{'waitforcontinue'});
            }
            if (defined($threads{$pid . $tid}->{'handshake_start'})) { 
                $hr->{'appserverdelayhandshake'} = sprintf("%.2f", $threads{$pid . $tid}->{'handshake_stop'} -  
                    $threads{$pid . $tid}->{'handshake_start'});
            }
            if (defined($threads{$pid . $tid}->{'body_start'})) { 
                $hr->{'bodyfwddelay'} = sprintf("%.2f", $threads{$pid . $tid}->{'body_stop'} -  
                    $threads{$pid . $tid}->{'body_start'});
            }
            if (defined($threads{$pid . $tid}->{'connfailure'})) { 
                $hr->{'appserverdelayconnect'} = sprintf("%.2f", $threads{$pid . $tid}->{'connfailure'} -  
                    $threads{$pid . $tid}->{'dq'});
            }
            if (defined($threads{$pid . $tid}->{'respcode_start'})) { 
                $hr->{'respcodedelay'} = sprintf("%.2f", $threads{$pid . $tid}->{'respcode_stop'} -  
                    $threads{$pid . $tid}->{'respcode_start'});
            }


            push @requests, $hr;
            delete $threads{$pid . $tid};
        }
    }
    elsif (/just_read = (-?\d+) of the expected (\d+)/) {  # TODO: apache plugin-ism
        readpidtid();
        if ($1 != $2 && defined($threads{$pid . $tid})) { 
            $threads{$pid . $tid}->{'posterror'} = { code=>"just_read $1 of $2", line=>$ln};
        }
    }

    elsif (/(cb_write_body: write failed.*)/) {
        readpidtid();
        if (defined $threads{$pid . $tid}) {
            $threads{$pid . $tid}->{'miscerror'} = { time=>$timestr, line=>$ln , text=>$1};
        }
    }

    #
    # Time waitforcontinue
    #

    elsif (/(htrequestWrite: Waiting for the continue response)/) {
        readpidtid();
        if (defined $threads{$pid . $tid}) {
            $threads{$pid . $tid}->{'waitforcontinue'} = my_str2time($timestr);
        }
    }
    elsif (/(DETAI.*100 Continue)/) {
        readpidtid();
        if (defined $threads{$pid . $tid}) {
            $threads{$pid . $tid}->{'gotcontinue'} = my_str2time($timestr);
        }
    }

    #
    # Time handshake
    #

    elsif (/lib_stream: openStream: setting GSK_USER_DATA/) {
        readpidtid();
        if (defined $threads{$pid . $tid}) {
            $threads{$pid . $tid}->{'handshake_start'} = my_str2time($timestr);
        }
    }
    elsif (/Created a new stream; queue was empty, socket/) {
        readpidtid();
        if (defined $threads{$pid . $tid}) {
            $threads{$pid . $tid}->{'handshake_stop'} = my_str2time($timestr);
        }
    }

    #
    # Time body 
    #

    elsif (/htrequestWrite: Writing the request content, length (\d+)/) {
        readpidtid();
        if (defined $threads{$pid . $tid}) {
            $threads{$pid . $tid}->{'body_start'} = my_str2time($timestr);
            $threads{$pid . $tid}->{'body_len'} = $1;
        }
    }
    elsif (/cb_read_body: In the read body callback/) {
        readpidtid();
        if (defined $threads{$pid . $tid}) {
            $threads{$pid . $tid}->{'body_stop'} = my_str2time($timestr);
        }
    }
    #
    # Track conn failure, conn delay
    #

    elsif (/(transportStreamDequeue: Checking for existing stream from the queue)/) {
        readpidtid();
        if (defined $threads{$pid . $tid}) {
            $threads{$pid . $tid}->{'dq'} = my_str2time($timestr);
        }
    }
    elsif (/(.*Connection to.*ailed.*)/) { # non-block connect fail
        readpidtid();
        if (defined $threads{$pid . $tid}) {
            $threads{$pid . $tid}->{'miscerror'} = { time=>$timestr, line=>$ln , text=>$1};
        }
        if (defined $threads{$pid . $tid}->{'dq'}) { 
            $threads{$pid . $tid}->{'connfailure'} = my_str2time($timestr);
        }
    }
    elsif (/(.*all could be down*)/) { 
        readpidtid();
        if (defined $threads{$pid . $tid}) {
            $threads{$pid . $tid}->{'clusterdown'} = { time=>$timestr, line=>$ln , text=>$1};
        }
    }
    elsif (/(.*WSFO*)/) { 
        readpidtid();
        if (defined $threads{$pid . $tid}) {
            $threads{$pid . $tid}->{'WSFO'} = { time=>$timestr, line=>$ln , text=>$1};
        }
    }
    elsif (/(.*fired.*)/) { # connecttimeout or serveriotimeout
        readpidtid();
        if (defined $threads{$pid . $tid}) {
            $threads{$pid . $tid}->{'miscerror'} = { time=>$timestr, line=>$ln , text=>$1};
        }
    }
    elsif (/(.*Write failed.*)/) { # write failure [to server]
        readpidtid();
        if (defined $threads{$pid . $tid}) {
            $threads{$pid . $tid}->{'writeerror'} = { time=>$timestr, line=>$ln , text=>$1};
        }
    }
    elsif (/serverSetFailoverStatus: Marking (.+) down/) { 
        readpidtid();
        if (defined $threads{$pid . $tid}) { 
            if (!defined($threads{$pid . $tid}->{'markdowns'})) { 
                $threads{$pid . $tid}->{'markdowns'} = ();
            }
            push @{$threads{$pid . $tid}->{'markdowns'}}, { server=>$1, time=>$timestr, line=>$ln };
        }
    }

    elsif (/lib_htresponse: htresponseRead: Reading the response/) { 
        readpidtid();
        if (defined $threads{$pid . $tid}) { 
            $threads{$pid . $tid}->{'respcode_start'} = my_str2time($timestr);
            if (!defined $threads{$pid . $tid}->{'esipending'}) { 
                $threads{$pid . $tid}->{'read_response_start'} = my_str2time($timestr);
            }
            else { 
                my $len = scalar @{$threads{$pid . $tid}->{'esipending'}};
                if ($len > 0) { 
                    my @arr = @{$threads{$pid . $tid}->{'esipending'}};
                    $arr[$len - 1]->{'esi_start'} = my_str2time($timestr);
                }
            } 
        }
    }

    elsif (/getResponseFromCache: cache hit/) { 
        readpidtid();
        if (!defined($threads{$pid . $tid}->{'pastmainrequest'})) { 
    # The request from the client is found in the cache, vs a later ESI subrequest
            $threads{$pid . $tid}->{'read_response_end'} = my_str2time($timestr);
            $threads{$pid . $tid}->{'read_response_start'} = my_str2time($timestr);
            $threads{$pid . $tid}->{'status'} = 200;
        }
        else { 
            begin_esi_request($pid, $tid);
    # an ESI req served out of the cahce instead of seeing HTTP/1.1...
            if (defined $threads{$pid . $tid} && defined $threads{$pid . $tid}->{'esipending'}) {
                finish_esi_request($pid, $tid, 1); 
            }
        }
    }

    elsif (/getResponseFromCache: cache miss/) { 
        readpidtid();
        begin_esi_request($pid, $tid);
    } 
    elsif (/esiRulesGetCacheId: cache miss/) { 
        readpidtid();
        begin_esi_request($pid, $tid);
    } 

} # end while

if ($lastline =~ m/\[(.*?)(?:\.\d{5})?\] (\w+) (\w+)/) {
  $timestr = $1;
}


#*********************************************************************************************************************************
#Printing Bld Info
if ($bld1 eq "Not Reported") {
    print "===\nNo build version reported.\n\n";
} 
else {
    print "\nThere were $bldcnt build entries. \n";
    print "Last build version posted is $bld1 \n \n";
}
if ($webserver eq "Not Reported") {
    print "Webserver type not reported\n\n";
}else{
    print "Webserver is $webserver \n\n";
}

print "plugin-cfg.xml reloads (across all processes): $reloads\n\n";
#
print "===\nListing Unique Error Messages.\n";
foreach $r (@errorArray) {
    print "$r\n";
}
print "\n";

# disabled
if (0) { 
    print "===\nListing Session Set-Cookie Entries.\n";
    foreach $r (@sessionIDArray) {
        print "$r\n";
    }
    print "\n";
}
print "===\nListing STATS Entries.\n";
foreach $r (@statsArray) {
#    my $newReq = substr($r, index($r, "totalRequests ") + 14, (index($r, ".")-(index($r, "totalRequests ") + 14))) -  substr($r, index($r, "affinityRequests ") + 17, (index($r, "totalRequests")-(index($r, "affinityRequests "))));
#    my $subStatLine = substr($r, 0, (length($r) - 1));
#    my $statLine =  "$subStatLine newRequests  $newReq";
#    my $statLine =  "$subStatLine newRequests  $newReq";
    print "$r\n";
}


# every requst in response time order? Huh?
if (0) { 
    print "\n";
    foreach $r (sort { $$a{'delta'} <=> $$b{'delta'}} @requests) { 
        print fmt($r);
    }
}

print "\n===Interesting cookie/cacheRequests (experimental):\n";

foreach $r (@requests) { 
    if (defined $r->{'setcookies'} && !defined($r->{'cachecontrol'})) { 
        print "\n";
        print fmt($r);
        printf "\twhy: set-cookie ";
        print $r->{'setcookies'};
        printf " without cache-control " . $r->{'cachecontrol'}. "\n";
        printf "\tSplit trace:\n\t\t%s\n", sed_split($r);
    }
    elsif (defined $r->{'setcookies'} && !(defined($r->{'cachecontrolsetcookie'}) || defined($r->{'cachecontrolnocache'}))) { 
        print "\n";
        print fmt($r);
        print "\twhy: set-cookie " .  $r->{'setcookies'} . " without cache-control no-cache, cache-control no-cache=setcookie.  CC= '" . $r->{'cachecontrol'}. "' \n";
        printf "\tSplit trace:\n\t\t%s\n", sed_split($r);
    }
    elsif (defined $r->{'setcookies'} && defined($r->{'cachecontrolsetcookie'}) && defined($r->{'expires'})) { 
        print "\n";
        print fmt($r);
        print "\twhy: set-cookie ".  $r->{'setcookies'} .  " with cc: no-cache=setcookie but ALSO expires\n";
        printf "\tSplit trace:\n\t\t%s\n", sed_split($r);
    }
}

print "\n===Interesting Requests:\n";
my $count = 0;
foreach $r (sort { $$a{'delta'} <=> $$b{'delta'}} @requests) { 
    my $printed = 0;
    my @why = ();
    my $total_esi_seconds = 0;
    if (defined($r->{'esidone'}) && scalar @{$r->{'esidone'}} > 0) { 
        foreach (@{$r->{'esidone'}}) {
            $total_esi_seconds += $_->{'esi_end'} - $_->{'esi_start'}; 
        }
    } 
    if ($r->{'appserverdelaycontinue'} > 2 || $r->{'appserverdelaycontinue'} > .25 * $r->{'delta'}) { 
        push @why, sprintf "\twhy: 100-continue delay of $r->{'appserverdelaycontinue'} seconds \n";
        $printed = 1;
    }

    if ($r->{'appserverdelayconnect'} > 2 || $r->{'appserverdelayconnect'} > .25 * $r->{'delta'}) { 
        push @why, sprintf "\twhy: TCP connect delay of $r->{'appserverdelayconnect'} seconds delta is  $r->{'delta'} \n";
        $printed = 1;
    }
    if ($r->{'appserverdelayhandshake'} > 4 || $r->{'appserverdelayhandshake'} > .25 * $r->{'delta'}) { 
        push @why, sprintf "\twhy: TLS handshake delay of $r->{'appserverdelayhandshake'} seconds \n";
        $printed = 1;
    }
    if ($r->{'bodyfwddelay'} > 10 || $r->{'bodyfwddelay'} > .75 * $r->{'delta'}) { 
        push @why, sprintf "\twhy: Delay forwarding request body of $r->{'bodyfwddelay'} seconds \n";
        $printed = 1;
    }

    if ($r->{'respcodedelay'} > 5 || $r->{'respcodedelay'} > .75 * $r->{'delta'}) { 
        push @why, sprintf "\twhy: Delay waiting for status code of $r->{'respcodedelay'} seconds delta=$r->{'delta'}\n";
        $printed = 1;
    }

    if (defined $r->{'posterror'}) { 
        push @why, sprintf "\twhy: post error: '%s' at line %d\n", $r->{'posterror'}->{'code'}, $r->{'posterror'}->{'line'};
        $printed = 1;
    }

    if (defined $r->{'markdowns'}) { 
        push @why, "\twhy: markdowns\n";
        foreach (@{$r->{'markdowns'}}) {  
            push @why, sprintf "\twhy: Markdown of %s at line %d and time %s\n", $_->{'server'}, $_->{'line'}, $_->{'time'};
        }
        $printed = 1;
    }

    if (defined($r->{'miscerror'})) {
        push @why, sprintf "\twhy: misc error on line %d: '%s'\n", $r->{'miscerror'}->{'line'}, $r->{'miscerror'}->{'text'} ;
        $printed = 1;
    }
    if (defined($r->{'WSFO'})) {
        push @why, sprintf "\twhy: Failovers (\$WSFO\) on line %d: '%s'\n", $r->{'WSFO'}->{'line'}, $r->{'WSFO'}->{'text'} ;
        $printed = 1;
    }


    if (defined($r->{'writeerror'})) {
        push @why, sprintf "\twhy: write error (forwarding req body?) on line %d: '%s'\n", $r->{'writeerror'}->{'line'}, $r->{'writeerror'}->{'text'} ;
        $printed = 1;
    }
    if (defined($r->{'clusterdown'})) {
        push @why, sprintf "\twhy: cluster marked down on line %d: '%s'\n", $r->{'clusterdown'}->{'line'}, $r->{'clusterdown'}->{'text'} ;
        $printed = 1;
    }

    if (!$printed && ($r->{'delta'} >= 5)) {  # highlight slow requests
        if ($r->{'appserverdelay'} > (.75 * $r->{'delta'})) { 
            push @why, sprintf"\twhy: slow (WAS response generation or slow POST etc)\n";
        }
        else { 
            push @why, sprintf "\twhy: slow (wall time)\n";
        }
        $printed = 1;
    }

    if (!$printed && ($r->{'appserverdelay'} == -1)) {  # no response
        push @why, sprintf"\twhy: no response from appserver\n";
        $printed = 1;
    }
    my $wasted = $r->{'delta'} - $r->{'appserverdelay'} - $total_esi_seconds;

    if ($r->{'appserverdelay'} > 0 && 
            $r->{'delta'} > 2          &&
            $wasted > (.5 * $r->{'appserverdelay'})) { 
        push @why, "\twhy: less than half the wall time was due to appserver processing\n";
        $printed = 1;
    }

    if (!$printed && $r->{'status'} == 500) { 
        push @why, sprintf "\twhy: ISE from AppServer\n";
        $printed = 1;
    }

    if (!$printed && $opt_all) {
        push @why, sprintf "\twhy: debug switch -a passed\n";
        $printed = 1;
    }
    
   if ($printed) { 
        $count += 1;
        print "\n";
        print fmt($r);
        foreach (@why) {
            printf "$_";
        }
        printf "\tSplit trace:\n\t\t%s\n", sed_split($r);
   }

}

    print "\n===Unfinished Requests (experimental?):\n" if (scalar(keys %threads) > 0);

    my ($k, $v);
    while (($k, $v) = each(%threads)) { 
        my $delay = my_str2time($timestr) - $v->{'time'};
        print "Request didn't finish in this trace (which ended $delay seconds after the request began at line " . $v->{'begin'}  . 
            ") uri= " . $v->{'uri'} . "\n";
            my $r;
            $r->{'end_line'} = $ln;
            $r->{'begin_line'} = $v->{'begin'};
            $r->{'pidtid'} = $v->{'pidtid'};
            printf "\tSplit trace:\n\t\t%s\n", sed_split($r);
    }
close OVERWRITE;
sub sed_split() { 
    my ($r) = @_;
    return sprintf "sed -e '%s,%s!d' '%s' | grep '%s'\n",
           $r->{'begin_line'}, $r->{'end_line'}, $file , $r->{'pidtid'};
}

sub fmt() { 
    my ($r) = @_;
    my $total_esi_seconds = 0;
    my $result;

    if (defined($r->{'esidone'}) && scalar @{$r->{'esidone'}} > 0) { 
        foreach (@{$r->{'esidone'}}) {
            $total_esi_seconds += $_->{'esi_end'} - $_->{'esi_start'}; 
        }
    } 

    $result = sprintf "%.2fs (%.2fs) lines: %6d,%6d status=%d uri=%s end=%s\n", 
        $r->{'delta'}, 
        $r->{'appserverdelay'} + $total_esi_seconds, 
        $r->{'begin_line'},  $r->{'end_line'}, 
        $r->{'status'}, $r->{'uri'}, $r->{'end_time'} ;

    if (defined($r->{'esidone'}) && scalar @{$r->{'esidone'}} > 0) { 
        $result .= sprintf "\tesi subrequests = %d, total appserver ESI seconds=%d\n",
            scalar @{$r->{'esidone'}}, $total_esi_seconds;
    }
    return ($result);
}

sub finish_esi_request() { 
    my ($pid, $tid, $cached) = @_;
    my $len = scalar @{$threads{$pid . $tid}->{'esipending'}};
    if ($len > 0) { 
        my @arr = @{$threads{$pid . $tid}->{'esipending'}};
        $arr[$len - 1]->{'esi_end'} = my_str2time($timestr);
        my $hr = pop @arr;
        if (!defined $threads{$pid . $tid}->{'esidone'}) { 
            $threads{$pid . $tid}->{'esidone'} = ();
        }
        push @{$threads{$pid . $tid}->{'esidone'}}, $hr;
        if ($len == 1) { 
# we popped the last element
            undef $threads{$pid . $tid}->{'esipending'};
        }
    } 
}

sub begin_esi_request() { 
    my ($pid, $tid) = @_;
    if(defined  $threads{$pid . $tid}) { 
        if(defined $threads{$pid . $tid}->{'pastmainrequest'}) { 
            if (!defined  $threads{$pid . $tid}->{'esipending'}) { 
                $threads{$pid . $tid}->{'esipending'} = ();
            }  
            print OVERWRITE "new ESI req $_\n";
            push @{$threads{$pid . $tid}->{'esipending'}}, { uri => $1, esi_begin=>time2str($time), disp=>"unknown" };      
        }
        else {  # we don't want to process the main request as ESI, even though ESI handles it.
            print OVERWRITE "skipping new ESI req $_\n";
            $threads{$pid . $tid}->{'pastmainrequest'} = 1;
        }
    }
}
