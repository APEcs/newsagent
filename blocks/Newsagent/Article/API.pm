# @file
# This file contains the implementation of the API class
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
package Newsagent::Article::API;

use strict;
use base qw(Newsagent::Article); # This class extends the Newsagent article class
use Webperl::Utils qw(is_defined_numeric);
use v5.12;
use Data::Dumper;
# ============================================================================
#  Support functions

## @method private $ _explode_matrix($matrix)
# Given a string describing the enabled options in the recipient matrix of the
# form "recipientid-methodid,recipientid-methodid,...", produce an array of
# valid enabled options.
#
# @param matrix The string describing the enabled matrix options.
# @return A reference to an array of hashrefs, each element contains
#         {"recipient_id" => id, "method_id" => id} for a valid option.
sub _explode_matrix {
    my $self   = shift;
    my $matrix = shift;

    my @elements = split(/,/, $matrix);
    my @enabled = ();

    foreach my $element (@elements) {
        my ($recipid, $methid) = $element =~ /^(\d+)-(\d+)$/;

        # Only store the data from the matrix if it is valid
        push(@enabled, {"recipient_id" => $recipid, "method_id" => $methid})
            if($recipid && $methid);
    }

    return \@enabled;
}


# ============================================================================
#  API functions


sub _build_rcount_response {
    my $self = shift;

    my $yearid = is_defined_numeric($self -> {"cgi"}, "yearid")
        or return $self -> api_errorhash("internal_error", $self -> {"template"} -> replace_langvar("API_ERROR", {"***error***" => "{L_API_ERROR_NOYID}"}));

    my $setmatrix = $self -> {"cgi"} -> param("matrix")
        or return $self -> api_errorhash("internal_error", $self -> {"template"} -> replace_langvar("API_ERROR", {"***error***" => "{L_API_ERROR_NOMATRIX}"}));

    # Split the matrix into recipient/method hashes. If nothing comes out of this,
    # the data in $matrix is bad
    my $enabled = $self -> _explode_matrix($setmatrix);
    return $self -> api_errorhash("internal_error", $self -> {"template"} -> replace_langvar("API_ERROR", {"***error***" => "{L_API_ERROR_EMPTYMATRIX}"}))
        if(!scalar(@{$enabled}));

    my $matrix = $self -> {"module"} -> load_module("Newsagent::Notification::Matrix");

    # Now fetch the settings data for each recipient/method pair
    my $recipmeth = $matrix -> matrix_to_recipients($enabled, $yearid);

    # At this point, recipmeth contains the list of selected recipients, organised by the
    # method that will be used to contact them, and the settings that will be used by the
    # notification method to contact them. Now we need to go through these lists fetching
    # the counts for each
    foreach my $method (keys(%{$recipmeth -> {"methods"}})) {
        return $self -> api_errorhash("internal_error", $self -> {"template"} -> replace_langvar("API_ERROR", {"***error***" => "{L_API_ERROR_BADMETHOD}"}))
            if(!$self -> {"notify_methods"} -> {$method});

        foreach my $recip (@{$recipmeth -> {"methods"} -> {$method}}) {
            $recip -> {"recipient_count"} = $self -> {"notify_methods"} -> {$method} -> get_recipient_count($recip -> {"settings"})
                or return $self -> api_errorhash("internal_error", $self -> {"template"} -> replace_langvar("API_ERROR", {"***error***" => $self -> {"notify_methods"} -> {$method} -> errstr()}));
        }
    }

    die "Results:\n".Dumper($recipmeth)."\n";
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

    # Is this an API call, or a normal page operation?
    my $apiop = $self -> is_api_operation();
    if(defined($apiop)) {
        # API call - dispatch to appropriate handler.
        given($apiop) {
            when("rcount") { return $self -> api_response($self -> _build_rcount_response()); }
            default {
                return $self -> api_html_response($self -> api_errorhash('bad_op',
                                                                         $self -> {"template"} -> replace_langvar("API_BAD_OP")))
            }
        }
    } else {
        my $userbar = $self -> {"module"} -> load_module("Newsagent::Userbar");
        my $message = $self -> {"template"} -> message_box("{L_APIDIRECT_FAILED_TITLE}",
                                                           "error",
                                                           "{L_APIDIRECT_FAILED_SUMMARY}",
                                                           "{L_APIDIRECT_FAILED_DESC}",
                                                           undef,
                                                           "errorcore",
                                                           [ {"message" => $self -> {"template"} -> replace_langvar("SITE_CONTINUE"),
                                                              "colour"  => "blue",
                                                              "action"  => "location.href='".$self -> build_url(block => "compose", pathinfo => [])."'"} ]);

        return $self -> {"template"} -> load_template("error/general.tem",
                                                      {"***title***"     => "{L_APIDIRECT_FAILED_TITLE}",
                                                       "***message***"   => $message,
                                                       "***extrahead***" => "",
                                                       "***userbar***"   => $userbar -> block_display("{L_APIDIRECT_FAILED_TITLE}"),
                                                      })
    }
}

1;
