## @file
# This file contains the implementation of the bridge to the userdata databse.
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
package Newsagent::System::UserDataBridge;

use strict;
use base qw(Webperl::SystemModule); # This class extends the system module
use v5.12;


# ============================================================================
#  Constructor

## @cmethod $ new(%args)
# Create a new Matrix object to manage matrix interaction.
# The minimum values you need to provide are:
#
# * dbh       - The database handle to use for queries.
# * settings  - The system settings object
# * metadata  - The system Metadata object.
# * roles     - The system Roles object.
# * logger    - The system logger object.
#
# @param args A hash of key value pairs to initialise the object with.
# @return A new Matrix object, or undef if a problem occured.
sub new {
    my $invocant = shift;
    my $class    = ref($invocant) || $invocant;
    my $self     = $class -> SUPER::new(@_)
        or return undef;

    # Check that the required objects are present
    return Webperl::SystemModule::set_error("No metadata object available.") if(!$self -> {"metadata"});
    return Webperl::SystemModule::set_error("No roles object available.")    if(!$self -> {"roles"});

    $self -> {"udata_dbh"} = DBI->connect($self -> {"settings"} -> {"userdata"} -> {"database"},
                                          $self -> {"settings"} -> {"userdata"} -> {"username"},
                                          $self -> {"settings"} -> {"userdata"} -> {"password"},
                                          { RaiseError => 0, AutoCommit => 1, mysql_enable_utf8 => 1 })
        or return Webperl::SystemModule::set_error("Unable to connect to userdata database: ".$DBI::errstr);

    return $self;
}


# ============================================================================
#  Data access

## @method $ get_valid_years($as_options)
# Obtain a list of academic years for which there is user information in the userdata
# database.
#
# @param as_options If this is set to true, the reference returned by this function
#                   contains the year data in a format suitable for use as <select>
#                   options via Webperl::Template::build_optionlist().
# @return A reference to an array containing year data hashrefs on success, undef
#         on error.
sub get_valid_years {
    my $self       = shift;
    my $as_options = shift;

    $self -> clear_error();

    my $lookuph = $self -> {"udata_dbh"} -> prepare("SELECT DISTINCT y.*
                                                     FROM `".$self -> {"settings"} -> {"userdata"} -> {"user_years"}."` AS l,
                                                          `".$self -> {"settings"} -> {"userdata"} -> {"acyears"}."` AS y
                                                     WHERE y.id = l.year_id
                                                     ORDER BY y.start_year DESC");
    $lookuph -> execute()
        or return $self -> self_error("Unable to execute academic year lookup: ".$self -> {"udata_dbh"} -> errstr);

    my $rows = $lookuph -> fetchall_arrayref({})
        or return $self -> self_error("Error fetching rows from year lookup");

    # If the data should be returned as-is, do so.
    return $rows if(!$as_options);

    # Otherwise, convert to an options-friendly format

    my @yearlist = ();
    foreach my $year (@{$rows}) {
        push(@yearlist, { "value" => $year -> {"id"},
                          "name"  => $year -> {"start_year"}."/".$year -> {"end_year"}});
    }

    return \@yearlist;
}


1;
