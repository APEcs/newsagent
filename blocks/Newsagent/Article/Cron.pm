## @file
# This file contains the implementation of the cron-triggered notification
# dispatcher
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
package Newsagent::Article::Cron;

use strict;
use base qw(Newsagent::Article); # This class extends the Article block class
use v5.12;

use Newsagent::System::Matrix;

## @method private $ _send_article_to_recipients($notify)
# Send the specified notification to its recipients. This traverses the list
# of recipients for the notification, updating the appropriate method with the
# settings needed to send to that recipient, and then invoking the dispatcher.
#
# @param notify The notification to send
# @return A reference to an array containing send status information for each
#         recipient, or undef if a serious error occurred.
sub _send_article_to_recipients {
    my $self   = shift;
    my $notify = shift;

    # Fetch the article core data
    my $article = $self -> {"article"} -> get_article($notify -> {"article_id"})
        or return $self -> self_error($self -> {"article"} -> errstr());

    # Now fetch the list of recipient/method rows this notification is going to
    my $recipmeths = $self -> {"notify_methods"} -> {$notify -> {"name"}} -> get_notification_targets($notify -> {"id"}, $notify -> {"year_id"})
        or return $self -> self_error($self -> {"notify_methods"} -> {$notify -> {"name"}} -> errstr());

    return $self -> {"notify_methods"} -> {$notify -> {"name"}} -> send($article, $recipmeths)
        or return $self -> self_error($self -> {"notify_methods"} -> {$notify -> {"name"}} -> errstr());
}


## @method private $ _send_pending_notifications($pending)
# Send the notifications in the pending queue. This processes all the currently
# pending messages
#
# @param pending A reference to an array of pending article notifications
# @return A string containing information about the send process, undef on error.
sub _send_pending_notifications {
    my $self    = shift;
    my $pending = shift;
    my $status  = "";

    foreach my $notify (@{$pending}) {

        # If the notification is still marked as pending, start it sending
        my ($state, $message, $time) = $self -> {"notify_methods"} -> {$notify -> {"name"}} -> get_notification_status($notify -> {"id"});
        if($state eq "pending") {
            # Mark as sending ASAP to prevent grabbing by another cron job on long jobs
            $self -> {"notify_methods"} -> {$notify -> {"name"}} -> set_notification_status($notify -> {"id"}, "sending");

            # Invoke the sender to do the actual work of dispatching the messages
            my $result = $self -> _send_article_to_recipients($notify);
            if(!$result) {
                $status .= $self -> {"template"} -> load_template("cron/status_item.tem", {"***article***" => $notify -> {"article_id"},
                                                                                           "***id***"      => $notify -> {"id"},
                                                                                           "***year***"    => $notify -> {"year_id"},
                                                                                           "***method***"  => $notify -> {"name"},
                                                                                           "***name***"    => "",
                                                                                           "***state***"   => "error",
                                                                                           "***message***" => $self -> errstr(),
                                                                  });
                last;
            }

            # Go through the results from the send code, converting to something usable
            # in the page.
            my $failmsg = "";
            foreach my $row (@{$result}) {
                $status .= $self -> {"template"} -> load_template("cron/status_item.tem", {"***article***" => $notify -> {"article_id"},
                                                                                           "***id***"      => $notify -> {"id"},
                                                                                           "***year***"    => $notify -> {"year_id"},
                                                                                           "***method***"  => $notify -> {"name"},
                                                                                           "***name***"    => $row -> {"name"},
                                                                                           "***state***"   => $row -> {"state"},
                                                                                           "***message***" => $row -> {"message"},
                                                                  });
                $failmsg .= $row -> {"name"}.": ".$row -> {"message"}."\n"
                    if($row -> {"state"} eq "error");
            }

            # Update the message status depending on whether errors were encountered
            $self -> {"notify_methods"} -> {$notify -> {"name"}} -> set_notification_status($notify -> {"id"}, $failmsg ? "failed" : "sent", $failmsg);

        } else {
            # notification grabed by other cron job
            $self -> log("cron", "Status if notification ".$notify -> {"id"}." changed since get_pending_notifications() called");
            $status .= $self -> {"template"} -> load_template("cron/status_item.tem", {"***article***" => $notify -> {"article_id"},
                                                                                       "***id***"      => $notify -> {"id"},
                                                                                       "***year***"    => $notify -> {"year_id"},
                                                                                       "***method***"  => $notify -> {"name"},
                                                                                       "***name***"    => "",
                                                                                       "***state***"   => "",
                                                                                       "***message***" => "Status changed during cron run, unable to process",
                                                                  });
        }
    }

    # return the status string
    return $self -> {"template"} -> load_template("cron/status.tem", {"***items***" => $status});
}


## @method private $ _build_pending_summary($pending)
# Generate a page block listing the currently pending notifications.
#
# @param pending A reference to an array of pending notification hashes.
# @return A string containing the formatted pending notification list.
sub _build_pending_summary {
    my $self    = shift;
    my $pending = shift;
    my $notify  = "";

    foreach my $entry (@{$pending}) {
        $notify .= $self -> {"template"} -> load_template("cron/summary_item.tem", {"***article***" => $entry -> {"article_id"},
                                                                                    "***id***"      => $entry -> {"id"},
                                                                                    "***year***"    => $entry -> {"year_id"},
                                                                                    "***method***"  => $entry -> {"name"},
                                                                                    "***time***"    => $self -> {"template"} -> fancy_time($entry -> {"release_time"}),
                                                          });
    }

    return $self -> {"template"} -> load_template("cron/summary.tem", {"***items***" => $notify});
}


## @method private $ _process_pending($pending)
# Go through the list of pending notifications, invoking the sender for each.
# This will generate a html block showing the sent status.
#
# @param pending A reference to an array of pending notification hashes.
# @return A string containing the formatted pending status list.
sub _process_pending {
    my $self    = shift;
    my $pending = shift;

    return $self -> _send_pending_notifications($pending);
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
    my ($content, $extrahead) = ("", "");

    my $matrix = $self -> {"module"} -> load_module("Newsagent::Notification::Matrix");

    $self -> log("cron", "Cron starting.");

    # Fetch the list of pending notifications
    my $pending = $matrix -> get_pending_notifications()
        or return $self -> generate_errorbox($matrix -> errstr());

    if(!scalar(@{$pending})) {
        $self -> log("cron", "No pending notifications to send.");

        $content = $self -> {"template"} -> load_template("cron/noitems.tem");
    } else {
        $self -> log("cron", scalar(@{$pending})." pending notifications to send.");

        # summarise in case this is being run attended
        my $summary = $self -> _build_pending_summary($pending);
        my $status  = $self -> _process_pending($pending);

        $content = $summary.$status;
    }

    $self -> log("cron", "Cron finished.");

    return $self -> generate_newsagent_page("{L_CRONJOB_TITLE}", $content, $extrahead);
}

1;
