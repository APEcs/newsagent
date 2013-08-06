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

    return $self -> {"template"} -> load_template("Notification/Method/Email/compose.tem", {"***email-cc***"      => $self -> {"template"} -> html_clean($args -> {"methods"} -> {"email"} -> {"cc"}),
                                                                                            "***email-bcc***"     => $self -> {"template"} -> html_clean($args -> {"methods"} -> {"email"} -> {"bcc"}),
                                                                                            "***email-replyto***" => $self -> {"template"} -> html_clean($args -> {"methods"} -> {"email"} -> {"replyto"} || $user -> {"email"}),
                                                                                            "***email-prefix***"  => $self -> {"template"} -> build_optionlist($self -> _get_prefixes(), $args -> {"methods"} -> {"email"} -> {"prefix"}),
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
    foreach my $mode ("cc", "bcc", "replyto") {
        my $fieldname = $self -> {"template"} -> replace_langvar("METHOD_EMAIL_".uc($mode));

        ($args -> {"methods"} -> {"email"} -> {$mode}, $error) = $self -> validate_string("email-$mode", {"required"   => 0,
                                                                                                          "default"    => "",
                                                                                                          "nicename"   => $fieldname});
        # Fix up <, >, and "
        $args -> {"methods"} -> {"email"} -> {$mode} = decode_entities($args -> {"methods"} -> {"email"} -> {$mode});

        # If we have an error, store it, otherwise check the address is valid
        if($error) {
            push(@errors, $error);
        } else {
            ($args -> {"methods"} -> {"email"} -> {$mode}, $error) = $self -> _validate_emails($args -> {"methods"} -> {"email"} -> {$mode}, $fieldname, $mode eq "replyto" ? 1 : 0);

            push(@errors, $error) if($error);
        }
    }

    # prefix validation must be done separately
    ($args -> {"methods"} -> {"email"} -> {"prefix"}, $error) = $self -> validate_options("email-prefix", {"required" => 1,
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
