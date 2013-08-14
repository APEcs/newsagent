## @file
# This file contains the implementation of the cron-triggered notification
# dispatcher
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
package Newsagent::Article::Cron;

use strict;
use base qw(Newsagent::Article); # This class extends the Article block class
use v5.12;

use Newsagent::System::Matrix;

sub build_pending_summary {
    my $self    = shift;
    my $pending = shift;
    my $notify  = "";

    foreach my $entry (@{$pending}) {
        $notify .= $self -> {"template"} -> load_template("cron/summary_item.tem", {"***article***" => $entry -> {"article_id"},
                                                                                    "***id***"      => $entry -> {"id"},
                                                                                    "***year***"    => $entry -> {"year_id"},
                                                                                    "***method***"  => $entry -> {"name"},
                                                          });
    }

    return $notify;
}



# ============================================================================
#  Interface functions

## @method $ page_display()
# Produce the string containing this block's full page content. This generates
# the compose page, including any errors or user feedback.
#
# @return The string containing this block's page content.
sub page_display {
    my $self = shift;
    my ($content, $extrahead) = ("", "");

    my $matrix = $self -> {"module"} -> load_module("Newsagent::Notification::Matrix");

    # Fetch the list of pending notifications
    my $pending = $matrix -> get_pending_notifications()
        or return $self -> generate_errorbox($matrix -> errstr());

    if(!scalar(@{$pending})) {
        $content = $self -> {"template"} -> load_template("cron/noitems.tem");
    } else {
        # summarise in case this is being run attended
        my $summary = $self -> {"template"} -> load_template("cron/summary.tem", {"***items***" => $self -> build_pending_summary($pending)});

        $content = $summary;
    }

    return $self -> generate_newsagent_page("{L_CRONJOB_TITLE}", $content, $extrahead);
}

1;
