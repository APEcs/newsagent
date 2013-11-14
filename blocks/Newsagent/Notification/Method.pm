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


## @method $ store_article($args, $userid, $articleid, $is_draft, $recip_methods)
# Store the data for this method. This will store any method-specific
# data in the args hash in the appropriate tables in the database.
#
# @param args          A reference to a hash containing the article data.
# @param userid        A reference to a hash containing the user's data.
# @param articleid     The ID of the article being stored.
# @param is_draft      True if the article is a draft, false otherwise.
# @param recip_methods A reference to an array containing the recipient/method
#                      map IDs for the recipients this method is being used to
#                      send messages to.
# @return The ID of the article notify row on success, undef on error
sub store_article {
    my $self          = shift;
    my $args          = shift;
    my $userid        = shift;
    my $articleid     = shift;
    my $is_draft      = shift;
    my $recip_methods = shift;

    $self -> clear_error();

    # First create the notification header for this article for the current
    # notification method.
    my $notifyh = $self -> {"dbh"} -> prepare("INSERT INTO `".$self -> {"settings"} -> {"database"} -> {"article_notify"}."`
                                               (article_id, method_id, year_id, updated)
                                               VALUES(?, ?, ?, UNIX_TIMESTAMP())");
    my $rows = $notifyh -> execute($articleid, $self -> {"method_id"}, $args -> {"notify_matrix"} -> {"year"});
    return $self -> self_error("Unable to perform article notification insert: ". $self -> {"dbh"} -> errstr) if(!$rows);
    return $self -> self_error("Article notification insert failed, no rows inserted") if($rows eq "0E0");

    # FIXME: This ties to MySQL, but is more reliable that last_insert_id in general.
    #        Try to find a decent solution for this mess...
    # NOTE: the DBD::mysql documentation doesn't actually provide any useful information
    #       about what this will contain if the insert fails. In fact, DBD::mysql calls
    #       libmysql's mysql_insert_id(), which returns 0 on error (last insert failed).
    #       There, why couldn't they bloody /say/ that?!
    my $newid = $self -> {"dbh"} -> {"mysql_insertid"};

    return $self -> self_error("Unable to obtain id for new article notification row")
        if(!$newid);

    # Now there needs to be recipient/method map maps set up to tell this notification
    # method which recipients it needs to be sending to, and how
    my $rmmaph = $self -> {"dbh"} -> prepare("INSERT INTO `".$self -> {"settings"} -> {"database"} -> {"article_notify_rms"}."`
                                              (article_notify_id, recip_meth_id)
                                              VALUES(?, ?)");

    foreach my $rmid (@{$recip_methods}) {
        $rows = $rmmaph -> execute($newid, $rmid);
        return $self -> self_error("Unable to perform article notification rm map insert: ". $self -> {"dbh"} -> errstr) if(!$rows);
        return $self -> self_error("Article notification rm map insert failed, no rows inserted") if($rows eq "0E0");
    }

    return $newid;
}


## @method $ get_article($articleid)
# Fetch the method-specific data for the current method for the specified
# article. This generates a hash that contains the method's article-specific
# data and returns a reference to it.
#
# @param articleid The ID of the article to fetch the data for.
# @return A reference to a hash containing the data on success, undef on error
sub get_article {
    my $self      = shift;
    my $articleid = shift;

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
# @return A reference to an array of {name, state, message} hashes on success,
#         on entry for each recipient, undef on error.
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

    return \@results;
}


## @method $ set_notification_data($nid, $dataid)
# Update the data id contained in the specified notification header.
#
# @param nid    The ID of the article notification header.
# @param dataid The ID of the data row to associate with this header.
# @return true on success, undef on error.
sub set_notification_data {
    my $self   = shift;
    my $nid    = shift;
    my $dataid = shift;

    $self -> clear_error();

    my $updateh = $self -> {"dbh"} -> prepare("UPDATE `".$self -> {"settings"} -> {"database"} -> {"article_notify"}."`
                                               SET `data_id` = ?
                                               WHERE id = ?");
    my $rows = $updateh -> execute($dataid, $nid);
    return $self -> self_error("Unable to update article notification: ".$self -> {"dbh"} -> errstr) if(!$rows);
    return $self -> self_error("Article notification update failed: no rows updated.") if($rows eq "0E0");

    return 1;
}


## @method $ set_notification_status($nid, $status, $message)
# Update the status for the specified article notification header.
#
# @param nid     The ID of the article notification header.
# @param status  The new status to set.
# @param message The message to set for the new status
# @return true on success, undef on error
sub set_notification_status {
    my $self    = shift;
    my $nid     = shift;
    my $status  = shift;
    my $message = shift;

    $self -> clear_error();

    my $updateh = $self -> {"dbh"} -> prepare("UPDATE `".$self -> {"settings"} -> {"database"} -> {"article_notify"}."`
                                               SET `status` = ?, `message` = ?, `updated` = UNIX_TIMESTAMP()
                                               WHERE id = ?");
    my $rows = $updateh -> execute($status, $message, $nid);
    return $self -> self_error("Unable to update article notification: ".$self -> {"dbh"} -> errstr) if(!$rows);
    return $self -> self_error("Article notification update failed: no rows updated.") if($rows eq "0E0");

    return 1;
}


## @method $ get_notification_status($nid)
# Obtain the status of the specified article notification header.
#
# @param nid     The ID of the article notification header.
# @return true on success, undef on error
sub get_notification_status {
    my $self    = shift;
    my $nid     = shift;

    $self -> clear_error();

    my $stateh = $self -> {"dbh"} -> prepare("SELECT status, message, updated
                                              FROM `".$self -> {"settings"} -> {"database"} -> {"article_notify"}."`
                                              WHERE id = ?");
    $stateh -> execute($nid)
        or return $self -> self_error("Unable to execute notification lookup: ".$self -> {"dbh"} -> errstr());

    my $staterow = $stateh -> fetchrow_arrayref();
    return ("", "", 0) if(!$staterow);

    return @{$staterow};
}


## @method $ get_notification_targets($nid, $yid)
# Obtain a list of the targets this notification should be sent to.
#
# @param nid The ID of the article notification header.
# @param yid The ID of the year to fetch any year-specific data for.
# @return A reference to an array of target hashes on success, undef on error
sub get_notification_targets {
    my $self = shift;
    my $nid  = shift;
    my $yid  = shift;

    $self -> clear_error();

    # First, get the list of recipients 'as-is'
    my $reciph = $self -> {"dbh"} -> prepare("SELECT `rm`.`id`, `r`.`name`, `r`.`shortname`, `rm`.`settings`
                                              FROM `".$self -> {"settings"} -> {"database"} -> {"article_notify_rms"}."` AS `a`,
                                                   `".$self -> {"settings"} -> {"database"} -> {"notify_matrix"}."` AS `rm`,
                                                   `".$self -> {"settings"} -> {"database"} -> {"notify_recipients"}."` AS `r`
                                              WHERE `r`.`id` = `rm`.`recipient_id`
                                              AND `rm`.`id` = `a`.`recip_meth_id`
                                              AND `a`.`article_notify_id` = ?");
    $reciph -> execute($nid)
        or return $self -> self_error("Unable to perform recipient method lookup: ".$self -> {"dbh"} -> errstr);

    my $targets = $reciph -> fetchall_arrayref({});

    # Query to fetch any year data if needed
    my $yearh = $self -> {"dbh"} -> prepare("SELECT `settings`
                                             FROM `".$self -> {"settings"} -> {"database"} -> {"notify_matrix_cfg"}."`
                                             WHERE `rm_id` = ?
                                             AND `year_id` = ?");
    foreach my $target (@{$targets}) {
        $yearh -> execute($target -> {"id"}, $yid)
            or return $self -> self_error("Unable to perform recipient method year data lookup: ".$self -> {"dbh"} -> errstr);

        # If there are year-specific settings, override the basic ones
        my $settings = $yearh -> fetchrow_arrayref();
        $target -> {"settings"} = $settings -> [0]
            if($settings && $settings -> [0]);

        # Do any year id substitutions needed
        $target -> {"settings"} =~ s/\{V_\[yearid\]\}/$yid/g;
    }

    return $targets;
}


## @method $ get_notification_dataid($articleid)
# Given an article ID, fetch the data id for the current method from it.
#
# @param articleid The ID of the article to fetch the notification data for.
# @return The ID of the data row (or zero, if there is no data) on success, undef
#         on error.
sub get_notification_dataid {
    my $self = shift;
    my $articleid = shift;

    $self -> clear_error();

    my $headh = $self -> {"dbh"} -> prepare("SELECT data_id
                                             FROM `".$self -> {"settings"} -> {"database"} -> {"article_notify"}."`
                                             WHERE `article_id` = ?
                                             AND `method_id` = ?");
    $headh -> execute($articleid, $self -> {"method_id"})
        or return $self -> self_error("Unable to execute notification header lookip: ".$self -> {"dbh"} -> errstr());

    my $dataid = $headh -> fetchrow_arrayref();
    return 0 if(!$dataid || !$dataid -> [0]);  # not having any data is not an error, just does nothing

    return $dataid -> [0];
}


## @method $ cancel_notifications($articleid)
# Cancel all notifications for the specified method for the provided article.
#
# @param articleid The ID of the article to cancel notifications for
# @return true on success, undef on error.
sub cancel_notifications {
    my $self      = shift;
    my $articleid = shift;

    $self -> clear_error();

    my $updateh = $self -> {"dbh"} -> prepare("UPDATE `".$self -> {"settings"} -> {"database"} -> {"article_notify"}."`
                                               SET `status` = 'cancelled', `updated` = UNIX_TIMESTAMP()
                                               WHERE article_id = ? AND method_id = ?");
    my $rows = $updateh -> execute($articleid, $self -> {"method_id"});
    return $self -> self_error("Unable to update article notification: ".$self -> {"dbh"} -> errstr) if(!$rows);
    # Note that updating no rows here is valid - there may be no notification set for a given method

    return 1;
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


## @method $ generate_articlelist_ops($article, $args)
# Generate the fragment to display in the 'ops' column of the user
# article list for the specified article.
#
# @param article The article being processed.
# @param args    Additional arguments to use when filling in fragment templates.
# @return A string containing the HTML fragment to show in the ops column.
sub generate_articlelist_ops {
    my $self    = shift;
    my $article = shift;
    my $args    = shift;

    return "";
}


## @method $ known_op()
# Determine whether the method module can understand the operation specified
# in the query string. This function allows UserArticles to determine which
# Method modules understand operations added by methods during generate_articlelist_ops().
#
# @return true if the Method module can understand the operation, false otherwise.
sub known_op {
    my $self = shift;

    return 0;
}


## @method @ process_op($article)
# Perform the query-stringspecified operation on a article. This allows Method
# modules to implement the operations added as part of generate_articlelist_ops().
#
# @param article A reference to a hash containing the article data.
# @return A string containing a status update article to show above the list, and
#         a flag specifying whether the returned string is an error article or not.
sub process_op {
    my $self    = shift;
    my $article = shift;

    return ("", 0);
}

1;
