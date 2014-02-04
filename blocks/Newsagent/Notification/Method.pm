## @file
# This file contains the implementation of the method base class.
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
package Newsagent::Notification::Method;

## @class Newsagent::Notification::Method
# A base class for Method modules that provides minimal implementations
# of the interface functions expected by the rest of the system.
#
# Method modules are a real pain, in that they need to contain parts of
# model, view, and controller all in one place. While they could
# conceivably be split into the normal "view/controller in blocks,
# model in modules" setup other modules use, doing so will introduce
# many nasty complications. As a result, the different sections are
# clearly highlighted in an attempt to make the divisions explicit.
#
use strict;
use base qw(Newsagent);

# ============================================================================
#  Constructor

## @cmethod $ new(%args)
# Create a new Method object. This ensures that the method ID has been set, as
# required by Prophesy (and the get_method_config() function).
#
# @param args A hash of arguments to initialise the object with
# @return A blessed reference to the object
sub new {
    my $invocant = shift;
    my $class    = ref($invocant) || $invocant;
    my $self     = $class -> SUPER::new(@_)
        or return undef;

    return Webperl::SystemModule::set_error("No method ID specified when creating an instance of $class")
        if(!$self -> {"method_id"});

    return $self;
}


################################################################################
# Model/support functions
################################################################################

## @method $ get_id()
# Return the ID for this method.
#
# @return The method id.
sub get_id {
    my $self = shift;

    return $self -> {"method_id"};
}


## @method $ get_method_config($name, $default)
# Obtain the specified configuration setting for the current notification
# method.
#
# @param name The name of the configuration option to fetch the value for.
# @return The named configuration option if it is set, otherwise the default
#         (or the empty string if the default is not set). Undef on error.
sub get_method_config {
    my $self    = shift;
    my $name    = shift;
    my $default = shift || "";

    $self -> clear_error();

    my $configh = $self -> {"dbh"} -> prepare("SELECT `value`
                                               FROM `".$self -> {"settings"} -> {"database"} -> {"notify_meth_cfg"}."`
                                               WHERE `method_id` = ?
                                               AND `name` LIKE ?");
    $configh -> execute($self -> {"method_id"}, $name)
        or return $self -> self_error("Unable to execute method config lookup: ".$self -> {"dbh"} -> errstr);

    my $row = $configh -> fetchrow_arrayref();
    return ($row && $row -> [0] ? $row -> [0] : $default);
}


## @method $ set_config($args)
# Set the current configuration to the module to the values in the provided
# args string.
#
# @param args A string containing the new configuration.
# @return true on success, undef on error
sub set_config {
    my $self = shift;
    my $args = shift;

    $self -> clear_error();
    return $self -> self_error("No settings provided") if(!$args);

    $self -> {"args"} = $args;

    my @args = split(/\|/, $self -> {"args"});

    $self -> {"args"} = [];
    foreach my $arg (@args) {
        my @argbits = split(/\;/, $arg);

        my $arghash = {};
        foreach my $argbit (@argbits) {
            my ($name, $value) = $argbit =~ /^(\w+)=(.*)$/;
            $arghash -> {$name} = $value;
        }

        push(@{$self -> {"args"}}, $arghash);
    }

    return 1;
}


## @method $ store_data($articleid, $article, $userid, $is_draft, $recip_methods)
# Store the data for this method. This will store any method-specific
# data in the args hash in the appropriate tables in the database.
#
# @param articleid     The ID of the article to add the notifications for.
# @param article       A reference to a hash containing the article data.
# @param userid        A reference to a hash containing the user's data.
# @param is_draft      True if the article is a draft, false otherwise.
# @param recip_methods A reference to an array containing the recipient/method
#                      map IDs for the recipients this method is being used to
#                      send messages to.
# @return The ID of the notification data row on success, undef on error
sub store_data {
    my $self          = shift;
    my $articleid     = shift;
    my $article       = shift;
    my $userid        = shift;
    my $is_draft      = shift;
    my $recip_methods = shift;

    $self -> clear_error();

    return 0;
}


# @method $ get_data($articleid, $queue)
# Fetch the method-specific data for the current method for the specified
# article. This generates a hash that contains the method's article-specific
# data and returns a reference to it.
#
# @param articleid The ID of the article to fetch the data for.
# @param queue     A reference to the system notification queue object.
# @return A reference to a hash containing the data on success, undef on error
sub get_data {
    my $self      = shift;
    my $articleid = shift;
    my $queue     = shift;

    # Does nothing.
    return {};
}


## @method $ send($article, $recipients, $allrecips)
# Attempt to send the specified article through the current method to the
# specified recipients.
#
# @param article A reference to a hash containing the article to send.
# @param recipients A reference to an array of recipient/emthod hashes.
# @param allrecips A reference to a hash containing the methods being used to
#                  send notifications for this article as keys, and arrays of
#                  recipient names for each method as values.
# @return An overall status for the send, and a reference to an array of
#         {name, state, message} hashes on success, one entry for each
#         recipient, undef on error.
sub send {
    my $self       = shift;
    my $article    = shift;
    my $recipients = shift;
    my $allrecips  = shift;

    $self -> clear_error();

    my @results = ();
    foreach my $recipient (@{$recipients}) {
        # Store the send status.
        push(@results, {"name"    => $recipient -> {"shortname"},
                        "state"   => "error",
                        "message" => "No implementation of send() for this method"});
    }

    return ("error", \@results);
}


## @method $ get_recipient_count($settings)
# Obtain the number of recipients for the notification with the specified settings.
# This should be overridded by any methods that provide meaningful numbers for
# recipient counts (like email).
#
# @param settings The recipient settings to use when determining the count.
# @return -1 for unknown number of recipients, undef on error, otherwise the
#         number of unique recipients.
sub get_recipient_count {
    my $self     = shift;
    my $settings = shift;

    # Base method knows not of these recipient counts.
    return -1;
}


## @method @ get_method_state($articleid)
# Obtain the state, message, and timestamp for the current method for the specified
# article.
#
# @param articleid The ID of the article to fetch the method state for.
# @return Three values: the state, message, and timestamp for the method on
#         success, undefs on error.
sub get_method_state {
    my $self      = shift;
    my $articleid = shift;

    $self -> clear_error();

    my $stateh = $self -> {"dbh"} -> prepare("SELECT status, message, updated
                                              FROM `".$self -> {"settings"} -> {"database"} -> {"article_notify"}."`
                                              WHERE article_id = ? AND method_id = ?");
    $stateh -> execute($articleid, $self -> {"method_id"})
        or return $self -> self_error("Unable to execute notification lookup: ".$self -> {"dbh"} -> errstr());

    my $staterow = $stateh -> fetchrow_arrayref();
    return ("", "", 0) if(!$staterow);

    return @{$staterow};
}


################################################################################
#  View and controller functions
################################################################################


## @method $ generate_compose($args, $user)
# Generate the string to insert into the compose page for this method.
#
# @param args A reference to a hash of arguments to use in the form
# @param user A reference to a hash containing the user's data
# @return A string containing the article form fragment.
sub generate_compose {
    my $self = shift;
    my $args = shift;
    my $user = shift;

    # This method has no special options.
    return "";
}


## @method $ generate_edit($args)
# Generate the string to insert into the edit page for this method.
#
# @param args A reference to a hash of arguments to use in the form
# @return A string containing the article edit form fragment.
sub generate_article_edit {
    my $self = shift;
    my $args = shift;

    return "";
}


## @method $ generate_view($args, $outfields)
# Generate the string to insert into the view page for this method.
#
# @param args      A reference to a hash of arguments to use in the form
# @param outfields A reference to a hash of output values.
# @return A string containing the article view form fragment.
sub generate_article_view {
    my $self      = shift;
    my $args      = shift;
    my $outfields = shift;

    return "";
}


## @method $ validate_article($args, $userid)
# Validate this method's settings in the posted data, and store them in
# the provided args hash.
#
# @param args   A reference to a hash into which the Method's data should be stored.
# @param userid The ID of the user who submitted the form
# @return A reference to an array containing any error articles encountered
#         during validation,
sub validate_article {
    my $self   = shift;
    my $args   = shift;
    my $userid = shift;

    return [];
}


## @method $ generate_notification_state($articleid)
# Generate the fragment to show in the status area of the article list for this method.
#
# @param articleid The ID of article being processed.
# @return A string containing the HTML fragment to show in the status area
sub generate_notification_state {
    my $self      = shift;
    my $articleid = shift;

    my ($state, $message, $timestamp) = $self -> get_method_state($articleid);
    return "Error getting state: ".$self -> errstr() if(!defined($state));

    if($state) {
        return $self -> {"template"} -> load_template("articlelist/status.tem", {"***name***"     => $self -> {"method_name"},
                                                                                 "***id***"       => $self -> {"method_id"},
                                                                                 "***status***"   => $state,
                                                                                 "***statemsg***" => "{L_METHOD_STATE_".uc($state)."}",
                                                                                 "***date***"     => $self -> {"template"} -> fancy_time($timestamp),
                                                                                 "***title***"    => $message || $state,
                                                      });
    }
    return "";
}


1;
