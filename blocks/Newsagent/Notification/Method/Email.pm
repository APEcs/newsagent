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
use Digest::MD5 qw(md5_hex);
use Email::Valid;
use HTML::Entities;
use HTML::WikiConverter;
use Encode;
use Email::MIME;
use Email::MIME::CreateHTML;
use Email::Sender::Simple qw(sendmail);
use Email::Sender::Transport::SMTP;
use Email::Sender::Transport::SMTP::Persistent;
use Try::Tiny;
use Webperl::Utils qw(trimspace path_join);
use v5.12;

use Data::Dumper;


## @cmethod Newsagent::Notification::Method::Email new(%args)
# Create a new Email object. This will create an object
# that may be used to send messages to recipients over SMTP.
#
# @param args A hash of arguments to initialise the Email
#             object with.
# @return A new Email object.
sub new {
    my $invocant = shift;
    my $class    = ref($invocant) || $invocant;
    my $self     = $class -> SUPER::new(@_)
        or return undef;

    # Make local copies of the config for readability
    # Arguments for Email::Sender::Transport::SMTP(::Persistent)
    $self -> {"host"}     = $self -> get_method_config("smtp_host");
    $self -> {"port"}     = $self -> get_method_config("smtp_port");
    $self -> {"ssl"}      = $self -> get_method_config("smtp_secure");
    $self -> {"username"} = $self -> get_method_config("username");
    $self -> {"password"} = $self -> get_method_config("password");

    # Should persistent SMTP be used?
    $self -> {"persist"}  = $self -> get_method_config("persist");

    # Should the sender be forced (ie: always use the system-specified sender, even if the message has
    # an explicit sender. This should be the address to set as the sender.
    $self -> {"force_sender"} = $self -> get_method_config("force_sender");

    # The address to use as the envelope sender.
    $self -> {"env_sender"}   = $self -> {"settings"} -> {"config"} -> {"Core:envelope_address"};

    # set up persistent STMP if needed
    if($self -> {"persist"}) {
        eval { $self -> {"smtp"} = Email::Sender::Transport::SMTP::Persistent -> new($self -> _build_smtp_args()); };
        return SystemModule::set_error("SMTP Initialisation failed: $@") if($@);
    }

    return $self;
}


## @method void DESTROY()
# Destructor method to clean up persistent SMTP if it is in use.
sub DESTROY {
    my $self = shift;

    $self -> {"smtp"} -> disconnect()
        if($self -> {"persist"} && $self -> {"smtp"});
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

    my $prefix = $self -> _get_prefix($article -> {"methods"} -> {"Email"} -> {"prefix_id"});
    return $self -> self_error("Unable to locate prefix: " .$self -> errstr()) if(!defined($prefix));

    # Start building the recipient lists
    my $addresses = { "reply_to" => $article -> {"methods"} -> {"Email"} -> {"reply_to"},
                      "outgoing" => { "cc"       => {},
                                      "bcc"      => {} },
                      "debug"    => { "cc"       => {},
                                      "bcc"      => {} },
    };

    # Pull the addresses out of address lists, if specified.
    $self -> _parse_recipients_addrlist($addresses -> {"outgoing"} -> {"cc"} , $article -> {"methods"} -> {"Email"} -> {"cc"});
    $self -> _parse_recipients_addrlist($addresses -> {"outgoing"} -> {"bcc"}, $article -> {"methods"} -> {"Email"} -> {"bcc"});

    # Process each of the recipients, parsing the configuration and then merging recipient addresses
    foreach my $recipient (@{$recipients}) {
        # Let the standard config handler deal with this one
        if($self -> set_config($recipient -> {"settings"})) {

            # the settings will contain a series of recipients, which may be bcc, cc, or one of the database queries
            foreach my $arghash (@{$self -> {"args"}}) {
                my $addrmode = $arghash -> {"debug"} ? "debug" : "outgoing";

                if($arghash -> {"cc"}) {
                    $self -> _parse_recipients_addrlist($addresses -> {$addrmode} -> {"cc"} , $arghash -> {"cc"});

                } elsif($arghash -> {"bcc"}) {
                    $self -> _parse_recipients_addrlist($addresses -> {$addrmode} -> {"bcc"} , $arghash -> {"bcc"});

                } elsif($arghash -> {"destlist"} && $arghash -> {"destlist"} =~ /^b?cc$/)  {
                    $self -> _parse_recipients_database($addresses -> {$addrmode} -> {$arghash -> {"destlist"}}, $arghash);

                } else {
                    $self -> _parse_recipients_database($addresses -> {$addrmode} -> {"bcc"}, $arghash);
                }
            }

        } else {
            $self -> log("email:error", "No settings for recipient ".$recipient -> {"name"}.", ignoring\n");
        }
    }

    # If any debug addresses have been set, force debugging mode
    $addresses -> {"use_debugmode"} = (scalar(keys(%{$addresses -> {"debug"} -> {"cc"}})) || scalar(keys(%{$addresses -> {"debug"} -> {"bcc"}})));
    $self -> _move_outgoing_to_debug($addresses)
        if($addresses -> {"use_debugmode"});

    # At this point, the addresses should have been accumulated into the appropriate hashes
    # Convert the article into something nicer to throw around
    my $author = $self -> {"session"} -> get_user_byid($article -> {"creator_id"})
        or return $self -> self_error("Unable to obtain author information for message ".$article -> {"id"});

    $article -> {"images"} -> [0] -> {"location"} = path_join($self -> {"settings"} -> {"config"} -> {"Article:upload_image_url"},
                                                                 $self -> {"settings"} -> {"config"} -> {"HTML:default_image"})
            if(!$article -> {"images"} -> [0] -> {"location"} && $self -> {"settings"} -> {"config"} -> {"HTML:default_image"});

    my @images;
    for(my $img = 0; $img < 2; ++$img) {
        next if(!$article -> {"images"} -> [$img] || !$article -> {"images"} -> [$img] -> {"location"});
        $images[$img] = $article -> {"images"} -> [$img] -> {"location"};

        $images[$img] = path_join($self -> {"settings"} -> {"config"} -> {"Article:upload_image_url"},
                                  $images[$img])
            if($images[$img] && $images[$img] !~ /^http/);
    }

    $images[0] = $self -> {"template"} -> load_template("Notification/Method/Email/image_sized.tem", {"***class***"  => "leader",
                                                                                                      "***url***"    => $images[0],
                                                                                                      "***alt***"    => "lead image",
                                                                                                      "***width***"  => 130,
                                                                                                      "***height***" => 63});

    $images[1] = $self -> {"template"} -> load_template("Notification/Method/Email/image.tem", {"***class***"  => "article",
                                                                                                "***url***"    => $images[1],
                                                                                                "***alt***"    => "article image"})
        if($article -> {"images"} -> [1] -> {"location"});

    $article -> {"article"} = $self -> cleanup_entities($article -> {"article"});

    my $pubdate = $self -> {"template"} -> format_time($article -> {"release_time"}, "%a, %d %b %Y %H:%M:%S %z");
    my $subject = $article -> {"title"} || $pubdate;
    $subject = $prefix." ".$subject if($prefix);

    my $htmlbody = $self -> {"template"} -> load_template("Notification/Method/Email/email.tem", {"***body***"     => $article -> {"article"},
                                                                                                  "***title***"    => $article -> {"title"} || $pubdate,
                                                                                                  "***date***"     => $pubdate,
                                                                                                  "***summary***"  => $article -> {"summary"},
                                                                                                  "***img1***"     => $images[0],
                                                                                                  "***img2***"     => $images[1],
                                                                                                  "***logo_url***" => $self -> {"settings"} -> {"config"} -> {"Article:logo_img_url"},
                                                                                                  "***name***"     => $article -> {"realname"} || $article -> {"username"},
                                                                                                  "***gravhash***" => md5_hex(lc(trimspace($article -> {"email"} || ""))) });

    my $email_data = { "addresses" => $addresses,
                       "debug"     => $addresses -> {"use_debugmode"},
                       "subject"   => Encode::encode("iso-8859-1", $subject),
                       "html_body" => Encode::encode("iso-8859-1", $htmlbody),
                       "text_body" => $self -> make_markdown_body(Encode::encode("iso-8859-1", $article -> {"article"}), $article -> {"images"}),
                       "reply_to"  => $article -> {"methods"} -> {"Email"} -> {"reply_to"} || $author -> {"email"},
                       "from"      => $author -> {"email"},
                       "id"        => $article -> {"id"}
    };

    my $status = $self -> _send_emails($email_data);
    my @results = ();
    foreach my $recipient (@{$recipients}) {

        # Store the send status.
        push(@results, {"name"    => $recipient -> {"shortname"},
                        "state"   => $status,
                        "message" => $status eq "error" ? $self -> errstr() : ""});
    }

    return \@results;
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


## @method private $ _get_prefix(prefixid)
# Get the prefix selected
#
# @praram prefixid  The ID of the prefix to use
# @return A reference to an array containing the prefixes on succes, undef on
#         error.
sub _get_prefix {
    my $self     = shift;
    my $prefixid = shift;

    $self -> clear_error();

    my $prefixh = $self -> {"dbh"} -> prepare("SELECT prefix
                                               FROM `".$self -> {"settings"} -> {"method:email"} -> {"prefixes"}."`
                                               WHERE `id` = ?");
    $prefixh -> execute($prefixid)
        or return $self -> self_error("Unable to execute prefix lookup: ".$self -> {"dbh"} -> errstr);

    my $prefix = $prefixh -> fetchrow_arrayref()
        or return $self -> self_error("Unknown prefix selected: ".$self -> {"dbh"} -> errstr);

    return $prefix -> [0];
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
    foreach my $address (@addrlist) {
        # This will ensure that the recipient appears only once in the hash
        $reciphash -> {$address} = 1;
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
        $reciphash -> {$address} = 1;
    }

    return 1;
}


## @method private void _move_outgoing_to_debug($addresses)
# Move any outgoing addresses into the corresponding debug addresses.
#
# @param addresses A reference to the addresses hash
sub _move_outgoing_to_debug {
    my $self      = shift;
    my $addresses = shift;

    foreach my $mode ("cc", "bcc") {
        # Copy the addresses
        foreach my $addr (keys(%{$addresses -> {"outgoing"} -> {$mode}})) {
            $addresses -> {"debug"} -> {$mode} -> {$addr} = 1;
        }

        # nuke the outgoing
        $addresses -> {"outgoing"} -> {$mode} = {};
    }
}


## @method private % _build_smtp_args()
# Build the argument hash to pass to the SMTP constructor.
#
# @return A hash of arguments to pass to the Email::Sender::Transport::SMTP constructor
sub _build_smtp_args {
    my $self = shift;

    my %args = (host => $self -> {"host"},
                port => $self -> {"port"},
                ssl  => $self -> {"ssl"} || 0);

    if($self -> {"username"} && $self -> {"password"}) {
        $args{"sasl_username"} = $self -> {"username"};
        $args{"sasl_password"} = $self -> {"password"};
    }

    return %args;
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


## @method private $ _send_email_message($email)
# Send the specified email to its recipients. This constructs the email from the
# header, html body, and text body provided and sends it.
#
# @param email A reference to a hash containing the email to send. Must contain
#              `header` (a reference to an array of header fields to set),
#              `html_body` (the html version of the text to send), and `text_body`
#              containing the text version.
# @return true on success, undef on error.
sub _send_email_message {
    my $self  = shift;
    my $email = shift;

    if(!$self -> {"persist"}) {
        eval { $self -> {"smtp"} = Email::Sender::Transport::SMTP -> new($self -> _build_smtp_args()); };
        return $self -> self_error("SMTP Initialisation failed: $@") if($@);
    }

    # Eeech, HTML email ;.;
    my $outgoing = Email::MIME -> create_html(header    => $email -> {"header"},
                                              body      => $email -> {"html_body"},
                                              embed     => 0,
                                              text_body => $email -> {"text_body"});

    # Fly! Fly, my pretties!
    try {
        # Preserve the existing To/CC
        my $to = $outgoing -> header("To");
        my $cc = $outgoing -> header("Cc");

        # Email::Sender will silently drop Bcc addresses - they need to be handled
        # separately.
        my $bcc = $outgoing -> header("Bcc");
        if($bcc) {
            # Clear the bcc header
            $outgoing -> header_set("Bcc");

            # Send the message with an explicit envelope recipient list
            my @bccaddrs = split(/,/, $bcc);

            # Remove the explicit recipients
            $outgoing -> header_set("To");
            $outgoing -> header_set("Cc");

            given($self -> get_method_config("bcc_mode")) {
                when('promote') {
                    foreach my $addr (@bccaddrs) {

                        $outgoing -> header_set("To", $addr);
                        sendmail($outgoing, { from      => $self -> {"env_sender"},
                                              transport => $self -> {"smtp"}});
                    }
                }
                default {
                    sendmail($outgoing, { to        => \@bccaddrs,
                                          from      => $self -> {"env_sender"},
                                          transport => $self -> {"smtp"}});
                }
            }
        }

        # No point sending more messages than needed if there is no to or cc set...
        if($to || $cc) {
            $outgoing -> header_set("To", $to) if($to);
            $outgoing -> header_set("Cc", $cc) if($cc);

            sendmail($outgoing, { from      => $self -> {"env_sender"},
                                  transport => $self -> {"smtp"}});
        }
    } catch {
        # ... ooor, crash into the ground painfully.
        return $self -> self_error("Delivery of email failed: $_");
    };

    return 1;
}


## @method private $ _send_emails($email)
# Send the message to the recipients, chunking the dispatch into multiple emails if
# too many recipients have been specified to send in a single message.
#
# @param email A reference to a hash containing the email text body, html body,
#              and recipients. If 'debug' is set, the emails are sent to the
#              user that composed the email, along with debugging information,
#              rather than to the real recipients.
# @return "sent" on success, "error" on error.
sub _send_emails {
    my $self  = shift;
    my $email = shift;

    my $outmode = $email -> {"debug"} ? "debug" : "outgoing";

    # Go through cc/bcc, chunking the sends if needed. This is slightly wasteful if there are only a few
    # stray ccs or bccs, but it makes like a lot easier
    foreach my $mode ("cc", "bcc") {
        my @addresses = keys(%{$email -> {"addresses"} -> {$outmode} -> {$mode}});
        my $limit = $self -> get_method_config("recipient_limit") || 25;

        # while there are still addresses left to process in this mode...
        while(scalar(@addresses)) {
            # grab the first "limit" chunk of them, and convert to a comma separated string to
            # pass to the email sender
            my @recipients = splice(@addresses, 0, $limit);
            my $recipstr   = join(",", @recipients);

            my $text_body = $email -> {"text_body"};
            $text_body .= "DEBUG: Email would be ".$mode."d to ".scalar(@recipients)." addresses. Address data is: $recipstr"
                if($email -> {"debug"});

            my $header;
            if($email -> {"debug"}) {
                $header = [ "To"       => $email -> {"from"},
                            "From"     => $email -> {"from"},
                            "Subject"  => $email -> {"subject"},
                            "Reply-To" => $email -> {"reply_to"},
                          ];
            } else {
#                $self -> self_error("No real sending yet!");
#                return "error";

                $header = [ ucfirst($mode) => $recipstr,
                            "From"         => $email -> {"from"},
                            "Subject"      => $email -> {"subject"},
                            "Reply-To"     => $email -> {"reply_to"},
                          ];
                push(@{$header}, "To", $self -> get_method_config("require_to"))
                    if($self -> get_method_config("require_to"));
            }

            push(@{$header}, "X-Mailer", "Newsagent");

            $self -> _send_email_message({"header"    => $header,
                                          "html_body" => $email -> {"html_body"},
                                          "text_body" => $text_body,
                                          "id"        => $email -> {"id"},
                                         })
                or return "error";
        }
    }

    return "sent";
}

1;
