## @file
# This file contains the implementation of the Twitter message method.
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
#
package Newsagent::Notification::Method::Twitter;

use strict;
use base qw(Newsagent::Notification::Method); # This class is a Method module
use v5.12;

use Data::Dumper;

## @cmethod Newsagent::Notification::Method::Twitter new(%args)
# Create a new Twitter object. This will create an object
# that may be used to send messages to recipients over SMTP.
#
# @param args A hash of arguments to initialise the Twitter
#             object with.
# @return A new Twitter object.
sub new {
    my $invocant = shift;
    my $class    = ref($invocant) || $invocant;
    my $self     = $class -> SUPER::new(@_)
        or return undef;

    # Make local copies of the config for readability

    # Possible twitter text modes
    $self -> {"twittermodes"} = [ {"value" => "summary",
                                   "name"  => "{L_METHOD_TWEET_MODE_SUMM}",
                                  },
                                  {"value" => "custom",
                                   "name"  => "{L_METHOD_TWEET_MODE_OWN}",
                                  },
                                ];
    $self -> {"twitterauto"}  = [ {"value" => "link",
                                   "name"  => "{L_METHOD_TWEET_AUTO_LINK}",
                                  },
                                  {"value" => "news",
                                   "name"  => "{L_METHOD_TWEET_AUTO_NEWS}",
                                  },
                                  {"value" => "none",
                                   "name"  => "{L_METHOD_TWEET_AUTO_NONE}",
                                  },
                                ];

    return $self;
}

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

    my $emailh = $self -> {"dbh"} -> prepare("INSERT INTO `".$self -> {"settings"} -> {"method:twitter"} -> {"data"}."`
                                              (mode, auto, tweet)
                                              VALUES(?, ?, ?)");
    my $rows = $emailh -> execute($args -> {"methods"} -> {"Twitter"} -> {"mode"},
                                  $args -> {"methods"} -> {"Twitter"} -> {"auto"},
                                  $args -> {"methods"} -> {"Twitter"} -> {"tweet"});
    return $self -> self_error("Unable to perform article twitter notification data insert: ". $self -> {"dbh"} -> errstr) if(!$rows);
    return $self -> self_error("Article twitter notification data insert failed, no rows inserted") if($rows eq "0E0");
    my $dataid = $self -> {"dbh"} -> {"mysql_insertid"};

    return $self -> self_error("Unable to obtain id for new twitter email notification data row")
        if(!$dataid);

    $self -> set_notification_data($nid, $dataid)
        or return undef;

    # Finally, enable the notification
    $self -> set_notification_status($nid, $is_draft ? "draft" : "pending")
        or return undef;

    return $nid;
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

    $self -> clear_error();

    my $dataid = $self -> get_notification_dataid($articleid)
        or return $self -> self_error("Unable to get email settings for $articleid: ".($self -> errstr() || "No data stored"));

    my $datah = $self -> {"dbh"} -> prepare("SELECT *
                                             FROM `".$self -> {"settings"} -> {"method:twitter"} -> {"data"}."`
                                             WHERE id = ?");
    $datah -> execute($dataid)
        or return $self -> self_error("Unable to perform data lookup: ".$self -> {"dbh"} -> errstr);

    return $datah -> fetchrow_hashref()
        or return $self -> self_error("No email-specific settings for article $articleid");
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

    print STDERR "Article: ".Dumper($article);
    print STDERR "Recips: ".Dumper($recipients);
    print STDERR "Allrecip: ".Dumper($allrecips);




    return $self -> self_error("Not implemented");
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

    return $self -> {"template"} -> load_template("Notification/Method/Twitter/compose.tem", {"***twitter-mode***" => $self -> {"template"} -> build_optionlist($self -> {"twittermodes"}, $args -> {"methods"} -> {"Twitter"} -> {"mode"}),
                                                                                              "***twitter-text***" => $self -> {"template"} -> html_clean($args -> {"methods"} -> {"Twitter"} -> {"tweet"}),
                                                                                              "***twitter-auto***" => $self -> {"template"} -> build_optionlist($self -> {"twitterauto"}, $args -> {"methods"} -> {"Twitter"} -> {"auto"}),
                                                  });
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
    my $error  = shift;
    my @errors = ();

    ($args -> {"methods"} -> {"Twitter"} -> {"mode"}, $error) = $self -> validate_options("twitter-mode", {"required" => 1,
                                                                                                           "default"  => "summary",
                                                                                                           "source"   => $self -> {"twittermodes"},
                                                                                                           "nicename" => $self -> {"template"} -> replace_langvar("METHOD_TWITTER_MODE")});
    push(@errors, $error) if($error);

    ($args -> {"methods"} -> {"Twitter"} -> {"auto"}, $error) = $self -> validate_options("twitter-auto", {"required" => 1,
                                                                                                           "default"  => "link",
                                                                                                           "source"   => $self -> {"twitterauto"},
                                                                                                           "nicename" => $self -> {"template"} -> replace_langvar("METHOD_TWITTER_AUTO")});
    push(@errors, $error) if($error);

    ($args -> {"methods"} -> {"Twitter"} -> {"tweet"}, $error) = $self -> validate_string("twitter-text", {"required" => $args -> {"methods"} -> {"Twitter"} -> {"mode"} eq "custom",
                                                                                                           "maxlen"   => 140,
                                                                                                           "nicename" => $self -> {"template"} -> replace_langvar("METHOD_TWITTER_AUTO")});
    push(@errors, $error) if($error);

    return \@errors;
}

1;
