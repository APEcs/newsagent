## @file
# This file contains the implementation of the subscriptions model.
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
package Newsagent::System::Subscriptions;

use strict;
use base qw(Webperl::SystemModule); # This class extends the Newsagent block class
use v5.12;

## @cmethod $ new(%args)
# Create a new Subscriptions object to manage tag allocation and lookup.
# The minimum values you need to provide are:
#
# * dbh       - The database handle to use for queries.
# * settings  - The system settings object
# * metadata  - The system Metadata object.
# * roles     - The system Roles object.
# * logger    - The system logger object.
#
# @param args A hash of key value pairs to initialise the object with.
# @return A new Subscriptions object, or undef if a problem occured.
sub new {
    my $invocant = shift;
    my $class    = ref($invocant) || $invocant;
    my $self     = $class -> SUPER::new(@_)
        or return undef;

    return $self;
}


# ============================================================================
#  Data access


sub set_user_subscription {
    my $self   = shift;
    my $userid = shift;
    my $email  = shift;
    my $feeds  = shift;

    $self -> clear_error();

    my $subid = $self -> _get_subscription_id($userid, $email)
        or return undef;

    foreach my $feed (@{$feeds}) {
        $self -> _set_subscription($subid, $feed)
            or return undef;
    }

    return 1;
}


# ============================================================================
#  Internal implementation


sub _get_subscription_id {
    my $self   = shift;
    my $userid = shift;
    my $email  = shift;

    $self -> clear_error();

    # Lookup existing subscription
    my $

}

1;