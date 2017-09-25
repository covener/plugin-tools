#!/usr/bin/perl

# summarize_javacore.pl /path/to/javacore | sort | uniq -c | sort -n

my $state = "stackstart";

while(<>) {
  if ($state eq "stackstart") { 
    if ($_ =~ m/3XMTHREADINFO3.*Java/) { 
        $state = "feed";
        next;
    }
  }
  elsif ($state eq "feed") { 
    if ($_ !~ m/[456]XESTACKTRACE/) { 
        $state = "print";
        next;
    }
    chomp();
    if (m/^.* at (.+?)\(/) { 
        my $fn = $1;
        $fn =~ s@^java/.*?([^/]+)$@\1@g;
        $fn =~ s@sun/misc/(.+)@\1@g;
        $fn =~ s@concurrent/locks/(.+)@\1@g;
        $fn =~ s@concurrent/(.+)@\1@g;
        if ($stack eq "") { 
            $stack = "$fn";
        }
        else { 
            $stack = "$stack<$fn";
        }
        next;
    }
    elsif($_ =~ m/5XESTACKTRACE/) { 
       # lock held
       next;
    }
    die($_);
  }
  elsif ($state eq "print") { 
    print $stack . "\n\n";
    $stack = "";
    $state = "stackstart";
  }
  else { 
    die ("what is state $state");
  }
}
  
