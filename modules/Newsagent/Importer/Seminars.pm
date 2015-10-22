# @file
# This file contains the implementation of the Seminar importer class
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
#
#
package Newsagent::Importer::Seminars;

use strict;
use experimental 'smartmatch';
use base qw(Newsagent::Importer); # This class extends the Newsagent block class
use v5.12;
use Digest;
use DateTime;
use DateTime::Format::Strptime;
use XML::LibXML;
use Webperl::Utils qw(path_join);
use Data::Dumper;

# ============================================================================
#  Constructor

# No explicit constructor (uses Importer class constructor) but this must be
# created with 'importer_id' set appropriately.

# ============================================================================
#  Interface functions

## @method $ import_articles()
# Run the import process for this module. This will fetch the articles from the
# source, determine whether any need to be added to the system, and perform any
# additions or updates as needed.
#
# @return true on success (note that 'nothing imported' is considered success
#         if there is nothing to import!) or undef on error.
sub import_articles {
    my $self = shift;

    $self -> clear_error();

    my $seminars = $self -> _fetch_seminars($self -> {"args"} -> {"list"})
        or return undef;

    my $data = "";
    foreach my $seminar (@{$seminars}) {
        my ($semelem) = $seminar -> findnodes("seminar");

        # check for deletions
        my $cancelled = $semelem -> getAttribute("cancelled");
        if($cancelled) {
            $data .= "Got cancelled seminar\n";
#            $self -> _cancel_seminar($seminar);

        # Not deleted; must be a new or updated
        } else {
            my ($id) = $semelem -> findnodes("id");

            my $oldmeta = $self -> find_by_sourceid($id -> textContent);
            return undef if(!defined($oldmeta));

            # Old metadata is available, so this is an update
            if($oldmeta) {
                $data .= "Got updated seminar\n";
                #

            # No metadata set; must be a new seminar
            } else {
                $data .= "Got new seminar\n";

            }
        }

        $data .= $seminar."\n";
    }

    $data =~ s/</&lt;/g;
    $data =~ s/>/&gt;/g;

    return $self -> self_error("<pre>Data: $data</pre>");
    return 1;
}



# ============================================================================
#  Internal implementation - article interaction


# ============================================================================
#  Internal implementation - seminar fetch/parse/process

## @fn private $ _sortfn_by_date(void)
# A function used by sort() to order seminar elements based on the date and
# time of the seminar. This allows seminars to be sorted into reverse
# chronological order (future seminars first) using the timestamp set in
# the element. Note this this function *will not work* unless the list has
# been processed through _build_datestamps() first - the timestamp element
# this looks for does not exist in the 'standard' seminar element! If
# two seminars are set for the same day and time, this will sort them by
# their IDs.
#
# @param a (implicit scalar) A reference to an XML::LibXML::Element for a seminar.
# @param b (implicit scalar) A reference to an XML::LibXML::Element for a seminar.
# @return An integer indicating the relation between a and b.
sub _sortfn_by_date {
    my $adate = $a -> getAttribute("timestamp");
    my $bdate = $b -> getAttribute("timestamp");
    my ($aid) = $a -> findnodes("id");
    my ($bid) = $b -> findnodes("id");

    # If the dates match, use IDs to distinguish
    if($adate == $bdate) {
        return $bid -> textContent <=> $aid -> textContent;
    } else {
        return $bdate <=> $adate;
    }
}


## @method private $ _fetch_seminars($url)
# This will fetch the latest XML file and check whether any seminars need to be
# processed.
#
# @param url The location of the XML file to fetch and process.
# @return A reference to a an array of seminars that either don't exist in the
#         database, or have been updated since the article was created.
sub _fetch_seminars {
    my $self = shift;
    my $url  = shift;

    $self -> clear_error();

    my $dom = eval { XML::LibXML -> load_xml(location => $url); };
    return $self -> self_error("Unable to process seminar master XML: $@")
        if($@);

    # Go through the seminars throwing away ones that have already happened.
    $self -> _build_datestamps($dom) or return undef;
    my $pending = $self -> _build_pending($dom) or return undef;

    # Now go through the pending ones, looking to see which ones need processing
    my @toprocess = ();
    foreach my $seminar (@{$pending}) {
        my ($id) = $seminar -> findnodes("id");
        return $self -> self_error("Unable to find ID for seminar: ".$seminar)
            unless($id);

        # Pull in the full content for the seminar
        my $fulldata = $self -> _fetch_seminar($id -> textContent)
            or return undef;

        # Get the hash
        my ($semelem) = $fulldata -> findnodes("seminar");
        my $hash = $semelem -> getAttribute("hash");

        # Does this seminar have an entry in the meta table..?
        my $metainfo = $self -> find_by_sourceid($id);

        # If it doesn't or it doesn't match, it needs processing.
        push(@toprocess, $fulldata)
            if(!$metainfo || $metainfo -> {"data"} ne $hash);
    }

    return \@toprocess;
}


## @method private $ _fetch_seminar($sid)
# Given a seminar ID, attempt to fetch the seminar with that ID. This will fetch
# the seminar data, and store the MD5 hash of the seminar data in the parsed DOM.
#
# @param sid The seminar ID.
# @return A reference to a XML::LibXML::Document containing the parsed
#         seminar DOM.
sub _fetch_seminar {
    my $self = shift;
    my $sid  = shift;

    $self -> clear_error();

    my $url = path_join($self -> {"args"} -> {"base"}, "$sid.xml");
    my $dom = eval { XML::LibXML -> load_xml(location => $url); };
    return $self -> self_error("Unable to process seminar XML, id '$sid': $@")
        if($@);

    # Calculate the hash of the seminar data
    my $digest = Digest -> new("MD5");
    $digest -> add($dom -> toString());

    # Store the hash in the seminar element, to make lookup easier
    my ($seminar) = $dom -> findnodes("seminar");
    $seminar -> setAttribute("hash", $digest -> hexdigest());

    return $dom;
}


## @method private $ _build_datestamps($dom)
# Ensure that all the seminars in the specified DOM have a unix timestamp
# set for them in addition to the date and time provided by default.
#
# @param dom A reference to an XML::LibXML::Document containing the seminar DOM.
# @return true on success, undef on error
sub _build_datestamps {
    my $self = shift;
    my $dom  = shift;

    $self -> clear_error();

    # In theory, this should make it easier to fix parsing if the seminar xml changes...
    my $parser = DateTime::Format::Strptime -> new(pattern   => '%d-%B-%y %H:%M',
                                                   locale    => "en_GB",
                                                   time_zone => 'Europe/London',
                                                   on_error  => 'croak');

    # Go through each seminar adding a unix timestamp
    foreach my $seminar ($dom -> findnodes("seminars/seminar")) {
        my ($date) = $seminar -> findnodes("date");
        my ($time) = $seminar -> findnodes("time");
        my ($id)   = $seminar -> findnodes("id");

        # The time field is not entirely consistent, this should help to get it
        # into a HH:MM format we can work with.
        $time = $time -> textContent;
        $time =~ s/^(\d\d)pm$/$1:00/;
        $time =~ s/^(\d\d)(\d\d)$/$1:$2/;
        $time =~ s/^(\d\d)\.(\d\d)$/$1:$2/;

        # Try the parse; it may not work if the date or time are incorrect formats
        my $datetime = eval { $parser -> parse_datetime($date -> textContent." ".$time); };
        return $self -> self_error("Unable to create timestamp for seminar ".$id -> textContent.": $@")
            if($@);

        # Store the timestamp as seconds since the epoch it UTC.
        $seminar -> setAttribute('timestamp', $datetime -> epoch());
    }

    return 1;
}


## @method private $ _build_pending($dom)
# Generate a list of seminars FROM THE FUTURE. This looks a the list of seminars
# in the specified DOM and pulls out the ones that have not yet happened - seminars
# that have already happened are ignored.
#
# @param dom A reference to an XML::LibXML::Document containing the seminar DOM.
# @return A reference to an array of XML::LibXML::Elements, one per seminar. This
#         list may be empty if there are no pending seminars.
sub _build_pending {
    my $self = shift;
    my $dom  = shift;
    my $now  = time();

    my @pending = ();
    foreach my $item (sort _sortfn_by_date $dom -> findnodes("seminars/seminar")) {
        my ($stamp) = $item -> findnodes("timestamp");

        # Stop if the item's timestamp is before the current time (seminar has already
        # happened, so there's no point in maintaining anything for it)
        last if($stamp -> textContent <= $now);

        # Get here and the seminar is in the future, add the XML::LibXML::Element to
        # the pending list.
        push(@pending, $item);
    }

    return \@pending;
}

1;