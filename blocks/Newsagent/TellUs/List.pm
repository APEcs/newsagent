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


## @method private $ _build_queue_list($queueidm $userid)
# Generate the list of queues and their statistics.
#
# @param queueid The currently active queue ID.
# @param userid  The ID of the user listing the queues.
# @return A string containing the queue list
sub _build_queue_list {
    my $self    = shift;
    my $queueid = shift;
    my $userid  = shift;
    my $result  = "";

    # First get the list of queues the user can manage
    my $queues = $self -> {"tellus"} -> get_queues($userid, "manage");

    # Now go through the queues fetching their stats and building table rows
    foreach my $queue (@{$queues}) {
        my $stats = $self -> {"tellus"} -> get_queue_stats($queue -> {"value"});

        # If the queue is active, it needs highlighting as such
        my $highlight = [ ($queueid == $queue -> {"value"} ? "active" : "") ];

        # The highlight may also need to be updated depending on the stats (queues with new messages get highlighted)
        push(@{$highlight}, "hasnew") if($stats -> {"new"});

        $result .= $self -> {"template"} -> load_template("tellus/queues/queue.tem", {"***highlight***" => join(" ", @{$highlight}),
                                                                                    "***name***"      => $queue -> {"name"},
                                                                                    "***new***"       => $stats -> {"new"}    || "0",
                                                                                    "***read***"      => $stats -> {"viewed"} || "0",
                                                                                    "***all***"       => $stats -> {"total"}  || "0",
                                                          });
    }

    # Fallback for users with no queues.
    $result = $self -> {"template"} -> load_template("tellus/queues/noqueues.tem")
        if(!$result);

    return $result;
}


## @method private $ _build_message_row($message, $now)
# Generate the message list row for the specified message.
#
# @param message The message to generate the list row for.
# @param now     The current time as a unix timestamp.
# @return A string containing the message row html.
sub _build_message_row {
    my $self    = shift;
    my $message = shift;
    my $now     = shift;

    return $self -> {"template"} -> load_template("tellus/queues/row.tem", {
                                                  });
}


## @method private @ _generate_queues($queue, $pagenum)
# Generate the contents of a page listing the queues messages the user has
# permission to edit.
#
# @return Two strings: the page title, and the contents of the page.
sub _generate_messagelist {
    my $self     = shift;
    my $queue    = shift;
    my $pagenum  = shift || 1;
    my $userid   = $self -> {"session"} -> get_session_userid();
    my $now      = time();

    my $queuedata = $self -> _active_queue($queue);
    my $queuelist = $self -> _build_queue_list($queuedata -> {"id"}, $userid);

    my $body = "";
    my $messages = $self -> {"tellus"} -> get_queue_messages($queuedata -> {"id"});
    foreach my $message (@{$messages}) {
        $body .= $self -> _build_message_row($message, $now);
    }

    return ($self -> {"template"} -> replace_langvar("TELLUS_QLIST_TITLE"),
            $self -> {"template"} -> load_template("tellus/queues/content.tem", {"***queues***"   => $queuelist,
                                                                                 "***messages***" => $body,
                                                                                 "***paginate***" => $paginate,
                                                   }));
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

        $extrahead .= $self -> {"template"} -> load_template("tellus/queues/extrahead.tem");
        return $self -> generate_newsagent_page($title, $content, $extrahead, "list");
    }
}

1;
