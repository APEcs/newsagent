# @file
# This file contains the implementation of the Newsletter base class.
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
package Newsagent::Newsletter;

use strict;
use base qw(Newsagent::Article); # This class extends the Newsagent Article class
use Webperl::Utils qw(trimspace path_join);
use Digest::MD5 qw(md5_hex);
use v5.12;


# ============================================================================
#  Content support

sub _build_newsletter_article {
    my $self     = shift;
    my $article  = shift;
    my $template = shift;

    # The date can be needed in both the title and date fields.
    my $pubdate = $self -> {"template"} -> format_time($article -> {"release_time"}, $self -> {"timefmt"});

    # Generate the image urls
    my @images;

    for(my $img = 0; $img < 2; ++$img) {
        next if(!$article -> {"images"} -> [$img] || !$article -> {"images"} -> [$img] -> {"location"});

        $images[$img] = $article -> {"images"} -> [$img] -> {"location"}
        if($article -> {"images"} -> [$img] -> {"location"});

        $images[$img] = path_join($self -> {"settings"} -> {"config"} -> {"Article:upload_image_url"},
                                  $images[$img])
            if($images[$img] && $images[$img] !~ /^http/);
    }

    # Wrap the images in html
    $images[0] = $self -> {"template"} -> load_template("newsletter/image.tem", {"***class***" => "leader",
                                                                                 "***url***"   => $images[0],
                                                                                 "***title***" => $article -> {"title"}})
        if($images[0]);

    $images[1] = $self -> {"template"} -> load_template("newsletter/image.tem", {"***class***" => "article",
                                                                                 "***url***"   => $images[1],
                                                                                 "***title***" => $article -> {"title"}})
        if($images[1]);

    $article -> {"article"} = $self -> cleanup_entities($article -> {"article"})
        if($article -> {"article"});

    return $self -> {"template"} -> load_template($template, { "***id***"          => $article -> {"id"},
                                                               "***title***"       => $article -> {"title"} || $pubdate,
                                                               "***summary***"     => $article -> {"summary"},
                                                               "***leaderimg***"   => $images[0],
                                                               "***articleimg***"  => $images[1],
                                                               "***email***"       => $article -> {"email"},
                                                               "***name***"        => $article -> {"realname"} || $article -> {"username"},
                                                               "***fulltext***"    => $article -> {"article"},
                                                               "***gravhash***"    => md5_hex(lc(trimspace($article -> {"email"} || ""))),
                                                  });
}


sub build_newsletter {
    my $self     = shift;
    my $newsname = shift;
    my $issue    = shift;
    my $userid   = $self -> {"session"} -> get_session_userid();
    my $content;

    my $newsletter = $self -> {"schedule"} -> active_newsletter($newsname, $userid);

    # If a newsletter is selected, build the page
    if($newsletter) {
        # Fetch the list of dates teh newsletter is released on (this is undef for manual releases)
        my $dates = $self -> {"schedule"} -> get_newsletter_datelist($newsletter, $self -> {"settings"} -> {"config"} -> {"newsletter:future_count"});

        # And work out the date range for articles that should appear in the selected issue
        my ($mindate, $maxdate, $usenext) = $self -> {"schedule"} -> get_newsletter_daterange($newsletter, $dates, $issue);

        # Fetch the messages set for the current newsletter
        my $messages = $self -> {"schedule"} -> get_newsletter_messages($newsletter -> {"id"}, $userid, $usenext, $mindate, $maxdate);
        my $body  = "";
        foreach my $section (@{$messages}) {
            next unless(scalar(@{$section -> {"messages"}}) || $section -> {"required"} || $section -> {"empty_tem"});

            my $articles = "";
            foreach my $message (@{$section -> {"messages"}}) {
                my $article = $self -> {"article"} -> get_article($message -> {"id"});

                $articles .= $self -> _build_newsletter_article($article, $section -> {"article_tem"});
            }

            # If the section contains no articles, use the empty template.
            $articles = $self -> {"template"} -> load_template($section -> {"empty_tem"})
                if(!$articles && $section -> {"empty_tem"});

            # If it's still empty, and required, make it as such
            $articles = $self -> {"template"} -> load_template("newsletter/list/required-section.tem")
                if(!$articles && $section -> {"required"});

            # And add this section to the accumulating page
            $body .= $self -> {"template"} -> load_template($section -> {"template"}, {"***articles***" => $articles,
                                                                                       "***title***"    => $section -> {"name"},
                                                                                       "***id***"       => $section -> {"id"}});
        }

        $content = $self -> {"template"} -> load_template(path_join($newsletter -> {"template"}, "body.tem"), {"***name***"        => $newsletter -> {"name"},
                                                                                                               "***description***" => $newsletter -> {"description"},
                                                                                                               "***id***"          => $newsletter -> {"id"},
                                                                                                               "***body***"        => $body});
    }

    return ($content, $newsletter);
}

1;
