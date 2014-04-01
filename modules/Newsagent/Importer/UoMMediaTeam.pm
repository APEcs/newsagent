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
use base qw(Newsagent::Importer); # This class extends the Newsagent block class
use v5.12;
use DateTime;
use LWP::UserAgent;
use XML::Simple;
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

    my $updates = $self -> _fetch_updated_xml($self -> {"args"} -> {"url"}, DateTime -> from_epoch(epoch => $self -> {"importer_lastrun"} || 0))
        or return undef;

    foreach my $article (@{$updates}) {
        $self -> _import_article($article)
            or return undef;
    }

    return 1;
}


# ============================================================================
#  Internal implementation-specifics


## @method private $ _import_article($article)
# Attempt to import the specified article into the system, either updating the
# existing copy of it, or adding a copy to the system.
#
# @param article A reference to an UoM media article.
# @return true on succes, undef on error.
sub _import_article {
    my $self    = shift;
    my $article = shift;

    $self -> clear_error();

    # Attempt to locate any existing copies of this article in the system
    my $oldmeta = $self -> find_by_sourceid($article -> {"a"} -> {"name"});
    return undef if(!defined($oldmeta));

    # If an old ID has been found, update the article associated with it, otherwise
    # create a new article instead.
    if($oldmeta) {
        return $self -> _update_import($oldmeta, $article);
    } else {
        return $self -> _create_import($article);
    }
}


## @method private $ _create_import($article)
# Create a new Newsagent article using the contents of the specified UoM media team article.
#
# @param article A reference to hash containing a UoM media team article.
# @return true on success, undef on error.
sub _create_import {
    my $self    = shift;
    my $article = shift;

    $self -> clear_error();

    my $aid = $self -> {"article"} -> add_article({"images"  => {"a" => { "url" => $article -> {"images"} -> {"small"},
                                                                          "mode" => "url",
                                                                        },
                                                                 "b" => { "url" => $article -> {"images"} -> {"large"},
                                                                          "mode" => "url",
                                                                        },
                                                                },
                                                   "levels"  => { 'home' => 1, 'leader' => 1, 'group' => 1 },
                                                   "feeds"   => [ $self -> {"args"} -> {"feed"} ],
                                                   "release_mode" => 'visible',
                                                   "relmode"      => 0,
                                                   "full_summary" => 0,
                                                   "minor_edit"   => 0,
                                                   "sticky"       => 0,
                                                   "title"   => $article -> {"headline"},
                                                   "summary" => $article -> {"strapline"},
                                                   "article" => $article -> {"mainbody"},
                                                  },
                                                  $self -> {"args"} -> {"userid"})
        or return $self -> self_error("Article addition failed: ".$self -> {"article"} -> errstr());

    return $self -> _add_import_meta($aid, $article -> {"a"} -> {"name"});
}


## @method private $ _update_import($oldmeta, $article)
# Determine whether the specified article needs to be updated, and if so update the data.
#
# @param oldmeta The import metadata for the import.
# @param article A reference to hash containing a UoM media team article.
# @return true on success (either the article does not need updating, or it has been
#         updated successfully), undef on error.
sub _update_import {
    my $self    = shift;
    my $oldmeta = shift;
    my $article = shift;

    $self -> clear_error();

    # Convert the last update in the metadata to a datatime, and then check whether the
    # source article has been updated since the last update
    # WARNING: This may cause problems with DST. By default from_epoch will be UTC, and
    # hopefully comparison with the datePub field will be timezone/DST sane....
    my $updated = DateTime -> from_epoch(epoch => $oldmeta -> {"updated"});

    return 1 if($updated >= $article -> {"datePub"});

    # Okay, the source article was updated after the last update for the import
    # update the settings for the newsagent article
    return $self -> {"article"} -> update_article_inplace($oldmeta -> {"article_id"}, { "images"  => {"a" => { "url" => $article -> {"images"} -> {"small"},
                                                                                                               "mode" => "url",
                                                                                                             },
                                                                                                      "b" => { "url" => $article -> {"images"} -> {"large"},
                                                                                                               "mode" => "url",
                                                                                                             },
                                                                                                     },
                                                                                        "title"   => $article -> {"headline"},
                                                                                        "summary" => $article -> {"strapline"},
                                                                                        "article" => $article -> {"mainbody"},
                                                                                      })
        or $self -> self_error($self -> {"article"} -> errstr());

    return $self -> _touch_import_meta($oldmeta -> {"id"});
}


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
