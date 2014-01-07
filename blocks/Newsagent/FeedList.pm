## @file
# This file contains the implementation of the feed list page.
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
package Newsagent::FeedList;

use strict;
use base qw(Newsagent); # This class extends the Newsagent block class
use Newsagent::System::Article;
use v5.12;

# ============================================================================
#  Constructor

## @cmethod $ new(%args)
# Overloaded constructor for the Compose facility, loads the System::Article model
# and other classes required to generate the compose pages.
#
# @param args A hash of values to initialise the object with. See the Block docs
#             for more information.
# @return A reference to a new Newsagent::Compose object on success, undef on error.
sub new {
    my $invocant = shift;
    my $class    = ref($invocant) || $invocant;
    my $self     = $class -> SUPER::new(@_)
        or return undef;

    $self -> {"article"} = Newsagent::System::Article -> new(dbh      => $self -> {"dbh"},
                                                             settings => $self -> {"settings"},
                                                             logger   => $self -> {"logger"},
                                                             roles    => $self -> {"system"} -> {"roles"},
                                                             metadata => $self -> {"system"} -> {"metadata"})
        or return Webperl::SystemModule::set_error("FeedList initialisation failed: ".$SystemModule::errstr);

    return $self;
}

1;
