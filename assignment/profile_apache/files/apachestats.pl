#!/usr/bin/perl
#
#ApacheStats.pl
#
#Date: 17/08/2019
#Autho: Santosh Chakkilam
#Version: 1.2
#This script collects logs and writes them to a file in /data/webstats/. Current implementation has improved. I think.....
#
# Modified 24/5/19 by Adrian: move the tmp file to /var/tmp as the root partition can fill up
#
use strict;
use warnings;

use Switch;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError) ;
use DateTime;

######Setup time
my $logdir = "/var/log/httpd";
my $file = `ls -t $logdir/access_log*.gz | head -1`;
chomp($file);
my $tothit = 0;

#####Setup Variables and objects######
my $outfile = "/data/webstats/apache_stats";
my $tmpfile = "/var/tmp/astmp";
gunzip $file => $tmpfile or die "gunzip failed: $GunzipError\n";

#####Setup Hash of hashes#####
my %mash;

#####Setup date, properly!#####
my @dat = split(/\W/,$file);
my $datlog = $dat[5]; 
my $dt = DateTime->new(
	year    => substr($datlog,0,4),
	month   => substr($datlog,4,2),
	day	=> substr($datlog,6,2),
);
$datlog = $dt->subtract (days => 1);
$datlog = $dt->ymd("");

#####Open file in read only mode and scrape it to get redirections######
open(FILE, $tmpfile) or die "Can't open/create tmp uncompressed file for writing.";
my @rout = <FILE>;
close(FILE);

######Go through each line and use regex to pull stats into a hash
foreach my $line (@rout){
my $count;
	
	switch ($line){
		case m/ to_zope / { $count=$mash{"zope"};$count++;$mash{"zope"}=$count; }
		case m/ to_aix / { $count=$mash{"aix"};$count++;$mash{"aix"}=$count; }
		case m/ skip / { $count=$mash{"skip"};$count++;$mash{"skip"}=$count; }
	}
	
	switch ($line) {
                case m/"\s+2\d{2}\s+/ { $count=$mash{"2xx"};$count++;$mash{"2xx"}=$count; }
                case m/"\s+3\d{2}\s+/ { $count=$mash{"3xx"};$count++;$mash{"3xx"}=$count; }
                case m/"\s+4\d{2}\s+/ { $count=$mash{"4xx"};$count++;$mash{"4xx"}=$count; }
                case m/"\s+5\d{2}\s+/ { $count=$mash{"5xx"};$count++;$mash{"5xx"}=$count; }
        }

$tothit++;
}

######Setup the output text######
my $instr = $datlog." ".sprintf("%8d", $mash{"2xx"})." ".sprintf("%8d", $mash{"3xx"})." ".sprintf("%8d", $mash{"4xx"})." ".sprintf("%8d", $mash{"5xx"})." ".sprintf("%8d", $mash{"zope"})." ".sprintf("%8d", $mash{"aix"})." ".sprintf("%8d", $mash{"skip"})." ".sprintf("%8d", $tothit)."\n";
my $headstr = sprintf("%8s", "Date")." ".sprintf("%8s", "2xx")." ".sprintf("%8s", "3xx")." ".sprintf("%8s", "4xx")." ".sprintf("%8s", "5xx")." ".sprintf("%8s", "to_zope")." ".sprintf("%8s", "to_aix")." ".sprintf("%8s", "skip")." ".sprintf("%8s", "Total\n");

######Write the data to the file and close it#####
open(FILE, ">>$outfile") or die "Can't open/create logfile for writing.";
if ( -s $outfile < 1 ){ print FILE $headstr; }
print FILE $instr;
close(FILE);

unlink($tmpfile) or die "File deletion failed";
