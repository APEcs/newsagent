## @file
# This file contains the implementation of the background message dispatcher.
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
package Newsagent::System::Megaphone;

use strict;
use base qw(Webperl::SystemModule); # This class extends the Newsagent block class
use v5.12;

use Webperl::Message::Queue;
use Webperl::Modules;
use Webperl::Template;
use Newsagent::System;
use Newsagent::System::Feed;
use Newsagent::System::Article;
use Newsagent::System::NotificationQueue;

## @cmethod $ new(%args)
# Create a new Megaphone object to handle background message dispatch.
#
# @param args A hash of key value pairs to initialise the object with.
# @return A new Megaphone object, or undef if a problem occured.
sub new {
    my $invocant = shift;
    my $class    = ref($invocant) || $invocant;
    my $self     = $class -> SUPER::new(@_)
        or return undef;

    $self -> {"system"} = Newsagent::System -> new(dbh      => $self -> {"dbh"},
                                                   logger   => $self -> {"logger"},
                                                   settings => $self -> {"settings"})
        or return Webperl::SystemModule::set_error("Unable to create system: ".$Webperl::SystemModule::errstr);

    $self -> {"messages"} = Webperl::Message::Queue -> new(logger   => $self -> {"logger"},
                                                           dbh      => $self -> {"dbh"},
                                                           settings => $self -> {"settings"})
        or return Webperl::SystemModule::set_error("Megaphone initialisation failed: ".$Webperl::SystemModule::errstr);

    $self -> {"template"} = Webperl::Template -> new(logger    => $self -> {"logger"},
                                                     dbh       => $self -> {"dbh"},
                                                     basedir   => $self -> {"settings"} -> {"config"} -> {"template_dir"} || "templates",
                                                     timefmt   => $self -> {"settings"} -> {"config"} -> {"timefmt"},
                                                     blockname => 1,
                                                     mailcmd   => '/usr/sbin/sendmail -t -f '.$self -> {"settings"} -> {"config"} -> {"Core:envelope_address"},
                                                     settings  => $self -> {"settings"})
        or return Webperl::SystemModule::set_error("Megaphone initialisation failed: ".$Webperl::SystemModule::errstr);

    $self -> {"modules"} = Webperl::Modules -> new(logger   => $self -> {"logger"},
                                                   dbh      => $self -> {"dbh"},
                                                   settings => $self -> {"settings"},
                                                   template => $self -> {"template"},
                                                   blockdir => $self -> {"settings"} -> {"paths"} -> {"blocks"} || "blocks",
                                                   system   => $self -> {"system"},
                                                   messages => $self -> {"messages"})
        or return Webperl::SystemModule::set_error("Megaphone initialisation failed: ".$Webperl::SystemModule::errstr);

    $self -> {"system"} -> init(logger   => $self -> {"logger"},
                                dbh      => $self -> {"dbh"},
                                settings => $self -> {"settings"},
                                template => $self -> {"template"},
                                modules  => $self -> {"modules"},
                                messages => $self -> {"messages"})
        or return Webperl::SystemModule::set_error("Unable to create system: ".$self -> {"system"} -> errstr());

    $self -> {"feed"} = Newsagent::System::Feed -> new(dbh      => $self -> {"dbh"},
                                                       settings => $self -> {"settings"},
                                                       logger   => $self -> {"logger"},
                                                       roles    => $self -> {"system"} -> {"roles"},
                                                       metadata => $self -> {"system"} -> {"metadata"})
        or return Webperl::SystemModule::set_error("Megaphone initialisation failed: ".$Webperl::SystemModule::errstr);

    $self -> {"article"} = Newsagent::System::Article -> new(feed     => $self -> {"feed"},
                                                             dbh      => $self -> {"dbh"},
                                                             settings => $self -> {"settings"},
                                                             logger   => $self -> {"logger"},
                                                             roles    => $self -> {"system"} -> {"roles"},
                                                             metadata => $self -> {"system"} -> {"metadata"})
        or return Webperl::SystemModule::set_error("Megaphone initialisation failed: ".$Webperl::SystemModule::errstr);

    $self -> {"queue"} = Newsagent::System::NotificationQueue -> new(dbh      => $self -> {"dbh"},
                                                                     settings => $self -> {"settings"},
                                                                     logger   => $self -> {"logger"},
                                                                     article  => $self -> {"article"},
                                                                     module   => $self -> {"module"})
        or return Webperl::SystemModule::set_error("Megaphone initialisation failed: ".$Webperl::SystemModule::errstr);


    return $self;
}


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
        $status .= $self -> {"template"} -> load_template("cron/notify_email_row.tem", {"***name***"    => $row -> {"name"},
                                                                                        "***state***"   => $row -> {"state"},
                                                                                        "***message***" => $row -> {"message"} || "No errors reported",
                                                          });
    }

    $status =  $self -> {"messages"} -> queue_message(subject => $self -> {"template"} -> replace_langvar("CRON_NOTIFY_STATUS", {"***article***" => $article -> {"title"}}),
                                                      message => $self -> {"template"} -> load_template("cron/notify_email.tem",
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



## @method private void _schedule_wait(void)
# Wait until the next scheduled post time.
#
sub _schedule_wait {
    my $self = shift;
    my $now  = time();

    # Determine how long the process should wait for.
    my $wakeup = $self -> {"queue"} -> get_next_notification_time($now);
    if($wakeup) {
        my $next_schedule = DateTime -> from_epoch(epoch => $wakeup);
        $self -> {"logger"} -> print(Webperl::Logger::NOTICE, "Next scheduled message is at $next_schedule");

        $wakeup = min($wakeup - $now, $self -> {"settings"} -> {"megaphone"} -> {"default_sleep"})
    } else {
        $wakeup = $self -> {"settings"} -> {"megaphone"} -> {"default_sleep"};
    }

    $self -> {"logger"} -> print(Webperl::Logger::NOTICE, "Sleeping for $wakeup seconds");

    # This sleep should be interrupted if the schedule is updated
    sleep($wakeup);
}


## @method private void _schedule_send()
# Send any pending notifications. This processes all the currently pending messages,
# sending them to the appropriate recipients.
#
sub _schedule_send {
    my $self = shift;

    $self -> {"logger"} -> print(Webperl::Logger::NOTICE, "Checking for pending messages");

    my $pending = $self -> {"queue"} -> get_pending_notifications()
        or $self -> {"logger"} -> die_log("Notification fetch failed: ".$self -> {"queue"} -> errstr());

    $self -> {"logger"} -> print(Webperl::Logger::NOTICE, "Got ".scalar(@{$pending})." pending messages");

    if(scalar(@{$pending})) {
        my $allrecipients = $self -> _build_all_recipients($pending)
            or return undef;

        foreach my $notify (@{$pending}) {
            $self -> {"logger"} -> print(Webperl::Logger::NOTICE, "Starting delivery of notification ".$notify -> {"id"});

            # Invoke the sender to do the actual work of dispatching the messages
            my $result = $self -> {"queue"} -> send_pending_notification($notify, $allrecipients);
            if(!defined($result)) {
                $result = [ {"name" => "",
                             "state"   => "error",
                             "message" => "A serious error occurred: ".$self -> {"queue"} -> errstr()} ];
                $self -> log("cron", "Status of notification ".$notify -> {"id"}.": ".$self -> {"queue"} -> errstr());

            } else {
                foreach my $row (@{$result}) {
                    $self -> {"logger"} -> print(Webperl::Logger::NOTICE, "Status of notification ".$notify -> {"id"}.": ".$row -> {"name"}." = ".$row -> {"state"}." (".($row -> {"message"} || "").")");
                }
            }


            # notify the author
            $self -> _notify_author($notify, $result);

            # Update the message status depending on whether errors were encountered
            $self -> {"logger"} -> print(Webperl::Logger::NOTICE, "Finished delivery of notification ".$notify -> {"id"});
        }
    }
}


sub run {
    my $self = shift;

    while(1) {
        $self -> _schedule_send();
        $self -> _schedule_wait();
    }
}

1;
