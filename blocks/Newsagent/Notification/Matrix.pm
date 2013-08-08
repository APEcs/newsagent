## @file
# This file contains the implementation of the article composition facility.
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
package Newsagent::Notification::Matrix;

use strict;
use base qw(Newsagent); # This class extends the Newsagent block class
use Newsagent::System::Matrix;
use v5.12;

# ============================================================================
#  Constructor

## @cmethod $ new(%args)
# Overloaded constructor for the feed facility, loads the System::Article model
# and other classes required to generate the feeds.
#
# @param args A hash of values to initialise the object with. See the Block docs
#             for more information.
# @return A reference to a new Newsagent::Feed object on success, undef on error.
sub new {
    my $invocant = shift;
    my $class    = ref($invocant) || $invocant;
    my $self     = $class -> SUPER::new(@_)
        or return undef;

    $self -> {"matrix"} = Newsagent::System::Matrix -> new(dbh      => $self -> {"dbh"},
                                                           settings => $self -> {"settings"},
                                                           logger   => $self -> {"logger"},
                                                           roles    => $self -> {"system"} -> {"roles"},
                                                           metadata => $self -> {"system"} -> {"metadata"})
        or return SystemModule::set_error("Matrix initialisation failed: ".$SystemModule::errstr);

    return $self;
}


# ============================================================================
#  Interface functions

## @method $ get_used_methods($userid)
# Determine which of the user's recipients have methods set.
#
# @param userid The ID of the user accessing the page/
# @return A referencce to a hash containing the selected matrix data.
sub get_used_methods {
    my $self   = shift;
    my $userid = shift;

    $self -> clear_error();

    # Generate the matrix data
    my $matrix = $self -> {"matrix"} -> get_user_matrix($userid)
        or return $self -> self_error("Unable to generate matrix: ".$self -> {"matrix"} -> errstr());

    # convert the set options to a usable format. Note that, at this point, there's no validation done
    # on whether the user can actually set the recipient/method - that is done in '_check_used_methods()'
    my @set_methods = $self -> {"cgi"} -> param("matrix");
    my $methods = {};
    foreach my $set_meth (@set_methods) {
        my ($recip, $meth) = $set_meth =~ /^(\d+)-(\d+)$/;

        if($recip && $meth) {
            $methods -> {$recip} -> {$meth} = 1;
        }
    }

    my $result = { "matrix" => $matrix };
    $self -> _check_used_methods($matrix, $methods, $result);

    return $result;
}


## @method $ build_matrix($userid, $selected, $acyear)
# Build a HTML block containing the recipient/method matrix.
#
# @param userid   The ID of the user accessing the page.
# @param selected A reference to a hash of selected methods.
# @param acyear   The ID of the selected academic year.
# @return A string containing the matrix html on success, undef
#         on error.
sub build_matrix {
    my $self     = shift;
    my $userid   = shift;
    my $selected = shift;
    my $acyear   = shift;

    $self -> clear_error();

    # Generate the matrix data
    my $matrix = $self -> {"matrix"} -> get_user_matrix($userid)
        or return $self -> self_error("Unable to generate matrix: ".$self -> {"matrix"} -> errstr());

    my $html = $self -> _build_matrix_level($matrix, $selected, "matrix");

    if($html) {
        # Get the list of all method divs
        my @methdivs = $html =~ /(matrix-methods-\d+)/g;

        # Spit out the MultiSelect code
        my $multisel = "";
        foreach my $method (@methdivs) {
            my ($id) = $method =~ /matrix-methods-(\d+)/;

            $multisel .= $self -> {"template"} -> load_template("matrix/multiselect.tem", {"***id***" => $id,
                                                                                           "***selector***" => $method});
        }

        # Build the year list
        my $years = $self -> {"system"} -> {"userdata"} -> get_valid_years(1)
            or return $self -> self_error($self -> {"system"} -> {"userdata"} -> errstr());

        # default the year
        $acyear = $years -> [0] -> {"value"} if(!$acyear);

        return $self -> {"template"} -> load_template("matrix/container.tem", {"***matrix***"   => $html,
                                                                               "***acyears***"  => $self -> {"template"} -> build_optionlist($years, $acyear),
                                                                               "***multisel***" => $multisel});
    }

    return "";
}


# ============================================================================
#  Private code

sub _build_matrix_level {
    my $self     = shift;
    my $level    = shift;
    my $selected = shift;
    my $baseid   = shift;

    my $result = "";
    foreach my $entry (@{$level}) {
        my $children = $self -> _build_matrix_level($entry -> {"children"}, $selected)
            if($entry -> {"children"});

        # If there are any children, wrap them in any supporting template
        $children = $self -> {"template"} -> load_template("matrix/childblock.tem", {"***children***" => $children,
                                                           })
            if($children);

        # Build the supported methods for this recipient (there may be none!)
        my $methods = "";
        foreach my $method (@{$entry -> {"methods"}}) {
            $methods .= $self -> {"template"} -> load_template("matrix/method.tem", {"***recipient***" => $method -> {"recipient_id"},
                                                                                     "***method***"    => $method -> {"method_id"},
                                                                                     "***name***"      => $method -> {"name"},
                                                                                     "***checked***"   => $selected -> {$method -> {"recipient_id"}} -> {$method -> {"method_id"}} ? 'checked="checked"' : ''});
        }

        $methods = $self -> {"template"} -> load_template("matrix/methodblock.tem", {"***methods***"   => $methods,
                                                                                     "***recipient***" => $entry -> {"id"}})
            if($methods);

        $result .= $self -> {"template"} -> load_template("matrix/entry.tem", {"***name***"     => $entry -> {"shortname"},
                                                                               "***title***"    => $entry -> {"name"},
                                                                               "***id***"       => $entry -> {"id"},
                                                                               "***children***" => $children,
                                                                               "***methods***"  => $methods,
                                                                               "***haschild***" => $children ? "haschild" : "",
                                                          });
    }

    $result = $self -> {"template"} -> load_template("matrix/level.tem", {"***level***" => $result,
                                                                          "***id***"    => $baseid ? "id=\"$baseid\"" : ""})
        if($result);

    return $result;
}



## @method private void _check_used_methods($level, $methods, $base)
# Determine which methods have been used at this level, or in the children
#
# @param level   A reference to an array containing the level to check methods at.
# @param methods A reference to a hash containing the methods the user has enabled.
# @param base    A reference to the base of the tree
sub _check_used_methods {
    my $self    = shift;
    my $level   = shift;
    my $methods = shift;
    my $base    = shift;

    foreach my $entry (@{$level}) {
        my $children = $self -> _check_used_methods($entry -> {"children"}, $methods, $base)
            if($entry -> {"children"});

        foreach my $method (@{$entry -> {"methods"}}) {
            if($methods -> {$entry -> {"id"}} -> {$method -> {"method_id"}}) {
                # Store the recipient/method mapping ID for this method
                push(@{$base -> {"used_methods"} -> {$method -> {"name"}}}, $method -> {"id"}) ;

                $base -> {"enabled"} -> {$entry -> {"id"}} -> {$method -> {"method_id"}} = 1;
                $method -> {"enabled"} = 1;
            }
        }
    }
}

1;
