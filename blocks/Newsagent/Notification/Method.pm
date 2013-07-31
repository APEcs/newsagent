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
package Newsagent::Method;

## @class Newsagent::Method
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

################################################################################
# Model/support functions
################################################################################

## @method void set_config($args)
# Set the current configuration to the module to the values in the provided
# args string.
#
# @param args A string containing the new configuration.
sub set_config {
    my $self = shift;
    my $args = shift;

    # default does nothing
}


## @method $ store_message($args, $user, $mess_id, $prev_id)
# Store the data for this method. This will store any method-specific
# data in the args hash in the appropriate tables in the database.
#
# @param args    A reference to a hash containing the message data.
# @param user    A reference to a hash containing the user's data.
# @param mess_id The ID of the message being stored.
# @param prev_id If set, this is the ID of the message that the current
#                mess_id is an edit of.
# @return true on success, undef on error
sub store_message {
    my $self    = shift;
    my $args    = shift;
    my $user    = shift;
    my $mess_id = shift;
    my $prev_id = shift;

    # Does nothing
    return 1;
}


## @method void get_message($msgid, $message)
# Populate the specified message hash with data specific to this method.
# This will pull any data appropriate for the current method out of
# the database and shove it into the message hash.
#
# @param msgid   The ID of the message to fetch the data for.
# @param message A reference to the hash into which the data should be written.
# @return true on success, undef on error
sub get_message {
    my $self    = shift;
    my $msgid   = shift;
    my $message = shift;

    # Does nothing.
    return 1;
}


## @method $ send($message)
# Attempt to send the specified message to the method system.
#
# @param message A reference to a hash containing the message to send.
# @return undef on success, an error message on failure.
sub send {
    my $self    = shift;
    my $message = shift;

    return undef;
}


################################################################################
#  View and controller functions
################################################################################


## @method $ generate_compose($args, $user)
# Generate the string to insert into the compose page for this method.
#
# @param args A reference to a hash of arguments to use in the form
# @param user A reference to a hash containing the user's data
# @return A string containing the message form fragment.
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
# @return A string containing the message edit form fragment.
sub generate_message_edit {
    my $self = shift;
    my $args = shift;

    return "";
}


## @method $ generate_view($args, $outfields)
# Generate the string to insert into the view page for this method.
#
# @param args      A reference to a hash of arguments to use in the form
# @param outfields A reference to a hash of output values.
# @return A string containing the message view form fragment.
sub generate_message_view {
    my $self      = shift;
    my $args      = shift;
    my $outfields = shift;

    return "";
}


## @method $ validate_article($args)
# Validate this method's settings in the posted data, and store them in
# the provided args hash.
#
# @param args A reference to a hash into which the Method's data should be stored.
# @return A string containing any error messages encountered during validation.
sub validate_article {
    my $self = shift;
    my $args = shift;

    return "";
}


## @method $ generate_messagelist_visibility($message)
# Generate the fragment to display in the 'visibility' column of the user
# message list for the specified message.
#
# @param message The message being processed.
# @return A string containing the HTML fragment to show in the visibility column.
sub generate_messagelist_visibility {
    my $self    = shift;
    my $message = shift;

    return "";
}


## @method $ generate_messagelist_ops($message, $args)
# Generate the fragment to display in the 'ops' column of the user
# message list for the specified message.
#
# @param message The message being processed.
# @param args    Additional arguments to use when filling in fragment templates.
# @return A string containing the HTML fragment to show in the ops column.
sub generate_messagelist_ops {
    my $self    = shift;
    my $message = shift;
    my $args    = shift;

    return "";
}


## @method $ known_op()
# Determine whether the method module can understand the operation specified
# in the query string. This function allows UserMessages to determine which
# Method modules understand operations added by methods during generate_messagelist_ops().
#
# @return true if the Method module can understand the operation, false otherwise.
sub known_op {
    my $self = shift;

    return 0;
}


## @method @ process_op($message)
# Perform the query-stringspecified operation on a message. This allows Method
# modules to implement the operations added as part of generate_messagelist_ops().
#
# @param message A reference to a hash containing the message data.
# @return A string containing a status update message to show above the list, and
#         a flag specifying whether the returned string is an error message or not.
sub process_op {
    my $self    = shift;
    my $message = shift;

    return ("", 0);
}

1;
