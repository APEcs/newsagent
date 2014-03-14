#!/usr/bin/perl

use v5.12;
use lib qw(/var/www/webperl);
use lib qw(blocks);

use Newsagent::Importer::UoMMediaTeam;
use Data::Dumper;
use DateTime;

my $test = Newsagent::Importer::UoMMediaTeam -> new(minimal => 1);
my $lastrun = DateTime -> from_epoch(epoch => 0);

my $res = $test -> _fetch_updated_xml("http://newsadmin.manchester.ac.uk/xml/eps/computerscience/currentmonth.xml", $lastrun);
print "Result: ".Dumper($res)."\n";
