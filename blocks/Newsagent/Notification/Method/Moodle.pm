## @file
# This file contains the implementation of the moodle message method.
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
# A moodle method implementation. Supported arguments are:
#
# - forum_id=&lt;fid&gt; - ID of the forum to post to
# - course_id=&lt;cid&gt; - course id the forum resides in
#
# If multiple forum_id/course_id arguments are specified, this will
# insert the message into each forum.
package Newsagent::Notification::Method::Moodle;

use strict;
use base qw(Newsagent::Notification::Method); # This class is a Method module
use Data::Dumper;

################################################################################
# Model/support functions
################################################################################


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

    my $nid = $self -> SUPER::store_article($args, $userid, $articleid, $is_draft, $recip_methods)
        or return undef;

    $self -> set_notification_status($nid, $is_draft ? "draft" : "pending")
        or return undef;

    return $nid;
}


# ============================================================================
#  Article send functions

## @method $ send($article, $recipients)
# Attempt to send the specified article as moodle forum posts.
#
# @param article    A reference to a hash containing the article to send.
# @param recipients A reference to an array of recipient/emthod hashes.
# @return A reference to an array of {name, state, message} hashes on success,
#         on entry for each recipient, undef on error.
sub send {
    my $self       = shift;
    my $article    = shift;
    my $recipients = shift;

    my @results = ();

    # For each recipient, invoke the send
    foreach my $recipient (@{$recipients}) {
        my $result = "error";

        # Settings setup must work first...
        if($self -> set_config($recipient -> {"settings"})) {

            # now do the send
            $result = "sent"
                if($self -> _post_article($article));
        }

        # Store the send status.
        push(@results, {"name"    => $recipient -> {"shortname"},
                        "state"   => $result,
                        "message" => $result eq "error" ? $self -> errstr() : ""});
        $self -> log("Method::Moodle", "Send of article ".$article -> {"id"}." to ".$recipient -> {"shortname"}.": $result (".($result eq "error" ? $self -> errstr() : "").")");
    }

    return \@results;
}


# ============================================================================
#  Private functions

## @method private $ _get_moodle_userid($username)
# Obtain the moodle record for the user with the specified username.
#
# @param username The username of the user to find in moodle's database.
# @return The requested user's userid, or undef if the user does not exist.
sub _get_moodle_userid {
    my $self     = shift;
    my $username = shift;

    $self -> clear_error();

    # Pretty simple query, really...
    my $userh = $self -> {"moodle"} -> prepare("SELECT id FROM ".$self -> get_method_config("users")."
                                                WHERE username LIKE ?");
    $userh -> execute($username)
        or return $self -> self_error("Method::Moodle: Unable to execute user query: ".$self -> {"moodle"} -> errstr);

    my $user = $userh -> fetchrow_arrayref();

    return $user ? $user -> [0] : undef;
}


## @method private $ _post_article($article)
# Attempt to post the article specified to moodle. Note that set_config() must
# be called before calling this to ensure that the forum and course information
# has been set up correctly.
#
# @param article A reference to the article to post to moodle.
# @return true on success, undef on error.
sub _post_article {
    my $self    = shift;
    my $article = shift;

    $self -> clear_error();

    # Get the user's data
    my $user = $self -> {"session"} -> {"auth"} -> get_user_byid($article -> {"creator_id"})
        or return $self -> self_error("Method::Moodle: Unable to get user details for article ".$article -> {"id"});

    # Open the moodle database connection.
    $self -> {"moodle"} = DBI->connect($self -> get_method_config("database"),
                                       $self -> get_method_config("username"),
                                       $self -> get_method_config("password"),
                                       { RaiseError => 0, AutoCommit => 1, mysql_enable_utf8 => 1 })
        or return $self -> self_error("Method::Moodle: Unable to connect to database: ".$DBI::errstr);

    $self -> log("Method::Moodle", "Establised database connection");

    # Look up the user in moodle's user table
    my $moodleuser = $self -> _get_moodle_userid($user -> {"username"})
        or return undef;

    $self -> log("Method::Moodle", "Got moodle user $moodleuser");

    # If we have no user, fall back on the, um, fallback...
    my $fallback = 0;
    if(!$moodleuser) {
        $fallback = 1;
        $moodleuser = $self -> _get_moodle_userid($self -> get_method_config("fallback_user"))
            or return $self -> self_error("Method::Moodle: Unable to obtain a moodle user (username and fallback failed)");
    }

    # Precache queries
    my $discussh = $self -> {"moodle"} -> prepare("INSERT INTO ".$self -> get_method_config("discussions")."
                                                   (course, forum, name, userid, timemodified, usermodified)
                                                   VALUES(?, ?, ?, ?, ?, ?)");

    # Note: format = 1 here is telling moodle that the post is in html format (in theory, the data straight out
    # of the article text should work perfectly)
    my $posth   =  $self -> {"moodle"} -> prepare("INSERT INTO ".$self -> get_method_config("posts")."
                                                  (discussion, userid, created, modified, subject, message, format)
                                                  VALUES(?, ?, ?, ?, ?, ?, 1)");

    my $updateh = $self -> {"moodle"} -> prepare("UPDATE ".$self -> get_method_config("discussions")."
                                                  SET firstpost = ?
                                                  WHERE id = ?");

    # Go through each moodle forum, posting the article there.
    foreach my $arghash (@{$self -> {"args"}}) {
        # Timestamp for posting is now
        my $now = time();

        $self -> log("Method::Moodle", "posting article ".$article -> {"id"}." to forum ".$arghash -> {"forum_id"});

        # Make the discussion
        $discussh -> execute($arghash -> {"course_id"},
                             $arghash -> {"forum_id"},
                             $article -> {"title"},
                             $moodleuser,
                             $now,
                             $moodleuser)
            or return $self -> self_error("Unable to execute discussion insert query: ".$self -> {"moodle"} -> errstr);

        # Get the discussion id
        my $discussid = $self -> {"moodle"} -> {"mysql_insertid"};
        $self -> self_error("Unable to get ID of new discussion. This should not happen.") if(!$discussid);

        # Post the article body
        $posth -> execute($discussid, $moodleuser, $now, $now, $article -> {"title"}, $article -> {"article"})
            or return $self -> self_error("Unable to execute post insert query: ".$self -> {"moodle"} -> errstr);

        # Get the post id..
        my $postid = $self -> {"moodle"} -> {"mysql_insertid"};
        $self -> self_error("Unable to get ID of new post. This should not happen.") if(!$postid);

        # Update the discussion with the post id
        $updateh -> execute($postid, $discussid)
            or return $self -> self_error("Unable to execute discussion update query: ".$self -> {"moodle"} -> errstr);
    }

    # Done talking to moodle now.
    $self -> {"moodle"} -> disconnect();

    return 1;
}

1;
