# @file
# This file contains the implementation of the base Feed class
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
package Newsagent::Feed;

use strict;
use base qw(Newsagent); # This class extends the Newsagent block class
use Newsagent::System::Article;
use Newsagent::System::Feed;
use Digest::MD5 qw(md5_hex);
use Webperl::Utils qw(trimspace path_join);
use Date::Calc qw(Add_Delta_YMD Localtime Date_to_Time);
use v5.12;


# ============================================================================
#  Constructor

## @cmethod $ new(%args)
# Overloaded constructor for the feed facility, loads the System::Article model
# and other classes required to generate the feeds.
#
# @param args A hash of values to initialise the object with. See the Block docs
#             for more information.
# @return A reference to a new Newsagent::Feed object on success, undef on error.
sub new {
    my $invocant = shift;
    my $class    = ref($invocant) || $invocant;
    my $self     = $class -> SUPER::new("timefmt" => '%a, %d %b %Y %H:%M:%S %z',
                                        @_)
        or return undef;

    $self -> {"feed"} = Newsagent::System::Feed -> new(dbh      => $self -> {"dbh"},
                                                       settings => $self -> {"settings"},
                                                       logger   => $self -> {"logger"},
                                                       roles    => $self -> {"system"} -> {"roles"},
                                                       metadata => $self -> {"system"} -> {"metadata"})
        or return Webperl::SystemModule::set_error("Article initialisation failed: ".$SystemModule::errstr);

    $self -> {"article"} = Newsagent::System::Article -> new(feed     => $self -> {"feed"},
                                                             dbh      => $self -> {"dbh"},
                                                             settings => $self -> {"settings"},
                                                             logger   => $self -> {"logger"},
                                                             roles    => $self -> {"system"} -> {"roles"},
                                                             metadata => $self -> {"system"} -> {"metadata"})
        or return Webperl::SystemModule::set_error("Article initialisation failed: ".$SystemModule::errstr);

    return $self;
}


# ============================================================================
#  Validation code

## @method private $ _validate_settings()
# Validate any settings specified by the user on the query string, and create a
# hash containing the validated settings.
#
# @return A reference to a hash of query settings.
sub _validate_settings {
    my $self     = shift;
    my $settings = {};
    my $error;

    # Fulltext flag
    given($self -> {"cgi"} -> param("fulltext")) {
        when ("enabled")  { $settings -> {"fulltext_mode"} = "enabled"; }
        when ("markdown") { $settings -> {"fulltext_mode"} = "markdown"; }
        when ("plain")    { $settings -> {"fulltext_mode"} = "plain"; }
        when ("embedimg") { $settings -> {"fulltext_mode"} = "embedimg"; }
        default {
            $settings -> {"fulltext_mode"} = "";
        }
    }

    # description overriding
    given($self -> {"cgi"} -> param("desc")) {
        when ("fulltext") { $settings -> {"use_fulltext_desc"} = 1;

                            # Default the fulltext mode if it has not already been set.
                            $settings -> {"fulltext_mode"} = "embedimg" if(!$settings -> {"fulltext_mode"});
        }
        default {
            $settings -> {"use_fulltext_desc"} = 0;
        }
    }

    # Image control is only used by some feeds
    $settings -> {"images"} = 1
        if(defined($self -> {"cgi"} -> param("images")));

    # count and offset are easy
    ($settings -> {"id"}, $error)  = $self -> validate_numeric("id", {"required" => 0,
                                                                      "intonly"  => 1,
                                                               });
    ($settings -> {"articleid"}, $error)  = $self -> validate_numeric("articleid", {"required" => 0,
                                                                                    "intonly"  => 1,
                                                                      });
    $settings -> {"id"} = $settings -> {"articleid"}
        if(!$settings -> {"id"} && $settings -> {"articleid"});

    ($settings -> {"count"}, $error)  = $self -> validate_numeric("count", {"required" => 0,
                                                                            "intonly"  => 1,
                                                                            "default"  => $self -> {"settings"} -> {"config"} -> {"Feed:count"},
                                                                            "min"      => 1,
                                                                            "max"      => $self -> {"settings"} -> {"config"} -> {"Feed:count_limit"},
                                                                            "nicename" => ""
                                                                  });

    ($settings -> {"offset"}, $error)  = $self -> validate_numeric("offset", {"required" => 0,
                                                                              "intonly"  => 1,
                                                                              "default"  => 0,
                                                                              "min"      => 0,
                                                                              "nicename" => ""
                                                                   });

    # Feed and level are up next
    ($settings -> {"feed"}, $error) = $self -> validate_string("feed", {"required"   => 0,
                                                                        "default"    => "",
                                                                        "formattest" => '^\w+(?:,\w+)*$',
                                                                        "formatdesc" => "",
                                                                        "nicename"   => ""});
    ($settings -> {"site"}, $error) = $self -> validate_string("site", {"required"   => 0,
                                                                        "default"    => "",
                                                                        "formattest" => '^\w+(?:,\w+)*$',
                                                                        "formatdesc" => "",
                                                                        "nicename"   => ""});
    $settings -> {"feed"} = $settings -> {"site"}
        if(!$settings -> {"feed"} && $settings -> {"site"});

    my @feeds = split(/,/, $settings -> {"feed"} || "");
    $settings -> {"feeds"} = \@feeds;

    ($settings -> {"level"}, $error) = $self -> validate_string("level", {"required"   => 0,
                                                                          "default"    => "",
                                                                          "formattest" => '^\w+(?:,\w+)*$',
                                                                          "formatdesc" => "",
                                                                          "nicename"   => ""});
    my @levels = split(/,/, $settings -> {"level"} || "");
    $settings -> {"levels"} = \@levels;

    ($settings -> {"viewer"}, $error) = $self -> validate_string("viewer", {"required"   => 0,
                                                                            "default"    => "",
                                                                            "formattest" => '^\w+$',
                                                                            "formatdesc" => "",
                                                                            "nicename"   => ""});

    # If a maximum age is specified, convert it to a unix timestamp to use for filtering
    ($settings -> {"maxage"}, $error) = $self -> validate_string("maxage", {"required"   => 0,
                                                                            "default"    => $self -> {"settings"} -> {"config"} -> {"Feed:max_age"},
                                                                            "formattest" => '^\d+[dmy]?$',
                                                                            "formatdesc" => "",
                                                                            "nicename"   => ""});
    if($settings -> {"maxage"}) {
        my ($count, $modifier) = $settings -> {"maxage"} =~ /^(\d+)([dmy])?$/;
        my ($year, $month, $day) = Localtime();
        my ($dyear, $dmonth, $dday);

        given($modifier) {
            when("m") { ($dyear, $dmonth, $dday) = Add_Delta_YMD($year, $month, $day, 0, (-1 * $count), 0); }
            when("y") { ($dyear, $dmonth, $dday) = Add_Delta_YMD($year, $month, $day, (-1 * $count), 0, 0); }
            default {
                ($dyear, $dmonth, $dday) = Add_Delta_YMD($year, $month, $day, 0, 0, (-1 * $count));
            }
        }

        $settings -> {"maxage"} = Date_to_Time($dyear, $dmonth, $dday, 0, 0, 0);
    }

    return $settings;
}


# ============================================================================
#  Support

## @method $ feed_url($viewer, $setfeeds, $artfeeds, $articleid)
# Generate a URL to use as the viewer URL for the feed. This will attempt to
# create a URL based on the 'viewer' name specified, first checking for a
# feed with the specified name in the feeds table and then using its default
# viewer URL, then checking the feed_urls table for a match. If none are
# found, the default URL is returned.
#
# @param viewer     The name of the feed to use the viewer URL from. If this is
#                   'internal' the Newsagent built-in article viewer URL is
#                   returned, otherwise if a matching feed or feed url entry is
#                   found, its URL is used.
# @param setfeeds   A reference to the list of feeds requested by the user.
# @param artfeeds   A reference to a list of feeds set for the article.
# @param articleid  The ID of the article to view.
# @return A string containing the URL of an article viewer on success, undef
#         on error.
sub feed_url {
    my $self       = shift;
    my $viewer     = shift;
    my $setfeeds   = shift;
    my $artfeeds   = shift;
    my $articleid  = shift;

    $self -> clear_error();

    my $viewerparam = "?articleid=$articleid";

    # If a viewer has been set, try using it.
    if($viewer) {
        # If the caller has requested an internal viewer, the URL is simple
        return $self -> build_url(fullurl  => 1,
                                  block    => "view",
                                  pathinfo => [ "article", $articleid])
            if($viewer eq "internal");

        # Not an internal viewer, check for a matching feed
        my $feedurl = $self -> {"feed"} -> get_feed_url($viewer);
        return $feedurl.$viewerparam
            if($feedurl);
    }

    # No viewer was specified, or it is not valid; try using the first configured feed url if there is one
    if($setfeeds && scalar(@{$setfeeds})) {
        my $feedurl = $self -> {"feed"} -> get_feed_url($setfeeds -> [0]);

        return $feedurl.$viewerparam
            if($feedurl);
    }

    # No valid viewer or feed specified, fall back on the first configured
    # feed for the article
    return $artfeeds -> [0] -> {"default_url"}.$viewerparam;
}


# ============================================================================
#  Interface functions

## @method $ page_display()
# Produce the string containing this block's full page content. This generates
# the compose page, including any errors or user feedback.
#
# @return The string containing this block's page content.
sub page_display {
    my $self = shift;

    # Is this an API call, or a normal page operation?
    my $apiop = $self -> is_api_operation();
    if(defined($apiop)) {
        # API call - dispatch to appropriate handler.
        given($apiop) {
            default {
                return $self -> api_xml_response($self -> api_errorhash('bad_op',
                                                                        $self -> {"template"} -> replace_langvar("API_BAD_OP")))
            }
        }
    } else {
        $self -> generate_feed();
    }
}

1;
