#!/usr/bin/perl

# Approximate SSL handshake times given WAS SSLChannel trace.

use strict;
use HTTP::Date; # part of LWP

my @finished   = ();
my %pending = ();

my $state = "stackstart";
my $file = "???";
my $line = 0;

# Convert WAS timestampes for short deltas.
sub my_str2time {
   my $timestr = $_[0];
   my $rv = str2time($timestr);
   if ($timestr =~ /(\d+:\d+:\d+):(\d\d\d )/) {
       $rv = str2time("Wed, 09 Feb 1994 $1");
       $rv += $2/1000;
   }
   return $rv;
}


while(<>) {
    $file= $ARGV;
    if ($_ =~ m/\[(.*)\] ([0-9a-f]+) SSLUtils.*handleHandshake.*Entry/) { 
#         print "$_\n";
         my $t = my_str2time($1);
         if (defined($pending{$2})) { 
             die ("already saw $_");
         }
         my $v = { start=> $t, startpretty=>$1, pidtid=>$2, begin_line=>$line};
         $pending{$2} = $v;
    } 
    elsif ($_ =~ m/\[(.*)\] ([0-9a-f]+) SSLUtils.*handleHandshake Exit/) { 
#         print "$_\n";
         my $t = my_str2time($1);
         if (!defined($pending{$2})) { 
            print STDERR "handshake didn't start $_\n";
            $line++; 
            next;
         }
         my $start = $pending{$2}->{'start'};
         my $v = { start=>$start, startpretty=>$pending{$2}->{'startpretty'}, pidtid=>$2, stop=>$t, delta=> ($t - $start), 
                   end_line=>$line, begin_line=>$pending{$2}->{'begin_line'} };
         push @finished, $v;
         $pending{$2} = undef;
    } 
 $line++;
}
 
my $r;
foreach $r (@finished) {
  my $delta = sprintf "%.4fs", $r->{'delta'} ;
  my $sed = sed_split($r);
  print "$delta, $r->{'startpretty'}, $r->{'pidtid'}, \"$sed\"\n";
}

sub sed_split() {
    my ($r) = @_;
    return sprintf "sed -e '%s,%s!d' '%s' | grep '%s'",
           $r->{'begin_line'}, $r->{'end_line'}, $file , $r->{'pidtid'};
}



