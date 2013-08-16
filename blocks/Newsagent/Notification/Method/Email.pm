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
#
package Newsagent::Notification::Method::Email;

use strict;
use base qw(Newsagent::Notification::Method); # This class is a Method module
use Email::Valid;
use HTML::Entities;


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

    my $emailh = $self -> {"dbh"} -> prepare("INSERT INTO `".$self -> {"settings"} -> {"method:email"} -> {"data"}."`
                                              (prefix_id, cc, bcc, reply_to)
                                              VALUES(?, ?, ?, ?)");
    my $rows = $emailh -> execute($args -> {"methods"} -> {"Email"} -> {"prefix_id"},
                                  $args -> {"methods"} -> {"Email"} -> {"cc"},
                                  $args -> {"methods"} -> {"Email"} -> {"bcc"},
                                  $args -> {"methods"} -> {"Email"} -> {"reply_to"});
    return $self -> self_error("Unable to perform article email notification data insert: ". $self -> {"dbh"} -> errstr) if(!$rows);
    return $self -> self_error("Article email notification data insert failed, no rows inserted") if($rows eq "0E0");
    my $dataid = $self -> {"dbh"} -> {"mysql_insertid"};

    return $self -> self_error("Unable to obtain id for new article email notification data row")
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
                                             FROM `".$self -> {"settings"} -> {"method:email"} -> {"data"}."`
                                             WHERE id = ?");
    $datah -> execute($dataid)
        or return $self -> self_error("Unable to perform data lookup: ".$self -> {"dbh"} -> errstr);

    return $datah -> fetchrow_hashref()
        or return $self -> self_error("No email-specific settings for article $articleid");
}


## @method $ send($article, $recipients)
# Attempt to send the specified article through the current method to the
# specified recipients.
#
# @param article A reference to a hash containing the article to send.
# @param recipients A reference to an array of recipient/emthod hashes.
# @return A reference to an array of {name, state, message} hashes on success,
#         on entry for each recipient, undef on error.
sub send {
    my $self       = shift;
    my $article    = shift;
    my $recipients = shift;

    $self -> clear_error();

    # First, need the email-specific data for the article
    $article -> {"methods"} -> {"Email"} = $self -> get_article($article -> {"id"})
        or return undef;

    # Start building the recipient lists
    my $addresses = { "reply_to" => $article -> {"methods"} -> {"Email"} -> {"reply_to"},
                      "cc"       => {},
                      "bcc"      => {}};

    # Pull the addresses out of address lists, if specified.
    $self -> _parse_recipients_addrlist($addresses -> {"cc"} , $article -> {"methods"} -> {"Email"} -> {"cc"});
    $self -> _parse_recipients_addrlist($addresses -> {"bcc"}, $article -> {"methods"} -> {"Email"} -> {"bcc"});

    # Process each of the recipients, parsing the configuration and then merging recipient addresses
    foreach my $recipient (@{$recipients}) {
        # Let the standard config handler deal with this one
        if($self -> set_config($recipient -> {"settings"})) {

            # the settings will contain a series of recipients, which may be bcc, cc, or one of the database queries
            foreach my $arghash (@{$self -> {"args"}}) {
                if($arghash -> {"cc"}) {
                    $self -> _parse_recipients_addrlist($addresses -> {"cc"} , $arghash -> {"cc"});

                } elsif($arghash -> {"bcc"}) {
                    $self -> _parse_recipients_addrlist($addresses -> {"bcc"} , $arghash -> {"bcc"});

                } elsif($arghash -> {"destlist"} && $arghash -> {"destlist"} =~ /^b?cc$/)  {
                    $self -> _parse_recipients_database($addresses -> {$arghash -> {"destlist"}}, $arghash);

                } else {
                    $self -> _parse_recipients_database($addresses -> {"bcc"}, $arghash);
                }
            }

        } else {
            $self -> log("email:error", "No settings for recipient ".$recipient -> {"name"}.", ignoring\n");
        }
    }

    # At this point, the addresses should have been accumulated into the appropriate hashes

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

    return $self -> {"template"} -> load_template("Notification/Method/Email/compose.tem", {"***email-cc***"      => $self -> {"template"} -> html_clean($args -> {"methods"} -> {"Email"} -> {"cc"}),
                                                                                            "***email-bcc***"     => $self -> {"template"} -> html_clean($args -> {"methods"} -> {"Email"} -> {"bcc"}),
                                                                                            "***email-replyto***" => $self -> {"template"} -> html_clean($args -> {"methods"} -> {"Email"} -> {"reply_to"} || $user -> {"email"}),
                                                                                            "***email-prefix***"  => $self -> {"template"} -> build_optionlist($self -> _get_prefixes(), $args -> {"methods"} -> {"Email"} -> {"prefix_id"}),
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

    # Email field validation can be done all in one loop
    foreach my $mode ("cc", "bcc", "reply_to") {
        my $fieldname = $self -> {"template"} -> replace_langvar("METHOD_EMAIL_".uc($mode));

        ($args -> {"methods"} -> {"Email"} -> {$mode}, $error) = $self -> validate_string("email-$mode", {"required"   => 0,
                                                                                                          "default"    => "",
                                                                                                          "nicename"   => $fieldname});
        # Fix up <, >, and "
        $args -> {"methods"} -> {"Email"} -> {$mode} = decode_entities($args -> {"methods"} -> {"Email"} -> {$mode});

        # If we have an error, store it, otherwise check the address is valid
        if($error) {
            push(@errors, $error);
        } else {
            ($args -> {"methods"} -> {"Email"} -> {$mode}, $error) = $self -> _validate_emails($args -> {"methods"} -> {"Email"} -> {$mode}, $fieldname, $mode eq "reply_to" ? 1 : 0);

            push(@errors, $error) if($error);
        }
    }

    # prefix validation must be done separately
    ($args -> {"methods"} -> {"Email"} -> {"prefix_id"}, $error) = $self -> validate_options("email-prefix", {"required" => 1,
                                                                                                              "default"  => "1",
                                                                                                              "source"   => $self -> _get_prefixes(),
                                                                                                              "nicename" => $self -> {"template"} -> replace_langvar("METHOD_EMAIL_PREFIX")});
    push(@errors, $error) if($error);

    return \@errors;
}


################################################################################
#  Private model functions
################################################################################

## @method private $ _get_prefixes()
# Get the options to show in the prefixes list in the email block.
#
# @return A reference to an array containing the prefixes on succes, undef on
#         error.
sub _get_prefixes {
    my $self = shift;

    $self -> clear_error();

    my $prefixh = $self -> {"dbh"} -> prepare("SELECT *
                                               FROM `".$self -> {"settings"} -> {"method:email"} -> {"prefixes"}."`
                                               ORDER BY `id`");
    $prefixh -> execute()
        or return $self -> self_error("Unable to execute prefix lookup: ".$self -> {"dbh"} -> errstr);

    my @options;
    while(my $row = $prefixh -> fetchrow_hashref()) {
        push(@options, {"value" => $row -> {"id"},
                        "name"  => $row -> {"prefix"}." (".$row -> {"description"}.")"});
    }

    return \@options;
}


## @method private $ _parse_recipients_addrlist($reciphash, $addresses)
# Parse the comma separated list of recipients in the specified addresses into
# the provided recipient hash.
#
# @param reciphash A reference to a hash of recipient addresses
# @param addresses A string containing the comma separated addresses to parse
# @return true on success, undef on error.
sub _parse_recipients_addrlist {
    my $self      = shift;
    my $reciphash = shift;
    my $addresses = shift;

    # Nothing to do if there are no addresses
    return 1 if(!$addresses);

    # Simple split & merge
    my @addrlist = split(/,/, $addresses);
    foreach my $addr (@addrlist) {
        # This will ensure that the recipient appears only once in the hash
        $reciphash -> {$addr} = 1;
    }

    return 1;
}


## @method private $ _parse_recipients_addrlist($reciphash, $settings)
# Fetch user email addresses, using the specified settings to control the query,
# and store the list of recipients in the provided recipient hash.
#
# @param reciphash A reference to a hash of recipient addresses
# @param settings  A reference to a hash of query settings supported by
#                  Newsagent::System::UserDataBridge::fetch_user_addresses()
# @return true on success, undef on error.
sub _parse_recipients_database {
    my $self      = shift;
    my $reciphash = shift;
    my $settings  = shift;

    $self -> clear_error();

    my $addresses = $self -> {"system"} -> {"userdata"} -> get_user_addresses($settings)
        or return $self -> self_error($self -> {"system"} -> {"userdata"} -> errstr());

    foreach my $address (@{$addresses}) {
        # This will ensure that the recipient appears only once in the hash
        $reciphash -> {$addr} = 1;
    }

    return 1;
}


################################################################################
#  Private view/controller functions
################################################################################

## @method private @ _validate_emails($emails, $field, $single)
# Validate a string of email addresses. This attempts to determine whether the
# email address(es) in the specified string are valid looking addresses - no
# actualy confirmation of validity is done (or, really, is possible).
#
# @param emails A string containing comma separated email addresses.
# @param field  The human-readable version of the field these email addresses are set for.
# @param single If true, the emails string must contain a single address, otherwise
#               it may contain any number of addresses.
# @return An array of two values: the first is the string passed to the function,
#         the second is a string containing any errors. Note that the emails string
#         is returned even if it contains errors.
sub _validate_emails {
    my $self   = shift;
    my $emails = shift;
    my $field  = shift;
    my $single = shift;

    my @addresses = split(/,/, $emails);

    # If the list is empty, there's nothing to do
    if(!scalar(@addresses)) {
        return ("", undef);

    # Enforce a single address if needed
    } elsif($single && scalar(@addresses) > 1) {
        return ($emails, $self -> {"template"} -> replace_langvar("METHOD_EMAIL_ERR_SINGLEADDR", {"***field***" => $field}));

    # Otherwise, check ALL THE EMAILS
    } else {

        foreach my $email (@addresses) {
            $email =~ s/^\s+|\s+$//g; # We don't need no steenking whitespace

            my $checked = Email::Valid -> address($email);
            if($checked) {
                $email = $checked; # Email::Valid may have modified the address to be more correct
            } else {
                return ($emails, $self -> {"template"} -> replace_langvar("METHOD_EMAIL_ERR_BADADDR", {"***field***" => $field}));
            }
        }

        # return the modified email string
        return (join(',', @addresses), undef);
    }
}

1;
