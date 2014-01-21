## @file
# This file contains the implementation of the Twitter message method.
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
package Newsagent::Notification::Method::Twitter;

use strict;
use base qw(Newsagent::Notification::Method); # This class is a Method module
use v5.12;

## @cmethod Newsagent::Notification::Method::Twitter new(%args)
# Create a new Twitter object. This will create an object
# that may be used to send messages to recipients over SMTP.
#
# @param args A hash of arguments to initialise the Twitter
#             object with.
# @return A new Twitter object.
sub new {
    my $invocant = shift;
    my $class    = ref($invocant) || $invocant;
    my $self     = $class -> SUPER::new(@_)
        or return undef;

    # Make local copies of the config for readability

    # Possible twitter text modes
    $self -> {"twittermodes"} = [ {"value" => "summary",
                                   "name"  => "{L_METHOD_TWEET_MODE_SUMM}",
                                  },
                                  {"value" => "custom",
                                   "name"  => "{L_METHOD_TWEET_MODE_OWN}",
                                  },
                                ];
    $self -> {"twitterauto"}  = [ {"value" => "link",
                                   "name"  => "{L_METHOD_TWEET_AUTO_LINK}",
                                  },
                                  {"value" => "news",
                                   "name"  => "{L_METHOD_TWEET_AUTO_NEWS}",
                                  },
                                  {"value" => "none",
                                   "name"  => "{L_METHOD_TWEET_AUTO_NONE}",
                                  },
                                ];

    return $self;
}


################################################################################
#  View and controller functions
################################################################################

## @method $ generate_compose($args, $user)
# Generate the string to insert into the compose page for this method.
#
# @param args A reference to a hash of arguments to use in the form
# @param user A reference to a hash containing the user's data
# @return A string containing the article form fragment.
sub generate_compose {
    my $self = shift;
    my $args = shift;
    my $user = shift;

    return $self -> {"template"} -> load_template("Notification/Method/Twitter/compose.tem", {"***twitter-mode***" => $self -> {"template"} -> build_optionlist($self -> {"twittermodes"}, $args -> {"methods"} -> {"Twitter"} -> {"mode"}),
                                                                                              "***twitter-text***" => $self -> {"template"} -> html_clean($args -> {"methods"} -> {"Twitter"} -> {"tweet"}),
                                                                                              "***twitter-auto***" => $self -> {"template"} -> build_optionlist($self -> {"twitterauto"}, $args -> {"methods"} -> {"Twitter"} -> {"auto"}),
                                                  });
}

1;
