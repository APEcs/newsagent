# Article Feeds

There are several ways to obtain feeds of articles stored in the system, currently
available methods are:

* RSS (RSS v2/Atom with custom 'newsagent' namespace), accessed via the `rss` path,
  for example: https://server.org/newsagent/rss/
* HTML accessed via the `html` path, for example: https://server.org/newsagent/html/

The different feed formats are accessed via unique URLs for simplicity, and they
share support for a number of query string parameters that control their behaviour.


## HTML Feeds

Three forms of HTML feed are provided by the system:

* `compact`: this feed includes only the date of publication and title of each
  article, suitable for sidebar feeds.
* `feed`: this feed includes article 'leader' images (if specified, with optional
  defaults if not), and the title, summary, and publication date of each article.
* `full`: this feed includes the full text, article image (if specified), title,
  and publication date of each article.

In order to access the different feeds, add the feed name to the path after the
`html/`. For example, https://server.org/newsagent/html/compact/ selects the
`compact `feed, while https://server.org/newsagent/html/full/ selects the `full`
feed. If no feed is explicitly selected, the `feed` version is used.


## Query String Parameters

The following query string parameters may used to modify the list of articles
obtained by any of the feeds. Some examples are given after the documentation.

* `id=<article id>` or `articleid=<article id>`: allows the selection of a
  specific article in the system by its internal id. In general, if you include
  the `id`or `articleid` parameter in the query string, you will want to avoid
  including any other parameters to ensure that the article you are trying to
  select is not filtered out by other parameters!

* `level=<selected level(s)>`: select only articles that have been set
  to be published at the specified level(s). This can either be a single
  level, eg: `level=home` or it can be a comma separated list of
  `levels=home,leader`. Valid levels are currently `home`, `leader`, and
  `group`. Note that, if the `urllevel` parameter is not set, the first
  level specified for this parameter is used. If this is not specified, it
  will default to selecting **all** levels.

* `urllevel=<level>`: control the level for which any automatically generated
  links are tailored to. This allows the same article to appear in a different
  location depending on the level selected, to support different full article
  viewing pages depending on the level provided. Normally you can omit this,
  and it will default to the value set for `level`, if that is set, or an
  internal default (usually `group` level).

* `feed=<selected feed(s)>`: select articles that have been published in the
  specified feed(s). This is, again, either a single feed name, or a comma
  separated list of feeds, eg: `feed=acso` or `feed=acso,apecs`

* `fulltext=enabled` turns on the inclusion of the full article text in
  each returned article. Note that this is ignored by the HTML feed - the
  full article text is always included when the `full` HTML feed is used,
  and it is never included for `compact` or `feed`.

* `count=<number>` lets you control how many items are included in the feed.
  The default is 10, there is a 'hard' maximum of 100 enforced by the system.

* `offset=<number>` lets you change where the feed starts from. Normally the
  feed starts with the newest item first, and then older items after it up
  to the count. With this you can tell it to skip items, so if you do
  `offset=5`, the first 5 newest items are skipped.

* `maxage=<number><d|m|y>` controls the maximum age of the articles included
  in the feed. If this is specified, only articles less than the specified
  age will be included. The number specified is, by default, the age in days
  but you can append `m` or `y` to indicate that the number is a number of
  months or years, eg: `maxage=6m` will mean that the feed will include
  articles that are up to 6 months old, `maxage=2y` will include articles
  up to two years old. The default for this is `1y`, ie: articles up to one
  year old will be included in the feed.

### Examples

The following will generate an RSS/Atom feed of the first 3 articles posted
from either the `foo` or `bar` feeds at the `leader` importance level:

    https://server.org/newsagent/rss/?level=leader&count=3&feed=foo,bar

This will generate a HTML feed of the first 10 articles posted at the `home`
importance level in a form suitable for inclusion in a sidebar:

    https://server.org/newsagent/html/compact/?level=home&count=10

This will generate a HTML feed containing the full text of just one article,
or no articles if the ID specified is incorrect:

    https://server.org/newsagent/html/full?id=42
