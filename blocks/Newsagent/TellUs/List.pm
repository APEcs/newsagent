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
use experimental 'smartmatch';
use base qw(Newsagent::TellUs); # This class extends the Newsagent TellUs class
use POSIX qw(ceil);
use v5.12;
use Webperl::Utils qw(is_defined_numeric);
use Data::Dumper;


## @method private $ _get_messagelist_settings($year, $month, $pagenum)
# Build the settings used to fetch the message list and build the message list
# user interface.
#
# @param queueid The ID of the queue the user is viewing.
# @param pagenum The page of results the user is looking at.
# @return A reference to a hash of settings to use for the article list
sub _get_messagelist_settings {
    my $self      = shift;
    my $queueid   = shift;
    my $pagenum   = shift;
    my $settings  = {"count" => $self -> {"settings"} -> {"config"} -> {"Article::List:count"},
                     "pagenum"       => 1,
                     "show_rejected" => 0,
                     "queueid"       => $queueid,
    };

    $settings -> {"pagenum"} = $pagenum if(defined($pagenum) && $pagenum =~ /^\d+$/ && $pagenum > 0);
    $settings -> {"offset"}  = ($settings -> {"pagenum"} - 1) * $settings -> {"count"};

    return $settings;
}


## @method private $ _update_messagelist_allowed($msgids, $userid)
# Determine whether the user has permission to update the messages with the
# specified IDs. The user must have update permission for *ALL* the specified
# messages, or this will assume Shenanigans Are Afoot and deny permission to
# all the messages.
#
# @param msgids A string containing a comma separated list of message IDs
# @param userid The ID of the user to check update permission for
# @return A reference to an array of message IDs to update on success, undef
#         if the user does not have permission to update one or more of
#         the specified messages.
sub _update_messagelist_allowed {
    my $self   = shift;
    my $msgids = shift;
    my $userid = shift;

    # Extract the message IDs from the list. This will junk any entries that are not pure digits separated by commas.
    my @idlist = $msgids =~ /(\d+)(?:,|$)/g;

    # This will bail if any of the messages can't be deleted. Note that this *does not* delete anything
    foreach my $id (@idlist) {
        return undef
            if(!$self -> {"tellus"} -> update_allowed($id, $userid))
    }

    return \@idlist;
}


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


## @method private $ _build_typeopts()
# Generate the list of message types supported by the system for inclusion in the
# selection menu.
#
# @return A string containing the system message type list.
sub _build_typeopts {
    my $self     = shift;
    my $typeopts = "";

    my $types = $self -> {"tellus"} -> get_types()
        or return "";

    foreach my $type (@{$types}) {
        $typeopts .= $self -> {"template"} -> load_template("tellus/queues/typeopt.tem", {"***type***"     => lc($type -> {"name"}),
                                                                                          "***typename***" => $type -> {"name"}});
    }

    return $typeopts;
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

        my $namenew = $queue -> {"name"};
        $namenew .= " (".$stats -> {"new"}.")" if($stats -> {"new"});

        $result .= $self -> {"template"} -> load_template("tellus/queues/queue.tem", {"***highlight***" => join(" ", @{$highlight}),
                                                                                      "***idname***"    => lc($queue -> {"name"}),
                                                                                      "***name***"      => $queue -> {"name"},
                                                                                      "***namenew***"   => $namenew,
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


## @method private $ _build_move_targetlist($userid, $current)
# Generate the dropdown selector from which the user can select
# a target queue.
#
# @param userid  The ID of the current user.
# @param current A reference to a hash containing the current
#                queue details.
# @return A string containing the target queue list.
sub _build_move_targetlist {
    my $self    = shift;
    my $userid  = shift;
    my $current = shift;

    # Fetch the list of queue the user can manage or move messages to
    my $queues = $self -> {"tellus"} -> get_queues($userid, ['moveto', 'manage'])
        or return $self -> {"template"} -> load_template("tellus/queues/notargets.tem");

    my $queuelist = "";
    foreach my $queue (@{$queues}) {
        # Skip the current queue
        next if($queue -> {"id"} == $current -> {"id"});

        $queuelist .= $self -> {"template"} -> load_template("tellus/queues/target.tem", {"***id***"   => $queue -> {"id"},
                                                                                          "***name***" => $queue -> {"name"}});
    }

    return $self -> {"template"} -> load_template("tellus/queues/notargets.tem")
        if(!$queuelist);

    return $self -> {"template"} -> load_template("tellus/queues/targetlist.tem", {"***targets***" => $queuelist});
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

    my $summary = $self -> {"template"} -> html_strip($message -> {"message"});
    $summary = $self -> truncate_text($summary, 120);

    return $self -> {"template"} -> load_template("tellus/queues/row.tem", {"***id***"        => $message -> {"id"},
                                                                            "***adddate***"   => $self -> {"template"} -> fancy_time($message -> {"created"}),
                                                                            "***realname***"  => $message -> {"realname"},
                                                                            "***email***"     => $message -> {"email"},
                                                                            "***summary***"   => $summary,
                                                                            "***typeclass***" => lc($message -> {"name"}),
                                                                            "***typeinfo***"  => $message -> {"name"},
                                                                            "***modeclass***" => $message -> {"state"},
                                                                            "***extrainfo***" => "",
                                                                            "***controls***"  => $self -> {"template"} -> load_template("tellus/queues/control_default.tem", {"***id***" => $message -> {"id"}})

                                                  });
}


## @method private @ _generate_messagelist($queue, $pagenum)
# Generate the contents of a page listing the queues messages the user has
# permission to edit.
#
# @return Two strings: the page title, and the contents of the page.
sub _generate_messagelist {
    my $self      = shift;
    my $queue     = shift;
    my $pagenum   = shift || 1;
    my $userid    = $self -> {"session"} -> get_session_userid();
    my $now       = time();
    my ($body, $queuelist, $paginate, $targets, $typeopts) = ("", "", "", "", "");

    my $queuedata = $self -> {"tellus"} -> active_queue($queue, $userid);
    if($queuedata) {
        $queuelist = $self -> _build_queue_list($queuedata -> {"id"}, $userid);

        my $settings  = $self -> _get_messagelist_settings($queuedata -> {"id"}, $pagenum);

        my $messages = $self -> {"tellus"} -> get_queue_messages($settings);
        foreach my $message (@{$messages -> {"messages"}}) {
            $body .= $self -> _build_message_row($message, $now);
        }

        $body = $self -> {"template"} -> load_template("tellus/queues/norows.tem")
            if(!$body);

        my $maxpage = ceil($messages -> {"metadata"} -> {"count"} / $settings -> {"count"});
        $paginate = $self -> _build_pagination({ maxpage => $maxpage,
                                                 pagenum => $settings -> {"pagenum"},
                                                 queue   => lc($queuedata -> {"name"}),
                                               });

        $targets = $self -> _build_move_targetlist($userid, $queuedata);

        $typeopts = $self -> _build_typeopts();
    }

    return ($self -> {"template"} -> replace_langvar("TELLUS_QLIST_TITLE"),
            $self -> {"template"} -> load_template("tellus/queues/content.tem", {"***queues***"      => $queuelist,
                                                                                 "***messages***"    => $body,
                                                                                 "***paginate***"    => $paginate,
                                                                                 "***targets***"     => $targets,
                                                                                 "***typeopts***"    => $typeopts,
                                                                                 "***compose-url***" => $self -> build_url(block    => "compose",
                                                                                                                           params   => [],
                                                                                                                           pathinfo => []),
                                                                                 "***mlist-url***"   => $self -> build_url(block    => "queues",
                                                                                                                           params   => [],
                                                                                                                           pathinfo => [])
                                                   }));
}


# ============================================================================
#  API functions

## @method private $ _build_api_view_response()
# Generate the HTML to send back to the user in response to to a message view
# request.
#
# @return The HTML to return to the user.
sub _build_api_view_response {
    my $self   = shift;
    my $userid = $self -> {"session"} -> get_session_userid();

    # determine which message the user is attempting to view.
    my $msgid = is_defined_numeric($self -> {"cgi"}, "id")
        or $self -> api_errorhash("internal_error", $self -> {"template"} -> replace_langvar("API_ERROR", {"***error***" => "{L_TELLUS_QLIST_ERR_NOMSGID}"}));

    my $message = $self -> {"tellus"} -> get_message($msgid)
        or $self -> api_errorhash("internal_error", $self -> {"template"} -> replace_langvar("API_ERROR", {"***error***" => $self -> {"tellus"} -> errstr()}));

    # does the user have permission to view the message ( = manage on its current queue)
    return $self -> api_errorhash("internal_error", $self -> {"template"} -> replace_langvar("API_ERROR", {"***error***" => "{L_TELLUS_QLIST_ERR_NOVIEWPERM}"}))
        unless($self -> check_permission("tellus.manage", $message -> {"metadata_id"}, $userid));

    # mark the message as read
    $self -> {"tellus"} -> set_message_status($msgid, $userid, "read");

    # User has permission, return the message text
    return $self -> {"template"} -> load_template("tellus/queues/viewmsg.tem", {"***message***" => $message -> {"message"}});
}


## @method private $ _build_api_queuelist_response()
# Generate an API response listing the queues the user has access to manage, the
# text to show ad the queue name in ther interface, the internal queue name, and
# whether the queue has new messages in it.
#
# @return A reference to a hash containing the API response.
sub _build_api_queuelist_response {
    my $self = shift;
    my $userid = $self -> {"session"} -> get_session_userid();
    my $queuelist = [ ];

    my $queues = $self -> {"tellus"} -> get_queues($userid, "manage");

    # Now go through the queues fetching their stats and building table rows
    foreach my $queue (@{$queues}) {
        my $stats = $self -> {"tellus"} -> get_queue_stats($queue -> {"value"});

        my $namenew = $queue -> {"name"};
        $namenew .= " (".$stats -> {"new"}.")" if($stats -> {"new"});

        push(@{$queuelist}, {"name"   => lc($queue -> {"name"}),
                             "value"  => $namenew,
                             "hasnew" => $stats -> {"new"}});
    }

    return {"result" => {"queues" => {"queue" => $queuelist}}};
}


## @method private $ _build_api_update_success($messids, $userid)
# Generate a hash containing the success information for a (potentially multi-message)
# move, reject, or delete request.
#
# @param messids A reference to an array of message ID numbers.
# @param userid  The ID of the user who made the request.
# @return A reference to a hash containing the result information.
sub _build_api_update_success {
    my $self    = shift;
    my $messids = shift;
    my $userid  = shift;
    my $queuelist = [ ];

    my $queues = $self -> {"tellus"} -> get_queues($userid, "manage");

    # Now go through the queues fetching their stats and building table rows
    foreach my $queue (@{$queues}) {
        my $stats = $self -> {"tellus"} -> get_queue_stats($queue -> {"value"});

        my $namenew = $queue -> {"name"};
        $namenew .= " (".$stats -> {"new"}.")" if($stats -> {"new"});

        push(@{$queuelist}, {"name"   => lc($queue -> {"name"}),
                             "value"  => $namenew,
                             "hasnew" => $stats -> {"new"}});
    }

    return {"result" => {"updated"  => "yes",
                         "messages" => { "message" => $messids },
                         "queues"   => {"queue" => $queuelist }
                        }
           };
}


## @method private $ _build_api_move_response()
# Perform a move of any selected messages to a destination queue.
#
# @return A reference to an API response hash to return to the user.
sub _build_api_move_response {
    my $self   = shift;
    my $userid = $self -> {"session"} -> get_session_userid();

    my $destid = is_defined_numeric($self -> {"cgi"}, "dest");
    my $msgids = $self -> {"cgi"} -> param("msgids");

    # Does the user have permission to move items to this queue?
    my $destqueue = $self -> {"tellus"} -> moveto_allowed($destid, $userid);
    return $self -> api_errorhash("internal_error", $self -> {"template"} -> replace_langvar("API_ERROR", {"***error***" => $self -> {"tellus"} -> errstr()}))
        if(!$destqueue);
    return $self -> api_errorhash("internal_error", $self -> {"template"} -> replace_langvar("API_ERROR", {"***error***" => "{L_TELLUS_QLIST_ERR_NOMOVETOPERM}"}))
        if(!$destqueue -> {"id"});

    # User has permission to move to the queue; does user have permission to move the messages?
    my $idlist = $self -> _update_messagelist_allowed($msgids, $userid)
        or return $self -> api_errorhash("internal_error", $self -> {"template"} -> replace_langvar("API_ERROR", {"***error***" => "{L_TELLUS_QLIST_ERR_NOMOVEPERM}"}));

    # now do the move
    foreach my $id (@{$idlist}) {
        $self -> log("tellus:manage", "Moving message '$id' to queue $destid.");

        # Moved messages are always reset to new
        $self -> {"tellus"} -> set_message_status($id, $userid, "new")
            or return $self -> api_errorhash("internal_error", $self -> {"template"} -> replace_langvar("API_ERROR", {"***error***" => $self -> {"tellus"} -> errstr()}));

        # Move into the new queue
        $self -> {"tellus"} -> set_message_queue($id, $userid, $destid)
            or return $self -> api_errorhash("internal_error", $self -> {"template"} -> replace_langvar("API_ERROR", {"***error***" => $self -> {"tellus"} -> errstr()}));

        # notify the queue owner.
        $self -> _notify_add_queue($id);

        # notify the message creator
        $self -> _notify_move_queue($id, $destid);
    }

    return $self -> _build_api_update_success($idlist, $userid);
}


## @method private $ _build_api_promote_response()
# Mark the message specified in the query as being promoted. This is
# used to allow messages that have been promoted into full articles
# to be marked for later reference.
#
# @return A reference to an API response hash to return to the user.
sub _build_api_promote_response {
    my $self   = shift;
    my $userid = $self -> {"session"} -> get_session_userid();
    my $msgid  = $self -> {"cgi"} -> param("msgid");

    # Check whether the user has permission to delete the messages
    $self -> {"tellus"} -> update_allowed($msgid, $userid)
        or return $self -> api_errorhash("internal_error", $self -> {"template"} -> replace_langvar("API_ERROR", {"***error***" => "{L_TELLUS_QLIST_ERR_NOPROMPERM}"}));

    $self -> log("tellus:manage", "Setting status of message '$msgid' to promoted.");

    # Messages are never really deleted, they just get the appropriate state
    $self -> {"tellus"} -> set_message_status($msgid, $userid, "promoted")
        or return $self -> api_errorhash("internal_error", $self -> {"template"} -> replace_langvar("API_ERROR", {"***error***" => $self -> {"tellus"} -> errstr()}));

    return {"result" => {"updated"  => "yes" } };
}


## @method private $ _build_api_delete_response()
# Perform a delete of any selected messages.
#
# @return A reference to an API response hash to return to the user.
sub _build_api_delete_response {
    my $self   = shift;
    my $userid = $self -> {"session"} -> get_session_userid();

    my $msgids = $self -> {"cgi"} -> param("msgids");

    # Check whether the user has permission to delete the messages
    my $idlist = $self -> _update_messagelist_allowed($msgids, $userid)
        or return $self -> api_errorhash("internal_error", $self -> {"template"} -> replace_langvar("API_ERROR", {"***error***" => "{L_TELLUS_QLIST_ERR_NODELPERM}"}));

    # now do the delete
    foreach my $id (@{$idlist}) {
        $self -> log("tellus:manage", "Setting status of message '$id' to deleted.");

        # Messages are never really deleted, they just get the appropriate state
        $self -> {"tellus"} -> set_message_status($id, $userid, "deleted")
            or return $self -> api_errorhash("internal_error", $self -> {"template"} -> replace_langvar("API_ERROR", {"***error***" => $self -> {"tellus"} -> errstr()}));
    }

    return $self -> _build_api_update_success($idlist, $userid);
}


## @method private $ _build_api_setread_response()
# Mark the selected messages as read.
#
# @return A reference to an API response hash to return to the user.
sub _build_api_setread_response {
    my $self   = shift;
    my $userid = $self -> {"session"} -> get_session_userid();

    my $msgids = $self -> {"cgi"} -> param("msgids");

    # Check whether the user has permission to delete the messages
    my $idlist = $self -> _update_messagelist_allowed($msgids, $userid)
        or return $self -> api_errorhash("internal_error", $self -> {"template"} -> replace_langvar("API_ERROR", {"***error***" => "{L_TELLUS_QLIST_ERR_NOVIEWPERM}"}));

    # now do the delete
    foreach my $id (@{$idlist}) {
        $self -> log("tellus:manage", "Setting status of message '$id' to read.");

        # Messages are never really deleted, they just get the appropriate state
        $self -> {"tellus"} -> set_message_status($id, $userid, "read")
            or return $self -> api_errorhash("internal_error", $self -> {"template"} -> replace_langvar("API_ERROR", {"***error***" => $self -> {"tellus"} -> errstr()}));
    }

    return $self -> _build_api_update_success($idlist, $userid);
}


## @method private $ _build_api_checkrej_response()
# Determine whether the user can reject the selected messages, and send
# back the reject form if so.
#
# @return A reference to an API response hash to return to the user.
sub _build_api_checkrej_response {
    my $self   = shift;
    my $userid = $self -> {"session"} -> get_session_userid();

    my $msgids = $self -> {"cgi"} -> param("msgids");

    # Check whether the user has permission to delete the messages
    my $idlist = $self -> _update_messagelist_allowed($msgids, $userid)
        or return $self -> api_errorhash("internal_error", $self -> {"template"} -> replace_langvar("API_ERROR", {"***error***" => "{L_TELLUS_QLIST_ERR_NOREJPERM}"}));

    return $self -> {"template"} -> load_template("tellus/queues/rejform.tem");
}


# @method private $ _build_api_reject_response()
# Reject the selected messages.
#
# @return A reference to an API response hash to return to the user.
sub _build_api_reject_response {
    my $self   = shift;
    my $userid = $self -> {"session"} -> get_session_userid();

    my $msgids = $self -> {"cgi"} -> param("msgids");
    my ($reason, $error) = $self -> validate_string("reason", {"required" => 0,
                                                               "nicename" => $self -> {"template"} -> replace_langvar("TELLUS_QLIST_ERR_BADREASON")});
    return $self -> api_errorhash("internal_error", $self -> {"template"} -> replace_langvar("API_ERROR", {"***error***" => $error}))
        if($error);

    # rejcheck will have checked the message ids. And relying on that would be really stupid: check
    # all the messages again to make sure the user really has permission to reject them.
    my $idlist = $self -> _update_messagelist_allowed($msgids, $userid)
        or return $self -> api_errorhash("internal_error", $self -> {"template"} -> replace_langvar("API_ERROR", {"***error***" => "{L_TELLUS_QLIST_ERR_NOREJPERM}"}));

    foreach my $id (@{$idlist}) {
        $self -> log("tellus:manage", "Setting status of message '$id' to rejected, message '$reason'.");

        # Reject!
        $self -> {"tellus"} -> set_message_status($id, $userid, "rejected", $reason)
            or return $self -> api_errorhash("internal_error", $self -> {"template"} -> replace_langvar("API_ERROR", {"***error***" => $self -> {"tellus"} -> errstr()}));

        $self -> _notify_reject($id, $reason)
            if($reason);
    }

    return $self -> _build_api_update_success($idlist, $userid);
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

    # permissions are checked within the various API and generation functions, there
    # is no single global 'queue manage' permission.

    # Is this an API call, or a normal page operation?
    my $apiop = $self -> is_api_operation();
    if(defined($apiop)) {
        # API call - dispatch to appropriate handler.
        given($apiop) {
            when("checkrej") { return $self -> api_html_response($self -> _build_api_checkrej_response()); }
            when("delete")   { return $self -> api_response($self -> _build_api_delete_response()); }
            when("move")     { return $self -> api_response($self -> _build_api_move_response()); }
            when("queues")   { return $self -> api_response($self -> _build_api_queuelist_response()); }
            when("reject")   { return $self -> api_response($self -> _build_api_reject_response()); }
            when("setread")  { return $self -> api_response($self -> _build_api_setread_response()); }
            when("promote")  { return $self -> api_response($self -> _build_api_promote_response()); }
            when("view")     { return $self -> api_html_response($self -> _build_api_view_response()); }
            default {
                return $self -> api_html_response($self -> api_errorhash('bad_op',
                                                                         $self -> {"template"} -> replace_langvar("API_BAD_OP")))
            }
        }
    } else {
        my @pathinfo = $self -> {"cgi"} -> multi_param('pathinfo');

        given($pathinfo[1]) {
            when("page") { ($title, $content) = $self -> _generate_messagelist($pathinfo[0], $pathinfo[2]); }
            default {
                ($title, $content) = $self -> _generate_messagelist($pathinfo[0], 1);
            }
        }

        $extrahead .= $self -> {"template"} -> load_template("tellus/queues/extrahead.tem");
        return $self -> generate_newsagent_page($title, $content, $extrahead, "list");
    }
}

1;
