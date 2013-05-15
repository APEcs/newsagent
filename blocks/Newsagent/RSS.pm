# @file
# This file contains the implementation of the RSS/API facility.
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
package Newsagent::RSS;

use strict;
use base qw(Newsagent); # This class extends the Newsagent block class
use Newsagent::System::Article;
use v5.12;

use Webperl::Utils qw(path_join);
use Data::Dumper;

# ============================================================================
#  Constructor

## @cmethod $ new(%args)
# Overloaded constructor for the RSS facility, loads the System::Article model
# and other classes required to generate the RSS feeds.
#
# @param args A hash of values to initialise the object with. See the Block docs
#             for more information.
# @return A reference to a new Newsagent::RSS object on success, undef on error.
sub new {
    my $invocant = shift;
    my $class    = ref($invocant) || $invocant;
    my $self     = $class -> SUPER::new("timefmt" => '%a, %d %b %Y %H:%M:%S %z',
                                        @_)
        or return undef;

    $self -> {"article"} = Newsagent::System::Article -> new(dbh      => $self -> {"dbh"},
                                                             settings => $self -> {"settings"},
                                                             logger   => $self -> {"logger"},
                                                             roles    => $self -> {"system"} -> {"roles"},
                                                             metadata => $self -> {"system"} -> {"metadata"})
        or return SystemModule::set_error("RSS initialisation failed: ".$SystemModule::errstr);

    return $self;
}


# ============================================================================
#  Validation code

## @method private $ _validate_settings()
# Validate any settings specified by the user on the query string, and create a
# hash containing the validated settings.
#
# @return A reference to a hash of query settings.
sub _validate_settings {
    my $self     = shift;
    my $settings = {};
    my $error;

    # Fulltext flag is simple to handle
    $settings -> {"fulltext"} = 1
        if(defined($self -> {"cgi"} -> param("fulltext")));

    # count and offset are easy
    ($settings -> {"id"}, $error)  = $self -> validate_numeric("id", {"required" => 0,
                                                                      "intonly"  => 1,
                                                               });
    ($settings -> {"count"}, $error)  = $self -> validate_numeric("count", {"required" => 0,
                                                                            "intonly"  => 1,
                                                                            "default"  => $self -> {"settings"} -> {"config"} -> {"Article:rss_count"},
                                                                            "min"      => 1,
                                                                            "max"      => $self -> {"settings"} -> {"config"} -> {"Article:rss_count_limit"},
                                                                            "nicename" => ""
                                                                  });
    ($settings -> {"offset"}, $error)  = $self -> validate_numeric("offset", {"required" => 0,
                                                                              "intonly"  => 1,
                                                                              "default"  => 0,
                                                                              "min"      => 0,
                                                                              "nicename" => ""
                                                                   });

    # Site and level are up next
    ($settings -> {"site"}, $error) = $self -> validate_string("site", {"required"   => 0,
                                                                        "default"    => "",
                                                                        "formattest" => '^\w+(?:,\w+)*$',
                                                                        "formatdesc" => "",
                                                                        "nicename"   => ""});
    ($settings -> {"level"}, $error) = $self -> validate_string("level", {"required"   => 0,
                                                                          "default"    => "",
                                                                          "formattest" => '^\w+(?:,\w+)*$',
                                                                          "formatdesc" => "",
                                                                          "nicename"   => ""});

    return $settings;
}


# ============================================================================
#  Content generators

sub generate_feed {
    my $self     = shift;
    my $settings = {};

    my $results = $self -> {"article"} -> get_feed_articles($self -> _validate_settings());

    my $items   = "";
    my $maxdate = 0;
    foreach my $result (@{$results}) {
        my ($images, $extra) = ("", "");

        # Keep track of the latest date (should be the first result, really)
        $maxdate = $result -> {"release_time"}
            if($result -> {"release_time"} > $maxdate);

        # Build the image list
        foreach my $image (@{$result -> {"images"}}) {
            # Work out where the image is
            my $url = $image -> {"location"};
            $url = path_join($self -> {"settings"} -> {"config"} -> {"Article:upload_image_url"}, $url)
                if($image -> {"type"} eq "file");

            $images .= $self -> {"template"} -> load_template("rss/image.tem", {"***url***" => $url,
                                                                                "***name***" => $image -> {"name"}});
        }
        $images = $self -> {"template"} -> load_template("rss/images.tem", {"***images***" => $images})
            if($images);

        $extra .= $self -> {"template"} -> load_template("rss/newsagent.tem", {"***elem***"    => "fulltext",
                                                                               "***attrs***"   => "",
                                                                               "***content***" => "<![CDATA[\n".$result -> {"fulltext"}."\n]]>" })
            if($result -> {"fulltext"});

        my $pubdate = $self -> {"template"} -> format_time($result -> {"release_time"}, $self -> {"timefmt"});

        $items .= $self -> {"template"} -> load_template("rss/item.tem", {"***title***"       => $result -> {"title"} || $pubdate,
                                                                          "***description***" => $result -> {"summary"},
                                                                          "***images***"      => $images,
                                                                          "***site***"        => $result -> {"sitename"},
                                                                          "***extra***"       => $extra,
                                                                          "***date***"        => $pubdate,
                                                                          "***guid***"        => $result -> {"siteurl"}."?id=".$result -> {"id"},
                                                                          "***link***"        => $result -> {"siteurl"}."?id=".$result -> {"id"},
                                                         });
    }

    my $feed = $self -> {"template"} -> load_template("rss/channel.tem", {"***generator***"   => "Newsagent",
                                                                          "***editor***"      => $self -> {"settings"} -> {"config"} -> {"RSS:editor"},
                                                                          "***webmaster***"   => $self -> {"settings"} -> {"config"} -> {"RSS:webmaster"},
                                                                          "***title***"       => $self -> {"settings"} -> {"config"} -> {"RSS:title"},
                                                                          "***description***" => $self -> {"settings"} -> {"config"} -> {"RSS:description"},
                                                                          "***link***"        => path_join($self -> {"cgi"} -> url(-base => 1),
                                                                                                           $self -> {"settings"} -> {"config"} -> {"scriptpath"}, "rss"),
                                                                          "***lang***"        => "en",
                                                                          "***now***"         => $self -> {"template"} -> format_time(time(), $self -> {"timefmt"}),
                                                                          "***changed***"     => $self -> {"template"} -> format_time($maxdate, $self -> {"timefmt"}),
                                                                          "***items***"       => $items,
                                                                          "***extra***"       => ""});

    print $self -> {"cgi"} -> header(-type => 'application/xml',
                                     -charset => 'utf-8');
    print Encode::encode_utf8($feed);

    $self -> {"template"} -> set_module_obj(undef);
    $self -> {"messages"} -> set_module_obj(undef);
    $self -> {"system"} -> clear() if($self -> {"system"});
    $self -> {"session"} -> {"auth"} -> {"app"} -> set_system(undef) if($self -> {"session"} -> {"auth"} -> {"app"});

    $self -> {"dbh"} -> disconnect();
    $self -> {"logger"} -> end_log();

    exit;
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
            default {
                return $self -> api_xml_response($self -> api_errorhash('bad_op',
                                                                        $self -> {"template"} -> replace_langvar("API_BAD_OP")))
            }
        }
    } else {
        my @pathinfo = $self -> {"cgi"} -> param('pathinfo');
        # Normal page operation.
        # ... handle operations here...

        $self -> generate_feed();
    }
}

1;
