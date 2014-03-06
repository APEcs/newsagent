# @file
# This file contains the implementation of the Media Team importer class
#
# @author  Chris Page &lt;chris@starforge.co.uk&gt;
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

## @class
# This class allows the parsing and import of news posts released by the
# university of manchester media team. This fetches and processes the
# XML containing the news stories published by the media team.
#
#package Newsagent::Importer::UoMMEdiaTeam;

use strict;
#use base qw(Newsagent); # This class extends the Newsagent block class
use v5.12;
use DateTime;
use LWP::UserAgent;
use XML::Simple;
use Data::Dumper;




# ============================================================================
#  Intrnal implementation-specifics

## @method private $ _fetch_updated_xml($url, $lastupdate)
# This will fetch the latest XML file and check whether it needs to be processed.
#
# @param url        The location of the XML file to fetch and process.
# @param lastupdate A DateTime object describing the time the xml was last checked.
# @return A reference to a hash containing updated/new stories.
sub _fetch_updated_xml {
#    my $self       = shift;
    my $url        = shift;
    my $lastupdate = shift;

#    $self -> clear_error();

    my $ua = LWP::UserAgent -> new();
    my $result = $ua -> get($url);

    # Bail if the xml file can not be read
#    return $self -> self_error("Unable to fetch XML file at $url: ".$result -> status_line)
    die "Unable to fetch XML file at $url: ".$result -> status_line."\n"
        unless($result -> is_success);

    # Fix up the hilariously broken content of the XML file. Seriously, why does it
    # mix the xml of the syndication format with the HTML content?!
    my $content = $result -> content();

    # Force the headline, strapline, and body to be properly cdata-wrapped
    foreach my $tag ("headline", "strapline", "mainbody") {
        $content =~ s|<$tag>\s*|<$tag><![CDATA[|gs;
        $content =~ s|\s*</tag>|]]></$tag>|gs;
    }

    print "Content:\n$content";
}


_fetch_updated_xml("http://newsadmin.manchester.ac.uk/xml/eps/computerscience/currentmonth.xml", 0);
