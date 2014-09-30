#!/usr/bin/perl
# Parse Java Proxy logs and look for mem2mm shennanigans

use strict;

my ($pid, $tid, $time, $timestr, $ver, $table);
my %threads = ();
my %servers = ();
my %dates = ();
my @chrono;
my $ln;
my $file = $ARGV[0];

sub readpidtid() {
  if (m/\[.*?(\d+:\d+:\d+:\d+).*?\] (\w+)/) {
    $timestr = $1;
    $tid = $2;
  }
}

sub sed_split {
  my ($data) = @_;
  return sprintf "sed -e '%s,%s!d' '%s' | grep '%s'\n", $data->{'line'}, $data->{'line_end'}, $file , $data->{'tid'};
}

while(<>) {
  $ln++;
  if (/\[null\]/) { 
      next;
  }
  # These cases are in the order the messages appear
  if (/Finishing request to target asynch.*target=(\S*)/) { 
      readpidtid();
      $threads{$tid} = { tid=>$tid, name=>$1, line=>$ln};
  }
  if (/Adding header \[Date\] with value \[(.*)\]$/) { 
      readpidtid();
      my $server = $threads{$tid}->{'name'};
      my $date = $1;
      if ($date =~ m/(\d+:\d+:\d+)/) { 
        $dates{$tid} = $1;
      }
  }
  if (/getHeaderAsString.*WSPT \[(.*)\]$/) { 
      readpidtid();
      my $server = $threads{$tid}->{'name'};
      $threads{$tid}->{'table'} = $1;
  }
  if (/getHeaderAsString.*_WS_HAPRT_WLMVERSION \[(.*)\]$/) { 
      readpidtid();
      my $server = $threads{$tid}->{'name'};
      my $line1 = $threads{$tid}->{'line'};
      my $table =  $threads{$tid}->{'table'};
      push @{$servers{$server}->{'data'}}, { tid=>$tid, time=>$timestr , table=>$table, version=>$1, line=>$line1, line_end=>$ln, http_date=>$dates{$tid} };
      push @chrono,  "$timestr\n\t$server\n\tWSPT=$table\n\tVER=$1";
  }
}
 
print "By Server\n\n"; 
my ($k, $v);
while (($k, $v) = each(%servers)) {
  print "$k\n\n";
  my $prevtable;
  foreach (@{$v->{'data'}}) {
    my @trace_time = split, /:/, $_->{'time'};
    my @http_time = split, /:/, $_->{'http_date'};
    my $delay_seconds = $trace_time[2] - $http_time[2];
    $delay_seconds = 60*($trace_time[1] - $http_time[1]);
    print "\t $_->{'line'}: $_->{'time'} delay=$delay_seconds VER=$_->{'version'} WSPT=$_->{'table'} \n";
    print "\t\t" .  sed_split($_) . "\n";
    if (defined($prevtable) && length($prevtable) > length($_->{'table'})) { 
      print "\t ^^^ WHY DID THIS SHRINK " .  sed_split($_) . "\n";
    } 
    $prevtable = $_->{'table'};
  }
}

print "By time\n\n"; 
foreach(@chrono) { 
  print "$_\n";
}
