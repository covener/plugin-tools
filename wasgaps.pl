#!/usr/bin/perl

# Report gaps in SystemOut.log
# covener@gmail.com

use strict;
use HTTP::Date; # part of LWP
use Getopt::Std;
use Statistics::Descriptive;

my @entries = ();
my ($pid, $time, $begin);
my $file = $ARGV[0];
my $ln;
my $timestr;
my $seconds = 10;

my $prevtime = undef;
my $prevline = undef;

sub my_str2time {
   my $timestr = $_[0];
   my $rv = str2time($timestr); # 1/15/16 11:44:07:465 

   if ($timestr =~ /(.*):(\d{3})$/) {
       $rv = str2time($1);
       # add fractional seconds 
       $rv += $2/1000;
   }
   return $rv;
}


while(<>) { 
  $ln++;
  chomp();
  if ($ln % 200000 == 0) { 
    print STDERR "reading line $ln...\n";
  }

  # grab TS
  if (/\[(.*?) \w{3}\] (\w+)/) { 
    $timestr = $1;
    $pid = $2;
  }
  else { 
    next; 
  }

  # Get numeric time
  $time = my_str2time($timestr);

  if (!defined($prevtime)) { 
    $prevtime = $time;
    $prevline = $_;
    next;
  }

  #print "time=$time, prevtime=$prevtime\n";
  if (($time - $prevtime) > $seconds) { 
     push(@entries, { ln=> $ln,  delta => ($time - $prevtime), txt=>$_,  prevtxt=>$prevline }) ;
  }
  $prevtime = $time;
  $prevline = $_;
}

foreach my $v (sort { $$a{'delta'} <=> $$b{'delta'}} @entries) {
   printf "\n\n%.3fs ln=%d\n\told=%s\n\tnew=%s\n",  $v->{'delta'}, $v->{'ln'}-1, $v->{'prevtxt'},  $v->{'txt'};
}

