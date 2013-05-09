## @file
# This file contains the Newsagent-specific user handling.
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
package Newsagent::AppUser;

use strict;
use base qw(Webperl::AppUser);
use Digest::MD5 qw(md5_hex);
use Webperl::Utils qw(trimspace);


## @method $ get_user($username, $onlyreal)
# Obtain the user record for the specified user, if they exist. This returns a
# reference to a hash of user data corresponding to the specified userid,
# or undef if the userid does not correspond to a valid user. If the onlyreal
# argument is set, the userid must correspond to 'real' user - bots or inactive
# users are not be returned.
#
# @param username The username of the user to obtain the data for.
# @param onlyreal If true, only users of type 0 or 3 are returned.
# @return A reference to a hash containing the user's data, or undef if the user
#         can not be located (or is not real)
sub get_user {
    my $self     = shift;
    my $username = shift;
    my $onlyreal = shift;

    my $user = $self -> _get_user("username", $username, $onlyreal, 1)
        or return undef;

    return $self -> _make_user_extradata($user);
}


## @method $ get_user_byid($userid, $onlyreal)
# Obtain the user record for the specified user, if they exist. This returns a
# reference to a hash of user data corresponding to the specified userid,
# or undef if the userid does not correspond to a valid user. If the onlyreal
# argument is set, the userid must correspond to 'real' user - bots or inactive
# users are not be returned.
#
# @param userid   The id of the user to obtain the data for.
# @param onlyreal If true, only users of type 0 or 3 are returned.
# @return A reference to a hash containing the user's data, or undef if the user
#         can not be located (or is not real)
sub get_user_byid {
    my $self     = shift;
    my $userid   = shift;
    my $onlyreal = shift;

    # obtain the user record
    my $user = $self -> _get_user("user_id", $userid, $onlyreal)
        or return undef;

    return $self -> _make_user_extradata($user);
}


## @method $ get_user_byemail($email, $onlyreal)
# Obtain the user record for the user with the specified email, if available.
# This returns a reference to a hash containing the user data corresponding
# to the user with the specified email, or undef if no users have the email
# specified.  If the onlyreal argument is set, the userid must correspond to
# 'real' user - bots or inactive users should not be returned.
#
# @param email    The email address to find an owner for.
# @param onlyreal If true, only users of type 0 or 3 are returned.
# @return A reference to a hash containing the user's data, or undef if the email
#         address can not be located (or is not real)
sub get_user_byemail {
    my $self     = shift;
    my $email    = shift;
    my $onlyreal = shift;

    my $user = $self -> _get_user("email", $email, $onlyreal, 1)
        or return undef;

    return $self -> _make_user_extradata($user);
}


## @method $ post_authenticate($username, $password, $auth)
# After the user has logged in, ensure that they have an in-system record.
# This is essentially a wrapper around the standard AppUser::post_authenticate()
# that handles things like user account activation checks.
#
# @param username The username of the user to perform post-auth tasks on.
# @param password The password the user authenticated with.
# @param auth     A reference to the auth object calling this.
# @param authmethod The id of the authmethod to set for the user.
# @return A reference to a hash containing the user's data on success,
#         undef otherwise. If this returns undef, an error message will be
#         set in to the specified auth's errstr field.
sub post_authenticate {
    my $self       = shift;
    my $username   = shift;
    my $password   = shift;
    my $auth       = shift;
    my $authmethod = shift;

    # Let the superclass handle user creation
    my $user = $self -> SUPER::post_authenticate($username, $password, $auth, $authmethod);
    return undef unless($user);

    # User now exists, determine whether the user is active
    return $user# $self -> post_login_checks($user, $auth)
        if($user -> {"activated"});

    # User is inactive, does the account need activating?
    if(!$user -> {"act_code"}) {
        # No code provided, so just activate the account
        if($self -> activate_user_byid($user -> {"user_id"})) {
            return $user; #$self -> post_login_checks($user, $auth)
        } else {
            return $auth -> self_error($self -> {"errstr"});
        }
    } else {
        return $auth -> self_error("User account is not active.");
    }
}


## @method $ post_login_checks($user, $auth)
# Perform checks on the specified user after they have logged in (post_authenticate is
# going to return the user record). This ensures that the user has the appropriate
# roles and settings.
#
# @todo This needs to invoke the enrolment engine to make sure the user has the
#       appropriate per-course roles assigned.
#
# @param user A reference to a hash containing the user's data.
# @param auth A reference to the auth object calling this.
# @return A reference to a hash containing the user's data on success,
#         undef otherwise. If this returns undef, an error message will be
#         set in to the specified auth's errstr field.
sub post_login_checks {
    my $self = shift;
    my $user = shift;
    my $auth = shift;

    # All users must have the user role in the metadata root
    my $roleid  = $self -> {"system"} -> {"roles"} -> role_get_roleid("user");
    my $root    = $self -> {"system"} -> {"roles"} -> {"root_context"};
    my $hasrole = $self -> {"system"} -> {"roles"} -> user_has_role($root, $user -> {"user_id"}, $roleid);

    # Give up if the role check failed.
    return $auth -> self_error($self -> {"system"} -> {"roles"} -> {"errstr"})
        if(!defined($hasrole));

    # Try to assign the role if the user does not have it.
    $self -> {"system"} -> {"roles"} -> user_assign_role($root, $user -> {"user_id"}, $roleid)
        or return $auth -> self_error($self -> {"system"} -> {"roles"} -> {"errstr"})
        if(!$hasrole);

    # TODO: Assign other roles as needed.

    return $user;
}


# ============================================================================
#  Internal functions

## @method private $ _make_user_extradata($user)
# Generate the 'calculated' user fields - full name, gravatar hash, etc.
#
# @param user A reference to the user hash to work on.
# @return The user hash reference.
sub _make_user_extradata {
    my $self = shift;
    my $user = shift;

    # Generate the user's full name
    $user -> {"fullname"} = (($user -> {"forenames"} || "")." ".($user -> {"surname"} || ""));
    $user -> {"fullname"} = $user -> {"username"} if($user -> {"fullname"} eq " ");

    # Make the user gravatar hash
    $user -> {"gravatar_hash"} = md5_hex(lc(trimspace($user -> {"email"} || "")));

    return $user;
}

1;
