## @file
# This file contains the implementation of the Tell Us base class.
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
package Newsagent::TellUs;

use strict;
use base qw(Newsagent); # This class extends the Newsagent block class
use Newsagent::System::TellUs;
use v5.12;

# ============================================================================
#  Constructor

## @cmethod $ new(%args)
# Overloaded constructor for the Article, loads the System::Article model
# and other classes required to generate article pages.
#
# @param args A hash of values to initialise the object with. See the Block docs
#             for more information.
# @return A reference to a new Newsagent::Article object on success, undef on error.
sub new {
    my $invocant = shift;
    my $class    = ref($invocant) || $invocant;
    my $self     = $class -> SUPER::new(@_)
        or return undef;

    $self -> {"article"} = Newsagent::System::TellUs -> new(dbh      => $self -> {"dbh"},
                                                            settings => $self -> {"settings"},
                                                            logger   => $self -> {"logger"},
                                                            roles    => $self -> {"system"} -> {"roles"},
                                                            metadata => $self -> {"system"} -> {"metadata"})
        or return Webperl::SystemModule::set_error("TellUs initialisation failed: ".$Webperl::SystemModule::errstr);

    $self -> {"state"} = [ {"value" => "new",
                            "name"  => "{L_TELLUS_NEW}" },
                           {"value" => "viewed",
                            "name"  => "{L_TELLUS_VIEWED}" },
                           {"value" => "rejected",
                            "name"  => "{L_TELLUS_REJECTED}" },
        ];

    $self -> {"allow_tags"} = [
        "a", "b", "blockquote", "br", "caption", "col", "colgroup", "comment",
        "em", "h1", "h2", "h3", "h4", "h5", "h6", "hr", "li", "ol", "p",
        "pre", "small", "span", "strong", "sub", "sup", "table", "tbody", "td",
        "tfoot", "th", "thead", "tr", "tt", "ul",
        ];

    $self -> {"tag_rules"} = [
        a => {
            href   => qr{^(?:http|https)://}i,
            name   => 1,
            '*'    => 0,
        },
        table => {
            cellspacing => 1,
            cellpadding => 1,
            style       => 1,
            class       => 1,
            '*'         => 0,
        },
        td => {
            colspan => 1,
            rowspan => 1,
            style   => 1,
            '*'     => 0,
        },
        blockquote => {
            cite  => qr{^(?:http|https)://}i,
            style => 1,
            '*'   => 0,
        },
        span => {
            class => 1,
            style => 1,
            title => 1,
            '*'   => 0,
        },
        div => {
            class => 1,
            style => 1,
            title => 1,
            '*'   => 0,
        },
        img => {
            src    => 1,
            class  => 1,
            alt    => 1,
            width  => 1,
            height => 1,
            style  => 1,
            title  => 1,
            '*'    => 0,
        },
        ];

    return $self;
}



1;
