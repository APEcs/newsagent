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

################################################################################
# Model/support functions
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

    return $self -> {"template"} -> load_template("Notification/Method/Email/compose.tem", {"***email-cc***"      => $args -> {"methods"} -> {"email"} -> {"cc"},
                                                                                            "***email-bcc***"     => $args -> {"methods"} -> {"email"} -> {"bcc"},
                                                                                            "***email-replyto***" => $args -> {"methods"} -> {"email"} -> {"replyto"} || $user -> {"email"},
                                                                                            "***email-prefix***"  => $self -> {"template"} -> build_optionlist($self -> _get_prefixes(), $args -> {"methods"} -> {"email"} -> {"prefix"}),
                                                  });
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

1;
