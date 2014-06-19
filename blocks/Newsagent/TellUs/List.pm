# @file
# This file contains the implementation of the tell us listing facility.
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
package Newsagent::TellUs::List;

use strict;
use base qw(Newsagent::TellUs); # This class extends the Newsagent TellUs class
use v5.12;


# ============================================================================
#  Content generators

## @method private $ _build_pagination($settings)
# Generate the navigation/pagination box for the message list. This will generate
# a series of boxes and controls to allow users to move between pages of message
# list. Supported settings are:
#
# - maxpage The last page number (first is page 1).
# - pagenum The selected page (first is page 1)
# - queue   The name of the active queue.
#
# @param settings A reference to a hash containing settings
# @return A string containing the navigation block.
sub _build_pagination {
    my $self     = shift;
    my $settings = shift;

    # If there is more than one page, generate a full set of page controls
    if($settings -> {"maxpage"} > 1) {
        my $controls = "";

        my $active = ($settings -> {"pagenum"} > 1) ? "newer.tem" : "newer_disabled.tem";
        $controls .= $self -> {"template"} -> load_template("paginate/$active", {"***prev***"  => $self -> build_url(pathinfo => [$settings -> {"queue"}, "page", $settings -> {"pagenum"} - 1])});

        $active = ($settings -> {"pagenum"} < $settings -> {"maxpage"}) ? "older.tem" : "older_disabled.tem";
        $controls .= $self -> {"template"} -> load_template("paginate/$active", {"***next***" => $self -> build_url(pathinfo => [$settings -> {"queue"}, "page", $settings -> {"pagenum"} + 1])});

        return $self -> {"template"} -> load_template("paginate/block.tem", {"***pagenum***" => $settings -> {"pagenum"},
                                                                             "***maxpage***" => $settings -> {"maxpage"},
                                                                             "***pages***"   => $controls});
    # If there's only one page, a simple "Page 1 of 1" will do the trick.
    } else { # if($settings -> {"maxpage"} > 1)
        return $self -> {"template"} -> load_template("paginate/block.tem", {"***pagenum***" => 1,
                                                                             "***maxpage***" => 1,
                                                                             "***pages***"   => ""});
    }
}


## @method private $ _build_message_row($message, $now)
# Generate the article list row for the specified message.
#
# @param article The article to generate the list row for.
# @param now     The current time as a unix timestamp.
# @return A string containing the article row html.
sub _build_article_row {
    my $self    = shift;
    my $article = shift;
    my $now     = shift;

    return $self -> {"template"} -> load_template("tellus/list/row.tem", {
                                                  });
}


## @method private @ _generate_queues($queue, $pagenum)
# Generate the contents of a page listing the queues messages the user has
# permission to edit.
#
# @return Two strings: the page title, and the contents of the page.
sub _generate_articlelist {
    my $self     = shift;
    my $queue    = shift;
    my $pagenum  = shift || 1;

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

    my $error = $self -> check_login();
    return $error if($error);

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

        given($pathinfo[1]) {
            when("page") { ($title, $content) = $self -> _generate_queues($pathinfo[0], $pathinfo[2]); }
            default {
                ($title, $content) = $self -> _generate_queues($pathinfo[0], 1);
            }
        }

        $extrahead .= $self -> {"template"} -> load_template("tellus/list/extrahead.tem");
        return $self -> generate_newsagent_page($title, $content, $extrahead, "list");
    }
}

1;
