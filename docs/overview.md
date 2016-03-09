System Structure
================

The top level of the Newsagent application consists of a number of directories,
each of which serves a specific purpose:

- admin: This directory contains various admin-specific tools that must be
  invoked from the command line. They're not considered part of the web app
  as such, but provide tools to update or query parts of its data.

- blocks: This tree contains the view and controller modules for the
  application; they contain the logic that creates the pages and handles
  user input. Modules in this tree that can be invoked via the web interface
  must be registered in the 'modules' table in the database, and have their
  block name the `blocks` table in the database. Note that not all modules
  in this tree have corresponding web access points: they may be the view
  modules for internal operations (for example, the modules under the
  `blocks/Newsagent/Notification` directory are there to handle notification
  generation)

- config: contains the configuration and some setup information. The key file
  here is the `site.cfg` which contains the core system settings. Additional
  system settings are stored in the `settings` table in the database.

- images: this directory contains a tree of processed images uploaded by the
  users via the image library interface.

- lang: The language file definitions. This contains subdirectories for each
  supported language, each containing the .lang files containing the system
  text strings. Updates to these files are not automatically picked up: the
  supportfiles/lang_to_db.pl file must be run to update the master list.

- modules: contains the common and model modules. These modules contain logic
  that must be common to model, view, and controller code; modules that are
  needed to support the framework; and modules that implement the data models
  for the system.

- supportfiles: These are miscellaneous scripts and support files used to
  do maintenance and support documentation generation.

- templates: This contains the system template files, including any javascript
  or css files that need to be web-accessible.

- uploads: files uploaded to Newsagent via the compose or edit forms are
  stored in this directory.

Query execution flow
--------------------

The general flow of execution can be thought of as follows (many details
omitted for clarity; please consult the module documentation for details):

- In a browser, the user enters the URL of a newsagent page. For the
  sake of example, say they are attempting to create an article, and thus
  visiting https://newsagent.cs.manchester.ac.uk/compose

- The request is sent from the web browser to the Apache service on the server.

- Before anything is invoked, Apache processes the directives inthe .htaccess
  file in the Newsagent directory. Given the above URL this step rewrites it
  to https://newsagent.cs.manchester.ac.uk/index.cgi/compose

- index.cgi is executed. This perfoms low-level setup, loads the Newsagent
  specific AppUser, BlockSelector, and System modules (under mod_perl,
  they are already in memory). It then invokes the Application constructor
  passing it the Newsagent specific modules and then runs it.

- the run() does the rest of the system setup:
  - it loads the basic config, connects to the database, loads the rest of
    the configuration, starts logging for the thread, sets up the core
    modules (message queues, templates, authentication system, template and
    language handling, dynamic module handling, and other system init tasks).
  - Once everything is set up, it uses the Newsagent::BlockSelector class to
    determine which block the user is attempting to access; in this case,
    the `compose` block.
  - The module loader is used to load the block module (the `blocks` table
    shows that `compose` is registered with the module ID 1, module ID 1 in
    the `modules` table gives the name as `Newsagent::Article::Compose`).
  - The `page_display()` function of the loaded block module is executed
    to generate the page.

- Within the `page_display()` function, typically several stages happen:
  - Some blocks may call Newsagent::check_login() to require a logged in
    session and will force a redirect to the login page if needed, others
    can be used with an anonymous session.
  - some modules will check whether the user has access to do anything
    with them at all using the Newsagent::check_permission() function
  - some modules support both normal page requests and API operations, and
    the `page_display()` function will usually distinguish between them
    and use separate dispatchers for the different paths: one given/when
    block for API operations and another for normal page operations.

Generally, each block module will take some arguments from the pathinfo
string, and some from the query string.