## @file
# This file contains the implementation of the Tell Us base class.
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
package Newsagent::TellUs;

use strict;
use base qw(Newsagent); # This class extends the Newsagent block class
use Newsagent::System::TellUs;
use Newsagent::System::Feed;
use v5.12;

# ============================================================================
#  Constructor

## @cmethod $ new(%args)
# Overloaded constructor for the TellUs classes, loads the System::TellUs model
# and other classes required to generate message pages.
#
# @param args A hash of values to initialise the object with. See the Block docs
#             for more information.
# @return A reference to a new Newsagent::TellUs object on success, undef on error.
sub new {
    my $invocant = shift;
    my $class    = ref($invocant) || $invocant;
    my $self     = $class -> SUPER::new(@_)
        or return undef;

    $self -> {"tellus"} = Newsagent::System::TellUs -> new(dbh      => $self -> {"dbh"},
                                                           settings => $self -> {"settings"},
                                                           logger   => $self -> {"logger"},
                                                           roles    => $self -> {"system"} -> {"roles"},
                                                           metadata => $self -> {"system"} -> {"metadata"})
        or return Webperl::SystemModule::set_error("TellUs initialisation failed: ".$Webperl::SystemModule::errstr);

    $self -> {"feed"} = Newsagent::System::Feed -> new(dbh      => $self -> {"dbh"},
                                                       settings => $self -> {"settings"},
                                                       logger   => $self -> {"logger"},
                                                       roles    => $self -> {"system"} -> {"roles"},
                                                       metadata => $self -> {"system"} -> {"metadata"})
        or return Webperl::SystemModule::set_error("Feed initialisation failed: ".$Webperl::SystemModule::errstr);

    $self -> {"state"} = [ {"value" => "new",
                            "name"  => "{L_TELLUS_NEW}" },
                           {"value" => "viewed",
                            "name"  => "{L_TELLUS_VIEWED}" },
                           {"value" => "rejected",
                            "name"  => "{L_TELLUS_REJECTED}" },
        ];

    $self -> {"allow_tags"} = [
        "a", "b", "blockquote", "br", "caption", "col", "colgroup", "comment",
        "em", "h1", "h2", "h3", "h4", "h5", "h6", "hr", "li", "ol", "p",
        "pre", "small", "span", "strong", "sub", "sup", "table", "tbody", "td",
        "tfoot", "th", "thead", "tr", "tt", "ul",
        ];

    $self -> {"tag_rules"} = [
        a => {
            href   => qr{^(?:http|https)://}i,
            name   => 1,
            '*'    => 0,
        },
        table => {
            cellspacing => 1,
            cellpadding => 1,
            style       => 1,
            class       => 1,
            '*'         => 0,
        },
        td => {
            colspan => 1,
            rowspan => 1,
            style   => 1,
            '*'     => 0,
        },
        blockquote => {
            cite  => qr{^(?:http|https)://}i,
            style => 1,
            '*'   => 0,
        },
        span => {
            class => 1,
            style => 1,
            title => 1,
            '*'   => 0,
        },
        div => {
            class => 1,
            style => 1,
            title => 1,
            '*'   => 0,
        },
        img => {
            src    => 1,
            class  => 1,
            alt    => 1,
            width  => 1,
            height => 1,
            style  => 1,
            title  => 1,
            '*'    => 0,
        },
        ];

    return $self;
}

# ============================================================================
#  Feed access

## @method private $ _get_feeds()
# Generate the options to show in the suggested feed dropdown.
#
# @return A reference to an array of hashes containing the feed list.
sub _get_feeds {
    my $self = shift;

    my $feeds = $self -> {"feed"} -> get_feeds();
    my @values = ();
    foreach my $feed (@{$feeds}) {
        push(@values, { "id"   => $feed -> {"id"},
                        "name" => $feed -> {"name"},
                        "desc" => $feed -> {"description"}});
    }

    return \@values;
}


# ============================================================================
#  Validation code

## @method private $ _validate_message_fields($args, $userid)
# Validate the contents of the fields in the message form. This will validate the
# fields, and perform any background file-wrangling operations necessary to deal
# with the submitted images (if any).
#
# @param args   A reference to a hash to store validated data in.
# @param userid The ID of the user submitting the form.
# @return empty string on success, otherwise an error string.
sub _validate_message_fields {
    my $self   = shift;
    my $args   = shift;
    my $userid = shift;
    my ($errors, $error) = ("", "");

    my $queues = $self -> {"tellus"} -> get_queues($userid, "additem");
    my $types  = $self -> {"tellus"} -> get_types();
    my $feeds  = $self -> {"feed"}   -> get_feeds();

    #

    ($args -> {"message"}, $error) = $self -> validate_htmlarea("message", {"required"   => 1,
                                                                            "minlen"     => 8,
                                                                            "nicename"   => $self -> {"template"} -> replace_langvar("TELLUS_DESC"),
                                                                            "validate"   => $self -> {"config"} -> {"Core:validate_htmlarea"},
                                                                            "allow_tags" => $self -> {"allow_tags"},
                                                                            "tag_rules"  => $self -> {"tag_rules"}});
    $errors .= $self -> {"template"} -> load_template("error/error_item.tem", {"***error***" => $error}) if($error);

    ($args -> {"type"}, $error) = $self -> validate_options("type", {"required" => 1,
                                                                     "default"  => "1",
                                                                     "source"   => $types,
                                                                     "nicename" => $self -> {"template"} -> replace_langvar("TELLUS_TYPE")});
    $errors .= $self -> {"template"} -> load_template("error/error_item.tem", {"***error***" => $error}) if($error);

    ($args -> {"queue"}, $error) = $self -> validate_options("queue", {"required" => 1,
                                                                       "default"  => "1",
                                                                       "source"   => $queues,
                                                                       "nicename" => $self -> {"template"} -> replace_langvar("TELLUS_QUEUE")});
    $errors .= $self -> {"template"} -> load_template("error/error_item.tem", {"***error***" => $error}) if($error);

    return $errors;
}


## @method private $ _validate_message($messageid)
# Validate the message data submitted by the user, and potentially add
# a new message to the system. Note that this will not return if the message
# fields validate; it will redirect the user to the new message and exit.
#
# @param messageid Optional message ID used when doing edits. Note that the
#                  caller must ensure this ID is valid and the user can edit it.
# @return An error message, and a reference to a hash containing
#         the fields that passed validation.
sub _validate_message {
    my $self      = shift;
    my $messageid = shift;
    my ($args, $errors, $error) = ({}, "", "", undef);
    my $userid = $self -> {"session"} -> get_session_userid();

    $error = $self -> _validate_message_fields($args, $userid);
    $errors .= $error if($error);

    # Give up here if there are any errors
    return ($self -> {"template"} -> load_template("error/error_list.tem", {"***message***" => "{L_TELLUS_FAILED}",
                                                                            "***errors***"  => $errors}), $args)
        if($errors);

    my $aid = $self -> {"tellus"} -> add_message($args, $userid)
        or return ($self -> {"template"} -> load_template("error/error_list.tem", {"***message***" => "{L_TELLUS_FAILED}",
                                                                                   "***errors***"  => $self -> {"template"} -> load_template("error/error_item.tem",
                                                                                                                                             {"***error***" => $self -> {"tellus"} -> errstr()
                                                                                                                                             })
                                                          }), $args);


    $self -> log("tellus", "Added tellus message $aid");

    # Send notifications to queue notification targets
    $self -> _notify_add_queue($aid);

    # And the creator
    $self -> _notify_add_creator($aid);

    # redirect to a success page
    # Doing this prevents page reloads adding multiple message copies!
    print $self -> {"cgi"} -> redirect($self -> build_url(pathinfo => ["success"]));
    exit;
}


# ============================================================================
#  Notification code

## @method private $ _notify_add_queue($messageid)
# Send notifications to the users who are responsible for the queue specified that
# a new message has been added to their queue.
#
# @param messageid The ID of the message added to the queue.
# @return true on success, undef on error.
sub _notify_add_queue {
    my $self      = shift;
    my $messageid = shift;

    $self -> clear_error();

    # Get the current user's info
    my $user = $self -> {"session"} -> get_user_byid();

    # Get the message information, that will contain almost all the information needed for the email
    my $message = $self -> {"tellus"} -> get_message($messageid)
        or return $self -> self_error("Unable to fetch message data: ".$self -> {"tellus"} -> errstr());

    # Need the list of people to notify in addition to the message data.
    my $recipients = $self -> {"tellus"} -> get_queue_notify_recipients($message -> {"queue_id"})
        or return $self -> self_error("Unable to fetch queue recipients: ".$self -> {"tellus"} -> errstr());

    # No point doing anything if there are not recipients to notify
    if(!scalar(@{$recipients})) {
        $self -> log("tellus.add", "No notification recipients for '".$message -> {"queuename"}."' - no notifications sent");
        return 1;
    }

    my $summary = $self -> {"template"} -> html_strip($message -> {"message"});
    $summary = $self -> truncate_text($summary, 240);
    $summary =~ s/^/> /gm;

    $self -> log("tellus:add", "Sending new queued message notifications to ".join(",", @{$recipients}));

    my $status =  $self -> {"messages"} -> queue_message(subject => $self -> {"template"} -> replace_langvar("TELLUS_EMAIL_MSGSUB", {"***queue***" => $message -> {"queuename"}} ),
                                                         message => $self -> {"template"} -> load_template("tellus/email/newqueuemsg.tem",
                                                                                                           {"***movename***"   => $user -> {"realname"},
                                                                                                            "***movemail***"   => $user -> {"email"},
                                                                                                            "***fullname***"   => $message -> {"realname"},
                                                                                                            "***email***"      => $message -> {"email"},
                                                                                                            "***queuename***"  => $message -> {"queuename"},
                                                                                                            "***typename***"   => $message -> {"typename"},
                                                                                                            "***summary***"    => $summary,
                                                                                                            "***manage_url***" => $self -> build_url("block"    => "queues",
                                                                                                                                                     "pathinfo" => [ lc($message -> {"queuename"}) ],
                                                                                                                                                     "api"      => [],
                                                                                                                                                     "fullurl"  => 1),
                                                                                                           }),
                                                         recipients       => $recipients,
                                                         send_immediately => 1);
    return $self -> self_error("Unable to send queue notification: $status")
        if($status);

    return 1;
}


## @method private $ _notify_add_creator($messageid)
# Send a notification to the creator of the specified message telling them that
# their message has been added to the system.
#
# @param messageid The ID of the new message.
# @return true on success, undef on error.
sub _notify_add_creator {
    my $self      = shift;
    my $messageid = shift;

    $self -> clear_error();

    # Get the message information, that will contain almost all the information needed for the email
    my $message = $self -> {"tellus"} -> get_message($messageid)
        or return $self -> self_error("Unable to fetch message data: ".$self -> {"tellus"} -> errstr());

    my $summary = $self -> {"template"} -> html_strip($message -> {"message"});
    $summary = $self -> truncate_text($summary, 240);
    $summary =~ s/^/> /gm;

    $self -> log("tellus:add", "Sending message creation notification to ".$message -> {"email"});

    my $status =  $self -> {"messages"} -> queue_message(subject => $self -> {"template"} -> replace_langvar("TELLUS_EMAIL_CREATESUB"),
                                                         message => $self -> {"template"} -> load_template("tellus/email/createnewmsg.tem",
                                                                                                           {"***fullname***"   => $message -> {"realname"},
                                                                                                            "***email***"      => $message -> {"email"},
                                                                                                            "***queuename***"  => $message -> {"queuename"},
                                                                                                            "***typename***"   => $message -> {"typename"},
                                                                                                            "***summary***"    => $summary
                                                                                                           }),
                                                         recipients       => [ $message -> {"creator_id"} ],
                                                         send_immediately => 1);
    return $self -> self_error("Unable to send creation notification: $status")
        if($status);

    return 1;
}


## @method private $ _notify_move_queue($messageid)
# Send a notification to the creator of the specified message telling them that
# their message has been moved to another queue. Note that this should be called
# *after* the message has been moved so that it can pick up the new queue data.
#
# @param messageid The ID of the message moved to a new queue.
# @return true on success, undef on error.
sub _notify_move_queue {
    my $self      = shift;
    my $messageid = shift;

    $self -> clear_error();

    # Get the current user's info
    my $user = $self -> {"session"} -> get_user_byid();

    # Get the message information, that will contain almost all the information needed for the email
    my $message = $self -> {"tellus"} -> get_message($messageid)
        or return $self -> self_error("Unable to fetch message data: ".$self -> {"tellus"} -> errstr());

    my $summary = $self -> {"template"} -> html_strip($message -> {"message"});
    $summary = $self -> truncate_text($summary, 240);
    $summary =~ s/^/> /gm;

    $self -> log("tellus:move", "Sending message move notifications to ".$message -> {"email"});

    my $status =  $self -> {"messages"} -> queue_message(subject => $self -> {"template"} -> replace_langvar("TELLUS_EMAIL_MOVESUB"),
                                                         message => $self -> {"template"} -> load_template("tellus/email/movemsg.tem",
                                                                                                           {"***movename***"   => $user -> {"realname"},
                                                                                                            "***movemail***"   => $user -> {"email"},
                                                                                                            "***fullname***"   => $message -> {"realname"},
                                                                                                            "***email***"      => $message -> {"email"},
                                                                                                            "***queuename***"  => $message -> {"queuename"},
                                                                                                            "***typename***"   => $message -> {"typename"},
                                                                                                            "***summary***"    => $summary
                                                                                                           }),
                                                         recipients       => [ $message -> {"creator_id"} ],
                                                         send_immediately => 1);
    return $self -> self_error("Unable to send queue move notification: $status")
        if($status);

    return 1;
}


## @method private $ _notify_reject($messageid, $reason)
# Send a notification to the creator of the specified message telling them that
# their message has been rejected.
#
# @param messageid The ID of the rejected message.
# @param reason    The reason to include in the rejection message.
# @return true on success, undef on error.
sub _notify_reject {
    my $self      = shift;
    my $messageid = shift;
    my $reason    = shift;

    $self -> clear_error();

    # Get the current user's info
    my $user = $self -> {"session"} -> get_user_byid();

    # Get the message information, that will contain almost all the information needed for the email
    my $message = $self -> {"tellus"} -> get_message($messageid)
        or return $self -> self_error("Unable to fetch message data: ".$self -> {"tellus"} -> errstr());

    my $summary = $self -> {"template"} -> html_strip($message -> {"message"});
    $summary = $self -> truncate_text($summary, 240);
    $summary =~ s/^/> /gm;

    $self -> log("tellus:reject", "Sending message rejection notifications to ".$message -> {"email"});

    my $status =  $self -> {"messages"} -> queue_message(subject => $self -> {"template"} -> replace_langvar("TELLUS_EMAIL_REJSUB"),
                                                         message => $self -> {"template"} -> load_template("tellus/email/rejectedmsg.tem",
                                                                                                           {"***rejname***"    => $user -> {"realname"},
                                                                                                            "***rejemail***"   => $user -> {"email"},
                                                                                                            "***reason***"     => $reason,
                                                                                                            "***fullname***"   => $message -> {"realname"},
                                                                                                            "***email***"      => $message -> {"email"},
                                                                                                            "***queuename***"  => $message -> {"queuename"},
                                                                                                            "***typename***"   => $message -> {"typename"},
                                                                                                            "***summary***"    => $summary
                                                                                                           }),
                                                         recipients       => [ $message -> {"creator_id"} ],
                                                         send_immediately => 1);
    return $self -> self_error("Unable to send rejection notification: $status")
        if($status);

    return 1;
}

1;
