# @file
# This file contains the implementation of the Seminar importer class
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
#
package Newsagent::Importer::Seminars;

use strict;
use experimental 'smartmatch';
use base qw(Newsagent::Importer); # This class extends the Newsagent block class
use v5.12;
use DateTime;
use LWP::UserAgent;
use XML::LibXML;

# ============================================================================
#  Constructor

# No explicit constructor (uses Importer class constructor) but this must be
# created with 'importer_id' set appropriately.

# ============================================================================
#  Interface functions

## @method $ import_articles()
# Run the import process for this module. This will fetch the articles from the
# source, determine whether any need to be added to the system, and perform any
# additions or updates as needed.
#
# @return true on success (note that 'nothing imported' is considered success
#         if there is nothing to import!) or undef on error.
sub import_articles {
    my $self = shift;

    $self -> clear_error();



    return 1;
}

1;