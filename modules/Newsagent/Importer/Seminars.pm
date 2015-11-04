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
# Import seminar information from Iain's seminar system. This reads the XML
# files written to teh school website by Iain, and processes them into
# newsagent articles with multiple notifications.
#
# This requires the following variables be set in the args field in the
# class' entry in the import_sources table:
#
# list=Full URL of the seminars_all.xml file;
# base=URL of the directory containing the XML files;
# feed=Comma separated list of feed IDs to publish in;
# prefix_id=The Id of the email prefix to use in notification emails;
# recipient_id=The ID of the recipient entry in the recipient_methods table;
# user_id=The ID of the user creating the articles;

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

## @cmethod $ new(%args)
# Overloaded constructor for the seminar importer facility.
#
# @param args A hash of values to initialise the object with. See the Block docs
#             for more information.
# @return A reference to a new Newsagent::Importer::Seminars object on success, undef on error.
sub new {
    my $invocant = shift;
    my $class    = ref($invocant) || $invocant;
    my $self     = $class -> SUPER::new(@_)
        or return undef;

    $self -> {"parser"} = DateTime::Format::Strptime -> new(pattern   => '%d-%B-%y %H:%M',
                                                            locale    => "en_GB",
                                                            time_zone => 'Europe/London',
                                                            on_error  => 'croak');

    return $self;
}


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

    foreach my $seminar (@{$seminars}) {
        my ($semelem) = $seminar -> findnodes("seminar");
        my ($id)      = $semelem -> findnodes("id");

        # check for deletions
        my $cancelled = $semelem -> getAttribute("cancelled");
        if($cancelled) {
            $self -> log("importer:seminars:debug", "Got cancelled seminar with ID ".$id -> textContent);
            $self -> _cancel_seminar($semelem)
                or return undef;

        # Not deleted; must be a new or updated
        } else {
            my $oldmeta = $self -> find_by_sourceid($id -> textContent);
            return undef if(!defined($oldmeta));

            # Old metadata is available, so this is an update
            if($oldmeta) {
                $self -> log("importer:seminars:debug", "Got updated seminar with ID ".$id -> textContent);
                $self -> _update_seminar($semelem, $oldmeta)
                    or return undef;

            # No metadata set; must be a new seminar
            } else {
                $self -> log("importer:seminars:debug", "Got new seminar with ID ".$id -> textContent);
                $self -> _create_seminar($semelem)
                    or return undef;
            }
        }
    }

    return 1;
}


# ============================================================================
#  Internal implementation - article interaction


## @method private $ _seminar_to_article($seminar)
# Given a seminar element, generate the data to go into a Newsagent article
# for the seminar.
#
# @param semelem A reference to an XML::LibXML::Element containing the seminar
#                element (and its children) of the seminar to build an article
#                for.
# @return A reference to a hash containing the article data.
sub _seminar_to_article {
    my $self    = shift;
    my $semelem = shift;

    # Pull the data for the parts of the seminar we are interested in
    my $datestamp   = $semelem -> getAttribute('timestamp');
    my ($title)     = $semelem -> findnodes('seminarTitle');
    my ($location)  = $semelem -> findnodes('room');
    my ($speaker)   = $semelem -> findnodes('seminarSpeaker/speakerName');
    my ($honorific) = $semelem -> findnodes('seminarSpeaker/speakerTitle');
    my ($institute) = $semelem -> findnodes('seminarSpeaker/speakerInstitute');
    my ($abstract)  = $semelem -> findnodes('seminarAbstract');

    # Build the text components we need to put into the article
    my $summary = $self -> {"template"} -> load_template("importer/seminars/summary.tem", { "***title***"     => $title ? $title -> textContent() : "{L_IMPORT_SEMINAR_UNKNOWN}",
                                                                                            "***date***"      => $self -> {"template"} -> format_time($datestamp),
                                                                                            "***location***"  => $location ? $location -> textContent() : "{L_IMPORT_SEMINAR_UNKNOWN}",
                                                                                            "***honorific***" => $honorific ? $honorific -> textContent() : "",
                                                                                            "***speaker***"   => $speaker ? $speaker -> textContent() : "{L_IMPORT_SEMINAR_UNKNOWN}",
                                                                                            "***intitute***"  => $institute ? $institute -> textContent() : "{L_IMPORT_SEMINAR_UNKNOWN}",
                                                                                            "***host***"      => $host ? $host -> textContent(): "{L_IMPORT_SEMINAR_UNKNOWN}" });
    my $article = $self -> {"template"} -> load_template("importer/seminars/article.tem", { "***article***"   => $abstract ? $abstract -> textContent() : "{L_IMPORT_SEMINAR_UNKNOWN}" });

    # And do some date wrangling
    my $event_time   = DateTime -> from_epoch(epoch => $datestamp);
    my $release_time = $event_time -> clone() -> subtract(days => 7);
    my @reminder     = ( $release_time -> epoch(),
                         $event_time -> clone() -> subtract(days  => 2) -> epoch(),
                         $event_time -> clone() -> subtract(hours => 6) -> epoch()
                       );

    my @feeds = split(/,/, $self -> {"args"} -> {"feed"});

    # Build the article hash ready to pass to the add_article
    return { "levels"       => { 'home' => 0, 'leader' => 1, 'group' => 1 },
             "feeds"        => \@feeds,
             "release_mode" => 'timed',
             "release_time" => $release_time -> epoch(),
             "relmode"      => 0,
             "full_summary" => 3,
             "minor_edit"   => 0,
             "sticky"       => 0,
             "title"        => $title ? $title -> textContent() : "{L_IMPORT_SEMINAR_UNKNOWN}",
             "summary"      => $summary,
             "article"      => $article,
             "reminders"    => \@reminder,
             "methods"      => { "Email" => { "prefix_id"  => $self -> {"args"} -> {"prefix_id"},
                                              "cc"         => '', # No additional CC recipients
                                              "bcc"        => '', # No additional BCC recipients
                                              "bcc_sender" => 1,  # Include the sender in the BCC list
                                              "reply_to"   => '',  # this should default to the author ID
                                 },
                               },
             "used_methods" => { 'Email' => [ $self -> {"args"} -> {"recipient_id"} ] }
    };
}


## @method private $ _cancel_seminar($seminar)
# Mark the Newsagent article associated with the specified seminar as deleted, and
# cancel any notifications associated with it.
#
# @param seminar A reference to an XML::LibXML::Element containing the seminar
#                element (and its children) of the seminar to cancel.
# @return true on success, undef on error. Note that cancelling a seminar that
#         does not exist as Newsagent article is not considered an error.
sub _cancel_seminar {
    my $self    = shift;
    my $seminar = shift;
    my ($id)    = $seminar -> findnodes("id");
    my $hash    = $seminar -> getAttribute("hash");

    # Given the seminar ID, fetch the metainfo....
    my $metainfo = $self -> find_by_sourceid($id -> textContent);

    # We have metainfo, so now we know what the article ID is. It can now be cancelled.
    # Just to be on the safe-side, make sure the article ID is non-zero, as it's possible
    # this function may have been called as a result of a hash change on a seminar that
    # never made it into the system to begin with, or one we've already cancelled.
    if($metainfo && $metainfo -> {"article_id"}) {
        $self -> {"article"} -> set_article_status($metainfo -> {"article_id"}, "deleted")
            or return $self -> self_error("Unable to cancel seminar: ".$self -> {"article"} -> errstr());

        $self -> {"queue"} -> cancel_notifications($metainfo -> {"article_id"})
            or return $self -> self_error("Unable to cancel seminar notifications: ".$self -> {"queue"} -> errstr());
    }

    # Always zero the article ID - helps to prevent repeat cancellations of seminar
    # articles, and ensures the ID is defined for the import metainfo.
    $metainfo -> {"article_id"} = 0;

    $self -> _set_import_meta($metainfo -> {"article_id"}, $id -> textContent, $hash)
        or return undef;

    return 1;
}


## @method private $ _create_seminar($seminar)
# Given a seminar element, create a newsagent article for it and queue up
# notifications to send as needed.
#
# @param seminar A reference to an XML::LibXML::Element containing the seminar
#                element (and its children) of the seminar to cancel.
# @return true on success, undef on error.
sub _create_seminar {
    my $self    = shift;
    my $seminar = shift;
    my ($id)    = $seminar -> findnodes("id");
    my $hash    = $seminar -> getAttribute("hash");

    $self -> clear_error();

    my $article = $self -> _seminar_to_article($seminar);
    my $aid = $self -> {"article"} -> add_article($article, $userid, undef, 0)
        or return $self -> self_error("Unable to add seminar article: ".$sefl -> {"article"} -> errstr());

    $self -> log("import:seminar:article", "Added article new $aid with has $hash");

    $self -> _set_import_meta($aid, $id, $hash)
        or return undef;

    # Now queue notifications
    my $now = time();
    foreach my $send_after (@{$article -> {"reminders"}}) {
        next if($send_after < $now); # skip notifications that should have been sent in the past.

        $self -> {"queue"} -> queue_notifications($aid, $article, $self -> {"args"} -> {"user_id"}, 0, $article -> {"used_methods"}, "timed", $send_after)
            or return $self -> self_error("Reminder queueing failed: ".$self -> {"queue"} -> errstr());

        $self -> log("import:seminar:article", "Queued reminder for seminar $id (article $aid) at $send_after");
    }

    return 1;
}


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

    # and give it a useful seminar datestamp
    $self -> _build_timestamp($seminar)
        or return undef;

    return $dom;
}


## @method private $ _build_timestamp($seminar)
# Given a seminar, attempt to build a unix timestamp for the specified seminar
# date and time. This parses the seminar time and day into a timestamp, relying
# on the TZ and pattern settings in the parser to do the job. On success,
# this will set the timestamp attribute of the supplied seminar to the
# UNIX timestamp for its date.
#
# @param seminar A reference to an XML::LibXML::Element containing the seminar
#                element (and its children) to build the datestamp for.
# @return The timestamp on success, undef on error.
sub _build_timestamp {
    my $self    = shift;
    my $seminar = shift;

    $self -> clear_error();

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
    my $datetime = eval { $self -> {"parser"} -> parse_datetime($date -> textContent." ".$time); };
    return $self -> self_error("Unable to create timestamp for seminar ".$id -> textContent.": $@")
        if($@);

    # Store the timestamp as seconds since the epoch it UTC.
    $seminar -> setAttribute('timestamp', $datetime -> epoch());

    return $datetime -> epoch();
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

    # Go through each seminar adding a unix timestamp
    foreach my $seminar ($dom -> findnodes("seminars/seminar")) {
        $self -> _build_timestamp($seminar)
            or return undef;
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
        my $stamp = $item -> getAttribute("timestamp");

        # Stop if the item's timestamp is before the current time (seminar has already
        # happened, so there's no point in maintaining anything for it)
        last if($stamp <= $now);

        # Get here and the seminar is in the future, add the XML::LibXML::Element to
        # the pending list.
        push(@pending, $item);
    }

    return \@pending;
}

1;