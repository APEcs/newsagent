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

## @method private $ _notify_author($notify, $result)
# Send an email to the author of the article telling them that the status of
# their message.
#
# @param notify A reference to the notification
# @param result A reference to an array of results.
# @return true on success, undef on error
sub _notify_author {
    my $self   = shift;
    my $notify = shift;
    my $result = shift;

    $self -> clear_error();

    my $article = $self -> {"article"} -> get_article($notify -> {"article_id"})
        or return $self -> self_error($self -> {"article"} -> errstr());

    my $author = $self -> {"session"} -> get_user_byid($article -> {"creator_id"})
        or return $self -> self_error("Unable to obtain author information for message ".$article -> {"id"});

    my $status = "";
    foreach my $row (@{$result}) {
        $status .= $self -> {"template"} -> load_template("article/cron/notify_email_row.tem", {"***name***"    => $row -> {"name"},
                                                                                                "***state***"   => $row -> {"state"},
                                                                                                "***message***" => $row -> {"message"} || "No errors reported",
                                                          });
    }

    $status =  $self -> {"messages"} -> queue_message(subject => $self -> {"template"} -> replace_langvar("CRON_NOTIFY_STATUS", {"***article***" => $article -> {"title"}}),
                                                      message => $self -> {"template"} -> load_template("article/cron/notify_email.tem",
                                                                                                        {"***article***"  => $article -> {"title"},
                                                                                                         "***status***"   => $status,
                                                                                                         "***realname***" => $author -> {"fullname"},
                                                                                                         "***method***"   => $notify -> {"name"},
                                                                                                        }),
                                                      recipients       => [ $author -> {"user_id"} ],
                                                      send_immediately => 1);
    return ($status ? undef : $self -> {"messages"} -> errstr());
}


## @method private $ _build_all_recipients($pending)
# Go through the provided list of pending notifications, and build a list of all
# methods and recipients they will be sent to (for inclusion in messages as a
# "sent to: ..." list).
#
# @param pending A reference to an array of pending article notifications.
# @return A reference to a hash keyed off methods, containing arrays of recipients.
sub _build_all_recipients {
    my $self       = shift;
    my $pending    = shift;
    my $recipients = {};

    $self -> clear_error();

    # Quickly go through the list of pending notifications building the recipients.
    # At this point it doesn't matter if we're actually going to send them here, or if
    # another cron job will grab them: we need to know where they are going regardless.
    foreach my $notify (@{$pending}) {
        my $recipmeths = $self -> {"queue"} -> get_notification_targets($notify -> {"id"}, $notify -> {"year_id"})
            or return $self -> self_error($self -> {"queue"} -> errstr());

        foreach my $dest (@{$recipmeths}) {
            push(@{$recipients -> {$notify -> {"name"}}}, $dest -> {"shortname"});
        }
    }

    return $recipients;
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

    $self -> clear_error();

    my $allrecipients = $self -> _build_all_recipients($pending)
        or return undef;

    foreach my $notify (@{$pending}) {
        $self -> log("cron", "Starting delivery of notification ".$notify -> {"id"});

        # Invoke the sender to do the actual work of dispatching the messages
        my $result = $self -> {"queue"} -> send_pending_notification($notify, $allrecipients);
        if(!defined($result)) {
            $status .= $self -> {"template"} -> load_template("article/cron/status_item.tem", {"***article***" => $notify -> {"article_id"},
                                                                                               "***id***"      => $notify -> {"id"},
                                                                                               "***year***"    => $notify -> {"year_id"},
                                                                                               "***method***"  => $notify -> {"name"},
                                                                                               "***name***"    => "",
                                                                                               "***state***"   => "error",
                                                                                               "***message***" => $self -> {"queue"} -> errstr(),
                                                              });
            $result = [ {"name" => "",
                         "state"   => "error",
                         "message" => "A serious error occurred: ".$self -> {"queue"} -> errstr()} ];
            $self -> log("cron", "Status of notification ".$notify -> {"id"}.": ".$self -> {"queue"} -> errstr());

        } else {
            # Go through the results from the send code, converting to something usable
            # in the page.
            my $failmsg = "";
            foreach my $row (@{$result}) {
                $status .= $self -> {"template"} -> load_template("article/cron/status_item.tem", {"***article***" => $notify -> {"article_id"},
                                                                                                   "***id***"      => $notify -> {"id"},
                                                                                                   "***year***"    => $notify -> {"year_id"},
                                                                                                   "***method***"  => $notify -> {"name"},
                                                                                                   "***name***"    => $row -> {"name"},
                                                                                                   "***state***"   => $row -> {"state"},
                                                                                                   "***message***" => $row -> {"message"},
                                                                  });
                $failmsg .= $row -> {"name"}.": ".$row -> {"message"}."\n"
                    if($row -> {"state"} eq "error");

                $self -> log("cron", "Status of notification ".$notify -> {"id"}.": ".$row -> {"name"}." = ".$row -> {"state"}." (".($row -> {"message"} || "").")");
            }
        }


        # notify the author
        $self -> _notify_author($notify, $result);

        # Update the message status depending on whether errors were encountered
        $self -> log("cron", "Finished delivery of notification ".$notify -> {"id"});
    }

    # return the status string
    return $self -> {"template"} -> load_template("article/cron/status.tem", {"***items***" => $status});
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
        $notify .= $self -> {"template"} -> load_template("article/cron/summary_item.tem", {"***article***" => $entry -> {"article_id"},
                                                                                            "***id***"      => $entry -> {"id"},
                                                                                            "***year***"    => $entry -> {"year_id"},
                                                                                            "***method***"  => $entry -> {"name"},
                                                                                            "***time***"    => $self_error -> {"template"} -> fancy_time($entry -> {"release_time"}),
                                                          });
    }

    return $self -> {"template"} -> load_template("article/cron/summary.tem", {"***items***" => $notify});
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

    $self -> log("cron", "Cron starting.");

    # Fetch the list of pending notifications
    my $pending = $self -> {"queue"} -> get_pending_notifications()
        or return $self -> generate_errorbox($self -> {"queue"} -> errstr());

    if(!scalar(@{$pending})) {
        $self -> log("cron", "No pending notifications to send.");

        $content = $self -> {"template"} -> load_template("article/cron/noitems.tem");
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
