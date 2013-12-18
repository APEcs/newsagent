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
package Newsagent::Feed::RSS;

use strict;
use base qw(Newsagent::Feed); # This class extends the Newsagent Feed class
use Newsagent::System::Article;
use Encode;
use Digest::MD5 qw(md5_hex);
use CGI::Util qw(escape);
use Webperl::Utils qw(trimspace path_join);
use HTML::FormatText;
use HTML::Entities;
use v5.12;

# ============================================================================
#  Content generators

## @method $ embed_fulltext_image($article)
# Generate a div-wrapped version of the article to include in the fulltext that
# includes the article image.
#
# @param article The article to generate the fulltext with embedded image for
# @return A string containing the full text with embedded image
sub embed_fulltext_image {
    my $self    = shift;
    my $article = shift;
    my $image   = "";

    foreach my $img (@{$article -> {"images"}}) {
        # Skip images other than the article image
        next unless($img -> {"location"} && $img -> {"order"} == 1);

        my $url = $img -> {"location"};
        $url = path_join($self -> {"settings"} -> {"config"} -> {"Article:upload_image_url"},
                         $url)
            if($img -> {"type"} eq "file");

        $image = $self -> {"template"} -> load_template("feeds/rss/fulltext-image-img.tem", {"***class***" => "article",
                                                                                             "***url***"   => $url,
                                                                                             "***title***" => $article -> {"title"}});
    }

    return $self -> {"template"} -> load_template("feeds/rss/fulltext-image.tem", {"***image***" => $image,
                                                                                   "***text***"  => $article -> {"fulltext"}});
}


## @method void generate_feed()
# Generate an RSS feed of articles based on the filters specified by the user on
# the query string. Note that this does not return, and errors that occur inside
# are consumed silently - this is a design decision based on the fact that the
# feeds are going to be automatically aggregated, and errors getting through
# to the aggregators is likely to be an undesirable state of affairs.
sub generate_feed {
    my $self     = shift;

    my $settings = $self -> _validate_settings();
    my $results  = $self -> {"article"} -> get_feed_articles($settings);

    my $items   = "";
    my $maxdate = 0;
    foreach my $result (@{$results}) {
        my ($images, $extra) = ("", "");

        # Keep track of the latest date (should be the first result, really)
        $maxdate = $result -> {"release_time"}
            if($result -> {"release_time"} > $maxdate);

        # Build the image list
        foreach my $image (@{$result -> {"images"}}) {
            next if(!$image -> {"location"});

            # Work out where the image is
            my $url = $image -> {"location"};
            $url = path_join($self -> {"settings"} -> {"config"} -> {"Article:upload_image_url"},
                             $url)
                if($image -> {"type"} eq "file");

            $images .= $self -> {"template"} -> load_template("feeds/rss/image.tem", {"***url***"   => $url,
                                                                                      "***name***"  => $image -> {"name"},
                                                                                      "***order***" => $image -> {"order"}});
        }
        $images = $self -> {"template"} -> load_template("feeds/rss/images.tem", {"***images***" => $images})
            if($images);

        # Handle fulltext transform
        $result -> {"fulltext"} = $self -> cleanup_entities($result -> {"fulltext"})
            if($result -> {"fulltext"});

        given($result -> {"fulltext_mode"}) {
            when("markdown") { $result -> {"fulltext"} = $self -> make_markdown_body(Encode::encode("iso-8859-1", $result -> {"fulltext"})); }
            when("plain")    { $result -> {"fulltext"} = $self -> html_strip($result -> {"fulltext"}); }
            when("embedimg") { $result -> {"fulltext"} = $self -> embed_fulltext_image($result); }
        }

        # If fulltext is activated, and it isn't used in the description already, include the text in the item
        $extra .= $self -> {"template"} -> load_template("feeds/rss/newsagent.tem", {"***elem***"    => "fulltext",
                                                                                     "***attrs***"   => "",
                                                                                     "***content***" => "<![CDATA[\n".$result -> {"fulltext"}."\n]]>" })
            if($result -> {"fulltext_mode"} && !$result -> {"use_fulltext_desc"});

        # The date can be needed in both the title and date fields.
        my $pubdate = $self -> {"template"} -> format_time($result -> {"release_time"}, $self -> {"timefmt"});

        # Work out the feeds
        my $feeds = "";
        foreach my $feed (@{$result -> {"feeds"}}) {

            $feeds .= $self -> {"template"} -> load_template("feeds/rss/feed.tem", {"***description***" => $feed -> {"description"},
                                                                                    "***name***"        => $feed -> {"name"}});
        }

        # work out the URL
        my $feedurl = $self -> feed_url($settings -> {"viewer"}, $settings -> {"feeds"}, $result -> {"feeds"}, $result -> {"id"});

        # Put the item together!
        $items .= $self -> {"template"} -> load_template("feeds/rss/item.tem", {"***title***"       => $result -> {"title"} || $pubdate,
                                                                                "***description***" => $result -> {"use_fulltext_desc"} ? $result -> {"fulltext"} : $result -> {"summary"},
                                                                                "***images***"      => $images,
                                                                                "***feeds***"       => $feeds,
                                                                                "***extra***"       => $extra,
                                                                                "***date***"        => $pubdate,
                                                                                "***guid***"        => $self -> build_url(fullurl  => 1,
                                                                                                                          block    => "view",
                                                                                                                          pathinfo => [ "article", $result -> {"id"}]),
                                                                                "***link***"        => $feedurl,
                                                                                "***email***"       => $result -> {"email"},
                                                                                "***name***"        => $result -> {"realname"} || $result -> {"username"},
                                                                                "***gravhash***"    => md5_hex(lc(trimspace($result -> {"email"} || ""))),
                                                         });
    }

    # Construct a nice feed url
    my $rssurl = path_join($self -> {"cgi"} -> url(-base => 1), $self -> {"settings"} -> {"config"} -> {"scriptpath"}, "rss/");
    my $query  = "";

    # Can't use join/bap trickery here, as don't want to include "unset" elements
    foreach my $key (keys %{$settings}) {
        # skip settings not specified in the original query
        next unless($settings -> {$key} && defined($self -> {"cgi"} -> param($key)));

        $query .= "&amp;" if($query);
        $query .= $key."=".escape($settings -> {$key});
    }
    $rssurl .= "?$query" if($query);

    # Put everything together in a channel to send back to the user.
    my $feed = $self -> {"template"} -> load_template("feeds/rss/channel.tem", {"***generator***"   => "Newsagent",
                                                                                "***editor***"      => $self -> {"settings"} -> {"config"} -> {"RSS:editor"},
                                                                                "***webmaster***"   => $self -> {"settings"} -> {"config"} -> {"RSS:webmaster"},
                                                                                "***title***"       => $self -> {"settings"} -> {"config"} -> {"RSS:title"},
                                                                                "***description***" => $self -> {"settings"} -> {"config"} -> {"RSS:description"},
                                                                                "***link***"        => $rssurl,
                                                                                "***lang***"        => "en",
                                                                                "***now***"         => $self -> {"template"} -> format_time(time(), $self -> {"timefmt"}),
                                                                                "***changed***"     => $self -> {"template"} -> format_time($maxdate, $self -> {"timefmt"}),
                                                                                "***items***"       => $items,
                                                                                "***extra***"       => ""});

    # Do not use the normal page generation process to send back the feed - that sends back
    # html, not xml. This sends the feed to the user, and then cleans up and shuts down the
    # script.
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


sub html_strip {
    my $self = shift;
    my $text = shift;

    $text = Encode::encode("iso-8859-1", $text);
    my $tree = HTML::TreeBuilder -> new_from_content($text);

    my $formatter = HTML::FormatText -> new(leftmargin => 0, rightmargin => 50000);
    return $formatter -> format($tree);
}

1;
