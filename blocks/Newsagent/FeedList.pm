## @file
# This file contains the implementation of the feed list page.
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
package Newsagent::FeedList;

use strict;
use base qw(Newsagent); # This class extends the Newsagent block class
use Newsagent::System::Article;
use Newsagent::System::Feed;
use v5.12;

# ============================================================================
#  Constructor

## @cmethod $ new(%args)
# Overloaded constructor for the Compose facility, loads the System::Article model
# and other classes required to generate the compose pages.
#
# @param args A hash of values to initialise the object with. See the Block docs
#             for more information.
# @return A reference to a new Newsagent::Compose object on success, undef on error.
sub new {
    my $invocant = shift;
    my $class    = ref($invocant) || $invocant;
    my $self     = $class -> SUPER::new(@_)
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

    $self -> {"fulltext"} = [ { "value" => "off",
                                "name"  => "{L_FLIST_FTEXT_NONE}" },
                              { "value" => "enabled",
                                "name"  => "{L_FLIST_FTEXT_HTML}" },
                              { "value" => "markdown",
                                "name"  => "{L_FLIST_FTEXT_MD}" },
                              { "value" => "plain",
                                "name"  => "{L_FLIST_FTEXT_TEXT}" },
                              { "value" => "embedimg",
                                "name"  => "{L_FLIST_FTEXT_ALL}" },
                            ];
    $self -> {"viewer"} = [ {"value" => "",
                             "name"  => "{L_FLIST_VIEW_DEF}" },
                            {"value" => "internal",
                             "name"  => "{L_FLIST_VIEW_INT}" },
                          ];

    return $self;
}


# ============================================================================
#  Content generators


## @method private $ _build_level_options()
# Build a list of level options the user can select from when building a feed URL.
#
# @return A string containing the level options.
sub _build_level_options {
    my $self = shift;

    my $levels  = $self -> {"article"} -> get_all_levels();
    my $options = [];

    # Convert the levels list to a format that generate_multiselect likes
    foreach my $level (@{$levels}) {
        push(@{$options}, {"id"   => $level -> {"value"},
                           "name" => $level -> {"value"},
                           "desc" => $level -> {"name"}});
    }

    return $self -> generate_multiselect("levels", "levels", "level", $options);
}


## @method pricate $ _build_feed_row($feed)
# Generate a feed list row from the specified feed data.
#
# @param feed A reference to a hash containing the feed data to use in the row.
# @return A string containing the feed data.
sub _build_feed_row {
    my $self = shift;
    my $feed = shift;

    my $rssurl = $self -> build_url(fullurl => 1,
                                    block   => "rss",
                                    params  => { "feed" => $feed -> {"name"} });

    return $self -> {"template"} -> load_template("feedlist/row.tem", {"***id***" => $feed -> {"id"},
                                                                       "***description***" => $feed -> {"description"},
                                                                       "***name***"        => $feed -> {"name"},
                                                                       "***rssurl***"      => $rssurl, });
}


## @method private @ _generate_feedlist()
# Generate the contents of a page listing the feeds available in the system
#
# @return Two strings: the page title, and the contents of the page.
sub _generate_feedlist {
    my $self = shift;

    my $feeds = $self -> {"feed"} -> get_feeds();
    if($feeds) {
        my $list = "";

        foreach my $feed (@{$feeds}) {
            $list .= $self -> _build_feed_row($feed);
        }
        $list = $self -> {"template"} -> load_template("feedlist/empty.tem")
            if(!$list);

        return ($self -> {"template"} -> replace_langvar("FLIST_PTITLE"),
                $self -> {"template"} -> load_template("feedlist/content.tem", {"***feeds***"    => $list,
                                                                                "***levels***"   => $self -> _build_level_options(),
                                                                                "***fulltext***" => $self -> {"template"} -> build_optionlist($self -> {"fulltext"}),
                                                                                "***viewops***"  => $self -> {"template"} -> build_optionlist($self -> {"viewer"}),
                                                                                "***rss_url***"  => $self -> build_url(fullurl  => 1,
                                                                                                                       block    => "rss",
                                                                                                                       params   => { },
                                                                                                                       pathinfo => [ ]),
                                                                               })
               );
    } else {
        return $self -> build_error_box($self -> {"feed"} -> errstr());
    }
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
    my ($title, $content, $extrahead);

    # NOTE: no need to check login here, this module can be used without logging in.

    # Is this an API call, or a normal page operation?
    my $apiop = $self -> is_api_operation();
    if(defined($apiop)) {
        # API call - dispatch to appropriate handler.
        given($apiop) {
            default {
                return $self -> api_html_response($self -> api_errorhash('bad_op',
                                                                         $self -> {"template"} -> replace_langvar("API_BAD_OP")))
            }
        }
    } else {
        my @pathinfo = $self -> {"cgi"} -> param('pathinfo');

        given($pathinfo[2]) {
            default {
                ($title, $content) = $self -> _generate_feedlist();
            }
        }

        $extrahead .= $self -> {"template"} -> load_template("feedlist/extrahead.tem");
        return $self -> generate_newsagent_page($title, $content, $extrahead, "feedlist");
    }
}

1;
