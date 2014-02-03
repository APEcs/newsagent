# @file
# This file contains the implementation of the notification queue model.
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
package Newsagent::System::NotificationQueue;

use strict;
use base qw(Webperl::SystemModule); # This class extends the Newsagent block class
use Webperl::Utils qw(hash_or_hashref);
use v5.12;


## @method $ queue_notification($articleid, $article, $userid, $is_draft, $used_methods)
#
# @param articleid    The ID of the article to add the notifications for.
# @param article      A reference to a hash containing the article data.
# @param userid       A reference to a hash containing the user's data.
# @param is_draft     True if the article is a draft, false otherwise.
# @param used_methods A reference to a hash of used methods. Each key should be the name
#                     of a notification method, and the value for each key should be a
#                     reference to an array of ids for rows in the recipient methods table.
# @return The ID of the article notify row on success, undef on error
sub queue_notification {
    my $self         = shift;
    my $articleid    = shift;
    my $article      = shift;
    my $userid       = shift;
    my $is_draft     = shift;
    my $used_methods = shift;

    $self -> clear_error();

    foreach my $method (keys(%{$used_methods})) {
        my $newid = $self -> _queue_notification($articleid, $article, $userid, $self -> {"methods"} -> {$method} -> get_id(), $is_draft, $used_methods -> {$method})
            or return undef;

        my $dataid = $self -> {"methods"} -> {$method} -> store_data(articleid, $article, $userid, $is_draft, $used_methods -> {$method});


        $self -> set_notification_data($newid, $dataid) or return undef
            if($dataid);

    $self -> set_notification_status($newid, $is_draft ? "draft" : "pending")
        or return undef;




    return $newid;
}


## @method $ cancel_notifications($articleid, $methodid)
# Cancel all notifications for the specified method for the provided article.
#
# @param articleid The ID of the article to cancel notifications for
# @param methodid  An optional ID of the method to cancel the notification for. If
#                  this is not specified, ALL notifications for this article are
#                  cancelled.
# @return true on success, undef on error.
sub cancel_notifications {
    my $self      = shift;
    my $articleid = shift;
    my $methodid  = shift;
    my @params = ();
    my $where  = "";

    $self -> clear_error();

    $self -> _build_param(\@params, \$where, 'WHERE', 'article_id', $article_id  , '=');
    $self -> _build_param(\@params, \$where, 'AND'  , 'method_id' , $method_id_id, '=');

    my $updateh = $self -> {"dbh"} -> prepare("UPDATE `".$self -> {"settings"} -> {"database"} -> {"article_notify"}."`
                                               SET `status` = 'cancelled', `updated` = UNIX_TIMESTAMP()
                                               $where");
    my $rows = $updateh -> execute(@params);
    return $self -> self_error("Unable to update article notification: ".$self -> {"dbh"} -> errstr) if(!$rows);
    # Note that updating no rows here is potentially valid.

    return 1;
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


## @method $ get_notification_status(%args)
# Obtain the status of the specified article notification header. Supported
# arguments are:
#
# - `id`: the id of the notification to get the data for
# - `articleid`: the id of the article to fetch the data for. If set, `methodid` must be set.
# - `methodid`: the id of the method to filter on.
#
# @param args The arguments to use when querying the database.
# @return A reference to a hash containing the article notification header on success,
#         an empty hashref if no matching notification header exists, undef on error.
sub get_notification_status {
    my $self   = shift;
    my $args   = hash_or_hashref(@_);
    my @params;
    my $where  = "";

    $self -> clear_error();

    if($args -> {"id"}) {
        _build_param(\@params, \$where, "WHERE", 'id' , $args -> {'id'});
    } elsif($args -> {"articleid"} && $args -> {"methodid"}) {
        _build_param(\@params, \$where, "WHERE", 'articleid', $args -> {'articleid'});
        _build_param(\@params, \$where, "AND"  , 'methodid' , $args -> {'methodid'});
    } else {
        return $self -> self_error("Incorrect parameters provided to get_notification_status()");
    }

    my $stateh = $self -> {"dbh"} -> prepare("SELECT *
                                              FROM `".$self -> {"settings"} -> {"database"} -> {"article_notify"}."`
                                              $where
                                              LIMIT 1");
    $stateh -> execute(@params)
        or return $self -> self_error("Unable to execute notification lookup: ".$self -> {"dbh"} -> errstr());

    return $stateh -> fetchrow_hashref() || {};
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


sub _queue_notification {
    my $self          = shift;
    my $articleid     = shift;
    my $article       = shift;
    my $userid        = shift;
    my $methodid      = shift;
    my $is_draft      = shift;
    my $send_after    = shift;
    my $recip_methods = shift;

    $self -> clear_error();

    # First create the notification header for this article for the current
    # notification method.
    my $notifyh = $self -> {"dbh"} -> prepare("INSERT INTO `".$self -> {"settings"} -> {"database"} -> {"article_notify"}."`
                                               (article_id, method_id, year_id, updated, send_after)
                                               VALUES(?, ?, ?, UNIX_TIMESTAMP(), ?)");
    my $rows = $notifyh -> execute($articleid, $methodid, $article -> {"notify_matrix"} -> {"year"}, $send_after);
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


sub _build_param {
    my $self   = shift;
    my $params = shift;
    my $where  = shift;
    my $lead   = shift;
    my $field  = shift;
    my $value  = shift;
    my $op     = shift;

    if(defined($value)) {
        push(@{$params}, $value);
        $$where .= " $lead `$field` $op ?";
    }
}

1;
