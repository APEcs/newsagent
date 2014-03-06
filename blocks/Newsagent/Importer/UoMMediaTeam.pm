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
package Newsagent::Importer::UoMMediaTeam;

use strict;
#use base qw(Newsagent); # This class extends the Newsagent block class
use base qw(Webperl::SystemModule);
use v5.12;
use DateTime;
use LWP::UserAgent;
use XML::Simple;
use Data::Dumper;


# ============================================================================
#  Internal implementation-specifics

## @method private $ _parse_rfc822_datestring($datestr)
# Parse the specified date string into a new DateTime object.
#
# @param datestr The RFC-822 (section 5) date to parse.
# @return A new DateTime object.
sub _parse_rfc822_datestring {
    my $self    = shift;
    my $datestr = shift;
    my $monmap  = { "Jan" => 1, "Feb" => 2, "Mar" => 3, "Apr" => 4, "May" => 5, "Jun" => 6, "Jul" => 7, "Aug" => 8, "Sep" => 9, "Oct" => 10, "Nov" => 11, "Dec" => 12 };

    $self -> clear_error();

    my ($day, $month, $year, $hour, $minute, $second, $tz) = $datestr =~ /^(?:\w+, )?(\d{2}) (\w+) (\d{4})(?:[T ]?(\d{2}):(\d{2}):(\d{2}) ([-+]\d{4}))?$/;

    # This should never actually happen - _parse_datestring() should never be able to call
    # this function if any of these values are bad - but check in case they are zeros.
    return $self -> self_error("Illegal date format '$datestr'")
        if(!$day || !$month || !$year);

    # Convert the month
    $month = $monmap -> {$month};
    return $self -> self_error("Illegal date format '$datestr': unknown month specified")
        if(!$month);

    return DateTime -> new(year      => $year,
                           month     => $month,
                           day       => $day,
                           hour      => $hour || 0,
                           minute    => $minute || 0,
                           second    => $second || 0,
                           time_zone => $tz || "UTC");
}


## @method private _parse_datestring($datestr)
# Identify the format used in the specified date string, and convert it to a
# DateTime object.
#
# @param datestr The date string to parse.
# @return A DateTime object on success, undef on error.
sub _parse_datestring {
    my $self    = shift;
    my $datestr = shift;

    given($datestr) {
        when(/^(?:\w+, )?(\d{2}) (\w+) (\d{4})(?:[T ]?(\d{2}):(\d{2}):(\d{2}) ([-+]\d{4}))?$/) {
            return $self -> _parse_rfc822_datestring($datestr);
        }
        default {
            return $self -> self_error("Unknown datetime format '$datestr'");
        }
    }
}


## @method private $ _fetch_updated_xml($url, $lastupdate)
# This will fetch the latest XML file and check whether it needs to be processed.
#
# @param url        The location of the XML file to fetch and process.
# @param lastupdate A DateTime object describing the time the xml was last checked.
# @return A reference to a hash containing updated/new stories.
sub _fetch_updated_xml {
    my $self       = shift;
    my $url        = shift;
    my $lastupdate = shift;

    $self -> clear_error();

    my $ua = LWP::UserAgent -> new();
    my $result = $ua -> get($url);

    # Bail if the xml file can not be read
    return $self -> self_error("Unable to fetch XML file at $url: ".$result -> status_line)
        unless($result -> is_success);

    # Fix up the hilariously broken content of the XML file. Seriously, why does it
    # mix the xml of the syndication format with the HTML content?!
    my $content = $result -> content();

    # Force the headline, strapline, and body to be properly cdata-wrapped
    foreach my $tag ("headline", "strapline", "mainbody") {
        $content =~ s|<$tag>\s*|<$tag><![CDATA[|gs;
        $content =~ s|\s*</$tag>|]]></$tag>|gs;
    }

    my $tree = eval { XMLin($content); };
    die "XML parsing $content\nError: $@\n"
        if($@);

    my @items = ();
    foreach my $item (@{$tree -> {"newsitem"}}) {
        $item -> {"datePub"} = $self -> _parse_datestring($item -> {"datePub"});

        push(@items, $item)
            if($item -> {"datePub"} > $lastupdate);
    }

    return \@items;
}

1;
