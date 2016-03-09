Operations
==========

This is a quick look-up mapping for web-accessible base paths into
newsagent and how they map to view/controller blocks:

| Path         | Module                         |
|--------------|--------------------------------|
| /articles    | Newsagent::Article::List       |
| /compose     | Newsagent::Article::Compose    |
| /cron        | Newsagent::Article::Cron       |
| /edit        | Newsagent::Article::Edit       |
| /feeds       | Newsagent::FeedList            |
| /html        | Newsagent::Feed::HTML          |
| /import      | Newsagent::Import              |
| /login       | Newsagent::Login               |
| /newsletters | Newsagent::Newsletter::List    |
| /queues      | Newsagent::TellUs::List        |
| /rss         | Newsagent::Feed::RSS           |
| /subscribe   | Newsagent::Subscriptions       |
| /subscron    | Newsagent::Subscriptions::Cron |
| /tellus      | Newsagent::TellUs::Compose     |
| /webapi      | Newsagent::Article::API        |

Note that these may be subject to change (in particular, `webapi`
may be changed to `rest`)
