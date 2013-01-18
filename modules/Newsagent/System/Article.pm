## @file
# This file contains the implementation of the article model.
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
package Newsagent::System::Article;

use strict;
use base qw(Webperl::SystemModule); # This class extends the Newsagent block class
use v5.12;


sub get_user_levels {
    my $self = shift;
    my $user = shift;

    my $levelsh = $self -> {"dbh"} -> prepare("SELECT * FROM `".$self -> {"settings"} -> {"database"} -> {"levels"}."`
                                               ORDER BY `id`");
    $levelsh -> execute()
        or return $self -> self_error("Unable to execute user levels query: ".$self -> {"dbh"} -> errstr);

    my @levellist;
    while(my $level = $levelsh -> fetchrow_hashref()) {
        # FIXME: Check user permission for level here?

        push(@levellist, {"name"  => $level -> {"description"},
                          "value" => $level -> {"level"}});
    }

    return \@levellist;
}


sub get_user_sites {
    my $self = shift;
    my $user = shift;

    my $sitesh = $self -> {"dbh"} -> prepare("SELECT * FROM `".$self -> {"settings"} -> {"database"} -> {"sites"}."`
                                              ORDER BY `name`");
    $sitesh -> execute()
        or return $self -> self_error("Unable to execute user sites query: ".$self -> {"dbh"} -> errstr);

    my @sitelist;
    while(my $site = $sitesh -> fetchrow_hashref()) {
        # FIXME: Check user permission for site here?

        push(@sitelist, {"name"  => $site -> {"description"},
                         "value" => $site -> {"name"}});
    }

    return \@sitelist;
}


1;
