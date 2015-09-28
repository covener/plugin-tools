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

# Parse log files recommended by 'mpmtats enhanced module timings' to see what
# % the WAS Plugin took for responses whose response time was > 1 second

# ecovener@us.ibm.com

print"plg+sm%\tplugin%\tmod_sm%\t logentry";
while(<>) { 
    if (/TRH=mod_was_ap22_http.c:(\d+)ms.*?(\d+)$/) { 
      my $plg = $1 * 1000;
      my $total = $2;
      my $sm = 0;

      if (/mod_sm22.cpp:(\d+)ms/) { 
        $sm = $1 * 1000;
      }
      if ($total > 1*1000*1000) { 
        my $percent =($plg/$total)*100 ;
        my $smpercent =($sm/$total)*100 ;
        printf "%03.2f%% %03.2f%%  %03.2f%% %s\n",  $percent + $smpercent, $percent, $smpercent, $_;
      }
    }
}


