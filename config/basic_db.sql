-- phpMyAdmin SQL Dump
-- version 4.3.6
-- http://www.phpmyadmin.net
--
-- Host: localhost
-- Generation Time: Jan 16, 2015 at 02:30 PM
-- Server version: 5.6.22-log
-- PHP Version: 5.5.18-pl0-gentoo

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;

--
-- Database: `newsagent`
--

-- --------------------------------------------------------

--
-- Table structure for table `auth_methods`
--

CREATE TABLE IF NOT EXISTS `auth_methods` (
  `id` tinyint(3) unsigned NOT NULL,
  `perl_module` varchar(100) NOT NULL COMMENT 'The name of the AuthMethod (no .pm extension)',
  `priority` tinyint(4) NOT NULL COMMENT 'The authentication method''s priority. -128 = max, 127 = min',
  `enabled` tinyint(1) NOT NULL COMMENT 'Is this auth method usable?'
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Stores the authentication methods supported by the system';

--
-- Dumping data for table `auth_methods`
--

INSERT INTO `auth_methods` (`id`, `perl_module`, `priority`, `enabled`) VALUES
(1, 'Webperl::AuthMethod::Database', 0, 1);

-- --------------------------------------------------------

--
-- Table structure for table `auth_methods_params`
--

CREATE TABLE IF NOT EXISTS `auth_methods_params` (
  `id` int(10) unsigned NOT NULL,
  `method_id` tinyint(4) NOT NULL COMMENT 'The id of the auth method',
  `name` varchar(40) NOT NULL COMMENT 'The parameter mame',
  `value` text NOT NULL COMMENT 'The value for the parameter'
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Stores the settings for each auth method';

--
-- Dumping data for table `auth_methods_params`
--

INSERT INTO `auth_methods_params` (`id`, `method_id`, `name`, `value`) VALUES
(1, 1, 'table', 'users'),
(2, 1, 'userfield', 'username'),
(3, 1, 'passfield', 'password');

-- --------------------------------------------------------

--
-- Table structure for table `blocks`
--

CREATE TABLE IF NOT EXISTS `blocks` (
  `id` smallint(5) unsigned NOT NULL COMMENT 'Unique ID for this block entry',
  `name` varchar(32) NOT NULL,
  `module_id` smallint(5) unsigned NOT NULL COMMENT 'ID of the module implementing this block',
  `args` varchar(128) NOT NULL COMMENT 'Arguments passed verbatim to the block module'
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='web-accessible page modules';

--
-- Dumping data for table `blocks`
--

INSERT INTO `blocks` (`id`, `name`, `module_id`, `args`) VALUES
(1, 'compose', 1, ''),
(2, 'login', 2, ''),
(3, 'rss', 3, ''),
(4, 'html', 4, ''),
(5, 'articles', 5, ''),
(6, 'edit', 6, ''),
(7, 'cron', 7, ''),
(8, 'webapi', 8, ''),
(9, 'feeds', 9, ''),
(10, 'import', 10, ''),
(11, 'tellus', 11, ''),
(12, 'queues', 12, ''),
(13, 'newsletters', 13, '');

-- --------------------------------------------------------

--
-- Table structure for table `language`
--

CREATE TABLE IF NOT EXISTS `language` (
  `id` int(10) unsigned NOT NULL,
  `name` varchar(255) COLLATE utf8_unicode_ci NOT NULL COMMENT 'The language variable name',
  `lang` varchar(8) COLLATE utf8_unicode_ci NOT NULL DEFAULT 'en' COMMENT 'The language the variable is in',
  `message` text COLLATE utf8_unicode_ci NOT NULL COMMENT 'The language variable message'
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci COMMENT='Stores language variable definitions';

--
-- Dumping data for table `language`
--

INSERT INTO `language` (`id`, `name`, `lang`, `message`) VALUES
(1, 'ALIST_TITLE', 'en', 'Article list'),
(2, 'ALIST_CREATED', 'en', 'Created'),
(3, 'ALIST_UPDATED', 'en', 'Updated'),
(4, 'ALIST_RELHIDDEN', 'en', 'Hidden (not currently published)'),
(5, 'ALIST_RELNOW', 'en', 'Released immediately'),
(6, 'ALIST_RELTIME_WAIT', 'en', 'Waiting for timed release'),
(7, 'ALIST_RELTIME_PASSED', 'en', 'Released after timed release'),
(8, 'ALIST_RELNONE', 'en', 'Draft article (never released)'),
(9, 'ALIST_RELEDIT', 'en', 'Edited (not publicly visible)'),
(10, 'ALIST_RELDELETED', 'en', 'Deleted'),
(11, 'ALIST_RELTEMPLATE', 'en', 'Template: ***preset***'),
(12, 'ALIST_RELNEWSNEXT', 'en', 'Released in next newsletter'),
(13, 'ALIST_RELNEWSAFTER', 'en', 'Released after ***afterdate***'),
(14, 'ALIST_RELNEWSUSED', 'en', 'Used in newsletter'),
(15, 'ALIST_FILTER_RELHIDDEN', 'en', 'Hidden'),
(16, 'ALIST_FILTER_RELNOW', 'en', 'Published'),
(17, 'ALIST_FILTER_RELTIME_WAIT', 'en', 'Timed'),
(18, 'ALIST_FILTER_RELTIME_PASSED', 'en', 'Released'),
(19, 'ALIST_FILTER_RELNONE', 'en', 'Draft'),
(20, 'ALIST_FILTER_RELEDIT', 'en', 'Edited'),
(21, 'ALIST_FILTER_RELTEMPLATES', 'en', 'Templates'),
(22, 'ALIST_FILTER_RELNEWSNEXT', 'en', 'Newsletter (next)'),
(23, 'ALIST_FILTER_RELNEWSAFTER', 'en', 'Newsletter (timed)'),
(24, 'ALIST_FILTER_RELNEWSUSED', 'en', 'Used in newsletter'),
(25, 'ALIST_CTRLEDIT', 'en', 'Edit this article'),
(26, 'ALIST_CTRLCLONE', 'en', 'Clone this article'),
(27, 'ALIST_CTRLHIDE', 'en', 'Unpublish (hide) this article'),
(28, 'ALIST_CTRLDELETE', 'en', 'Delete this article (can''t be undone!)'),
(29, 'ALIST_CTRLUNDELETE', 'en', 'Restore this article'),
(30, 'ALIST_CTRLUNHIDE', 'en', 'Show this article'),
(31, 'ALIST_CTRLPUBLISH', 'en', 'Publish this article immediately'),
(32, 'ALIST_EMPTYMONTH', 'en', 'There are no articles available in this month.'),
(33, 'ALIST_RESTORE', 'en', 'Remove filtering'),
(34, 'ALIST_SHOWFEED', 'en', 'Show feeds:'),
(35, 'ALIST_FEEDSEL', 'en', 'Select feeds...'),
(36, 'ALIST_SHOWMODES', 'en', 'Status:'),
(37, 'ALIST_MODESEL', 'en', 'Select states...'),
(38, 'ALIST_MORE', 'en', 'More...'),
(39, 'ALIST_MODE', 'en', 'Mode'),
(40, 'ALIST_SENDTIME', 'en', 'Send after'),
(41, 'ALIST_NEWSLETTER', 'en', 'Newsletter'),
(42, 'ALIST_NEWSSECT', 'en', 'Section'),
(43, 'USERBAR_PROFILE_EDIT', 'en', 'Edit Profile'),
(44, 'USERBAR_PROFILE_PREFS', 'en', 'Change Settings'),
(45, 'USERBAR_PROFILE_LOGOUT', 'en', 'Log out'),
(46, 'USERBAR_PROFILE_LOGIN', 'en', 'Log in'),
(47, 'USERBAR_ARTICLE_LIST', 'en', 'Article list'),
(48, 'USERBAR_COMPOSE', 'en', 'Add an article'),
(49, 'USERBAR_SITE_SETTINGS', 'en', 'Administer site'),
(50, 'USERBAR_NEWSLETTER_LIST', 'en', 'Newsletter editor'),
(51, 'USERBAR_LOGIN_USER', 'en', 'Username'),
(52, 'USERBAR_LOGIN_PASS', 'en', 'Password'),
(53, 'USERBAR_LOGIN', 'en', 'Log in'),
(54, 'USERBAR_TEMPLATES', 'en', 'Templates'),
(55, 'USERBAR_DOCLINK', 'en', 'Documentation (opens in new window)'),
(56, 'USERBAR_FRONT', 'en', 'Newsagent front page (Feed list)'),
(57, 'USERBAR_FEEDS', 'en', 'RSS Feeds'),
(58, 'USERBAR_TELLUS', 'en', 'Tell Us!'),
(59, 'USERBAR_TELLUS_QUEUES', 'en', 'Tell Us Messages'),
(60, 'NEWSLETTER_NONEWS', 'en', 'No newsletters found'),
(61, 'NEWSLETTER_LIST_TITLE', 'en', 'Newsletter Editor'),
(62, 'NEWSLETTER_PREVIEW', 'en', 'Preview this issue'),
(63, 'NEWSLETTER_PUBLISH', 'en', 'Publish this issue'),
(64, 'NEWSLETTER_NOPUBLISH', 'en', 'You do not have permission to publish this newsletter.'),
(65, 'NEWSLETTER_TYPE', 'en', 'Type:'),
(66, 'NEWSLETTER_TYPE_MANUAL', 'en', 'Manual (click ''publish'' to release this issue)'),
(67, 'NEWSLETTER_TYPE_AUTO', 'en', 'Automatic'),
(68, 'NEWSLETTER_MODE_MANUAL', 'en', 'Manual release newsletter ''***name***'''),
(69, 'NEWSLETTER_MODE_AUTO', 'en', 'Automatic release newsletter ''***name***'''),
(70, 'NEWSLETTER_MODE_ALERT', 'en', 'Blocked automatic release, requires attention.'),
(71, 'NEWSLETTER_LIST_SAVING', 'en', 'Saving article order'),
(72, 'NEWSLETTER_LIST_SAVED', 'en', 'Article order saved'),
(73, 'NEWSLETTER_ERR_NOSORT', 'en', 'No sort information in posted data'),
(74, 'NEWSLETTER_ERR_BADSORT', 'en', 'The sort data receieved by the API cannot be parsed.'),
(75, 'NEWSLETTER_LIST_PREVIEW', 'en', 'Preview: ''***newsletter***'''),
(76, 'NEWSLETTER_LIST_REQUIRED', 'en', 'This section does not contain enough articles for publication: the section contains ***count*** article(s), but ***required*** article(s) are required. This newsletter can not be published until the required number of articles have been added to this section.'),
(77, 'NEWSLETTER_PUBLISH_FAILED', 'en', 'Newsletter publication failed'),
(78, 'NEWSLETTER_PUBLISHED', 'en', 'Newsletter published successfully.'),
(79, 'NEWSLETTER_PUBLISHBLOCK', 'en', 'Publication blocked; one or more required sections empty!'),
(80, 'NEWSLETTER_API_BADNAME', 'en', 'Illegal characters detected in newsletter name.'),
(81, 'NEWSLETTER_API_PUBLISHED', 'en', 'Newsletter published successfully!<br /><br />You can view the published article by <a href="***viewurl***">clicking here</a>.'),
(82, 'NEWSLETTER_PUBLISHING', 'en', 'Publishing...'),
(83, 'NEWSLETTER_REQUIRED', 'en', 'required'),
(84, 'EDIT_ERROR_TITLE', 'en', 'Edit error'),
(85, 'EDIT_ERROR_NOID_SUMMARY', 'en', 'No article ID specified.'),
(86, 'EDIT_ERROR_NOID_DESC', 'en', 'The system has been unable to determine which article you want to edit, as no ID has been passed to it. If you followed a link to this page, please report it to <a href="mailto:{V_[admin_email]}">{V_[admin_email]}</a>.'),
(87, 'EDIT_ERROR_BADID_SUMMARY', 'en', 'Unable to obtain the data for the requested article.'),
(88, 'EDIT_FORM_TITLE', 'en', 'Edit article'),
(89, 'EDIT_ARTICLE', 'en', 'Edit article'),
(90, 'EDIT_SUBMIT', 'en', 'Edit article'),
(91, 'EDIT_ISMINOR', 'en', 'This is a minor edit.'),
(92, 'CLONE_SUBMIT', 'en', 'Create article'),
(93, 'CLONE_FORM_TITLE', 'en', 'Clone article'),
(94, 'TEMPLATE_SUBMIT', 'en', 'Create article'),
(95, 'TEMPLATE_FORM_TITLE', 'en', 'Create article from template'),
(96, 'EDIT_FAILED', 'en', 'Article editing failed'),
(97, 'EDIT_EDITED_TITLE', 'en', 'Article Edited'),
(98, 'EDIT_EDITED_SUMMARY', 'en', 'Article edited successfully.'),
(99, 'EDIT_EDITED_DESC', 'en', 'Your article has been updated successfully. If you set it for immediate publication, it should be visible on feeds now; timed articles will be released when the selected time has passed. Click ''Continue'' to return to your message list.'),
(100, 'EDIT_CONFIRM_INTRO', 'en', 'Before your article is updated, please check the information provided here.'),
(101, 'EDIT_ERRORS', 'en', 'Your article can not be updated at this time because:'),
(102, 'CRON_ATEACHDAY', 'en', 'At ***times*** each day,'),
(103, 'CRON_EACHMINUNTE', 'en', 'Every munute during the ***hour*** hour each day,'),
(104, 'CRON_MINUTEPAST', 'en', 'At ***minutes*** past each hour,'),
(105, 'CRON_DAYMONTH', 'en', '" on the ***day*** day of the month"'),
(106, 'CRON_ORDAYWEEK', 'en', '" and every ***days***"'),
(107, 'CRON_DAYWEEK', 'en', '" every ***days***"'),
(108, 'CRON_MONTHS', 'en', '" during ***months***"'),
(109, 'CRON_RANGE', 'en', '***start*** through ***end***'),
(110, 'CRON_AND', 'en', 'and ***last***'),
(111, 'CRON_SUNDAY', 'en', 'Sunday'),
(112, 'CRON_MONDAY', 'en', 'Monday'),
(113, 'CRON_TUESDAY', 'en', 'Tuesday'),
(114, 'CRON_WEDNESDAY', 'en', 'Wednesday'),
(115, 'CRON_THURSDAY', 'en', 'Thursday'),
(116, 'CRON_FRIDAY', 'en', 'Friday'),
(117, 'CRON_SATURDAY', 'en', 'Saturday'),
(118, 'CRON_JAN', 'en', 'January'),
(119, 'CRON_FEB', 'en', 'February'),
(120, 'CRON_MAR', 'en', 'March'),
(121, 'CRON_APR', 'en', 'April'),
(122, 'CRON_MAY', 'en', 'May'),
(123, 'CRON_JUN', 'en', 'June'),
(124, 'CRON_JUL', 'en', 'July'),
(125, 'CRON_AUG', 'en', 'August'),
(126, 'CRON_SEP', 'en', 'September'),
(127, 'CRON_OCT', 'en', 'October'),
(128, 'CRON_NOV', 'en', 'November'),
(129, 'CRON_DEC', 'en', 'December'),
(130, 'CRONJOB_TITLE', 'en', 'Newsagent Cron Processor'),
(131, 'CRONJOB_NOPENDING', 'en', 'No pending notifications to send at this time.'),
(132, 'CRONJOB_SUMMARY', 'en', 'Notification summary'),
(133, 'CRONJOB_ID', 'en', 'ID'),
(134, 'CRONJOB_ARTICLE', 'en', 'Article ID'),
(135, 'CRONJOB_METHOD', 'en', 'Method'),
(136, 'CRONJOB_YEAR', 'en', 'Year ID'),
(137, 'CRONJOB_RELEASED', 'en', 'Released'),
(138, 'CRONJOB_STATUS', 'en', 'Notification delivery status'),
(139, 'CRONJOB_STATE', 'en', 'Status'),
(140, 'CRONJOB_NAME', 'en', 'Recipient'),
(141, 'CRONJOB_MESSAGE', 'en', 'Message'),
(142, 'CRON_NOTIFY_STATUS', 'en', 'Notifications for ''***article***'''),
(143, 'CRON_NOTIFY_INTRO', 'en', 'Dear ***realname***,'),
(144, 'CRON_NOTIFY_ABOUT', 'en', 'This email contains information about the notifications sent by Newsagent for your recent article'),
(145, 'CRON_NOTIFY_STATES', 'en', 'The statuses of the notifications sent via "***method***" are:'),
(146, 'CRON_NOTIFY_HELPME', 'en', 'If you need help with this message, please reply to it.'),
(147, 'MEDIA_SELECT', 'en', 'Select an image...'),
(148, 'MEDIA_UPLOAD', 'en', '... or upload a new one'),
(149, 'UPLOADER_DROPHERE', 'en', 'Drop image to upload here'),
(150, 'API_BAD_OP', 'en', 'Unknown API operation requested.'),
(151, 'API_BAD_CALL', 'en', 'Incorrect invocation of an API-only module.'),
(152, 'API_ERROR', 'en', 'An internal API error has occurred: ***error***'),
(153, 'API_ERROR_NOAID', 'en', 'No article ID was included in the API request.'),
(154, 'API_ERROR_NOYID', 'en', 'No year ID was included in the API request.'),
(155, 'API_ERROR_NOMATRIX', 'en', 'No recipient and method information was included in the API request'),
(156, 'API_ERROR_EMPTYMATRIX', 'en', 'The specified recipient and method information appears to be invalid'),
(157, 'API_ERROR_BADMETHOD', 'en', 'Attempt to use an unknown delivery method.'),
(158, 'APIDIRECT_FAILED_TITLE', 'en', 'Direct access error'),
(159, 'APIDIRECT_FAILED_SUMMARY', 'en', 'Unsupported attempt to directly access the API'),
(160, 'APIDIRECT_FAILED_DESC', 'en', 'The Newsagent API does not support direct client access. Please refer to the API documentation for more information.'),
(161, 'PERMISSION_FAILED_TITLE', 'en', 'Access denied'),
(162, 'PERMISSION_FAILED_SUMMARY', 'en', 'You do not have permission to perform this operation.'),
(163, 'PERMISSION_VIEW_DESC', 'en', 'You do not have permission to view the requested resource. If you think this is incorrect, please <a href="https://support.cs.manchester.ac.uk/otrs/customer.pl">create a ticket</a> in the Newsagent queue, including your central username.'),
(164, 'PERMISSION_COMPOSE_DESC', 'en', 'You do not have permission to compose articles. If you think this is incorrect, please <a href="https://support.cs.manchester.ac.uk/otrs/customer.pl">create a ticket</a> in the Newsagent queue, including your central username.'),
(165, 'PERMISSION_LISTARTICLE_DESC', 'en', 'You do not have permission to view the list of articles. If you think this is incorrect, please <a href="https://support.cs.manchester.ac.uk/otrs/customer.pl">create a ticket</a> in the Newsagent queue, including your central username.'),
(166, 'PERMISSION_EDIT_DESC', 'en', 'You do not have permission to edit this article. If you think this is incorrect, please <a href="https://support.cs.manchester.ac.uk/otrs/customer.pl">create a ticket</a> in the Newsagent queue, including your central username.'),
(167, 'PERMISSION_TELLUS_DESC', 'en', 'You do not have permission to use the ''Tell Us'' service. If you think this is incorrect, please <a href="https://support.cs.manchester.ac.uk/otrs/customer.pl">create a ticket</a> in the Newsagent queue, including your central username.'),
(168, 'PERMISSION_LISTNEWSLETTER_DESC', 'en', 'You do not have permission to use the Newsletter service. If you think this is incorrect, please <a href="https://support.cs.manchester.ac.uk/otrs/customer.pl">create a ticket</a> in the Newsagent queue, including your central username.'),
(169, 'FOOTER_TIMENOTE', 'en', 'Note: all dates and times shown in server local time'),
(170, 'FOOTER_TIMEDST', 'en', '(DST in effect)'),
(171, 'FOOTER_NODST', 'en', ''),
(172, 'NAVBOX_PAGEOF', 'en', 'Page ***pagenum*** of ***maxpage***'),
(173, 'NAVBOX_FIRST', 'en', 'First'),
(174, 'NAVBOX_PREV', 'en', 'Newer'),
(175, 'NAVBOX_NEXT', 'en', 'Older'),
(176, 'NAVBOX_LAST', 'en', 'Last'),
(177, 'NAVBOX_SPACER', 'en', ''),
(178, 'EMAIL_SOCSTITLE', 'en', 'School of Computer Science'),
(179, 'EMAIL_SENTBY', 'en', 'Sent by Newsagent to:'),
(180, 'FLIST_LEVSEL', 'en', 'Select levels...'),
(181, 'FLIST_TITLE', 'en', 'Available Newsagent Feeds'),
(182, 'FLIST_PTITLE', 'en', 'Feeds'),
(183, 'FLIST_EMPTY', 'en', 'No Newsagent feeds are currently available.'),
(184, 'FLIST_INTRO', 'en', 'The following feeds are published by Newsagent. Click the RSS icon to get the feed URL, or select checkboxes to construct a compound feed in the Create Feed URL box to the right.'),
(185, 'FLIST_MAKEBOX', 'en', 'Create Feed URL'),
(186, 'FLIST_LEVELS', 'en', 'Only include articles marked as:'),
(187, 'FLIST_FTEXT', 'en', 'Include full article text:'),
(188, 'FLIST_FTEXT_NONE', 'en', 'Do not include'),
(189, 'FLIST_FTEXT_HTML', 'en', 'As HTML'),
(190, 'FLIST_FTEXT_MD', 'en', 'As Markdown'),
(191, 'FLIST_FTEXT_TEXT', 'en', 'As plain text'),
(192, 'FLIST_FTEXT_ALL', 'en', 'As HTML, with article image.'),
(193, 'FLIST_FULLDESC', 'en', 'Use full text in RSS &lt;description&gt;'),
(194, 'FLIST_COUNT', 'en', 'Number of articles to include:'),
(195, 'FLIST_RSSURL', 'en', 'Feed URL:'),
(196, 'FLIST_VIEWER', 'en', 'Full article viewer:'),
(197, 'FLIST_VIEW_DEF', 'en', 'Choose viewer automatically'),
(198, 'FLIST_VIEW_INT', 'en', 'Use Newsagent article viewer'),
(199, 'RSS_DESCRIPTION', 'en', 'Latest ***feedname*** news'),
(200, 'RSS_TITLE', 'en', '***feedname*** Feed'),
(201, 'FEED_PUBLISHED', 'en', 'Published'),
(202, 'TELLUS_FORM_TITLE', 'en', 'Tell Us'),
(203, 'TELLUS_FORM_INTRO', 'en', '<p>This form allows anyone with a University of Manchester login to tell us about an event, a piece of news, a seminar, or any other piece of information you think may be of interest. Your message will go into a queue, and staff in the school will contact you if more information is needed. Once your message has been reviewed and approved it will be published through Newsagent in the appropriate feeds.</p>'),
(204, 'TELLUS_ADDED_TITLE', 'en', 'Submission successful'),
(205, 'TELLUS_ADDED_SUMMARY', 'en', 'Message created and added to the system successfully.'),
(206, 'TELLUS_ADDED_DESC', 'en', 'Thank you for submission! Your message has been added to a queue, and the members of staff responsible for the queue have been notified. If additional information is required you may be contacted directly.'),
(207, 'TELLUS_NEW', 'en', 'Unread'),
(208, 'TELLUS_VIEWED', 'en', 'Read'),
(209, 'TELLUS_REJECTED', 'en', 'Rejected'),
(210, 'TELLUS_MESSAGE', 'en', 'Tell Us!'),
(211, 'TELLUS_TYPE', 'en', 'Message type:'),
(212, 'TELLUS_QUEUE', 'en', 'Initial queue:'),
(213, 'TELLUS_DESC', 'en', 'Message:'),
(214, 'TELLUS_SUBMIT', 'en', 'Tell Us'),
(215, 'TELLUS_FAILED', 'en', 'An error occurred when adding your message to the system:'),
(216, 'TELLUS_EMAIL_MSGSUB', 'en', '[Newsagent] A message in ''Tell Us'' queue ''***queue***'''),
(217, 'TELLUS_EMAIL_GREETING', 'en', 'Hi'),
(218, 'TELLUS_EMAIL_NEWMSG', 'en', 'A message has been added to a Newsagent ''Tell Us'' queue you have access to manage. The message was added to the queue by ***movename*** <***movemail***>.'),
(219, 'TELLUS_EMAIL_MSGINFO', 'en', 'The details of the message are:'),
(220, 'TELLUS_EMAIL_AUTHOR', 'en', 'Original author'),
(221, 'TELLUS_EMAIL_QUEUE', 'en', 'Queue'),
(222, 'TELLUS_EMAIL_TYPE', 'en', 'Type'),
(223, 'TELLUS_EMAIL_SUMMARY', 'en', 'Message extract'),
(224, 'TELLUS_EMAIL_MANAGE', 'en', 'To create a Newsagent article from this message, move it to another queue, or reject the message you should log into the queue management interface here'),
(225, 'TELLUS_EMAIL_CREATESUB', 'en', '[Newsagent] Your message has been added'),
(226, 'TELLUS_EMAIL_CREATEMSG', 'en', 'Your message has been added to the Newsagent ''Tell Us'' queue ***queuename***. The members of staff responsible for this queue have been notified, and they will process your message soon. If additional information is required, they may contact you directly. Please note that there is no guarantee that submitted messages will be accepted and published as Newsagent articles.'),
(227, 'TELLUS_EMAIL_MOVESUB', 'en', '[Newsagent] Your message has been moved'),
(228, 'TELLUS_EMAIL_MOVEMSG', 'en', 'A Tell Us message you added to Newsagent has been moved to a new queue by ***movename*** <***movemail***>.'),
(229, 'TELLUS_EMAIL_MOVEQUEUE', 'en', 'The message has been placed in the queue'),
(230, 'TELLUS_EMAIL_REJSUB', 'en', '[Newsagent] Your message has not been accepted'),
(231, 'TELLUS_EMAIL_REJECTED', 'en', 'A queue manager has decided not to use a Tell Us message you added to Newsagent at this time. ***rejname*** <***rejemail***> provided the following information regarding this decision:'),
(232, 'TELLUS_EMAIL_RETRY', 'en', 'If you feel this decision is incorrect, please try adding your message again with any additional information you feel may make it more likely to be used, or contact the queue manager for more information.'),
(233, 'TELLUS_QLIST_TITLE', 'en', 'Tell Us Messages'),
(234, 'TELLUS_QLIST_QLIST', 'en', 'Queues'),
(235, 'TELLUS_QLIST_NOQUEUES', 'en', 'No queues available'),
(236, 'TELLUS_QLIST_NOMSG', 'en', 'No messages are available in this queue.'),
(237, 'TELLUS_QLIST_NAME', 'en', 'Name'),
(238, 'TELLUS_QLIST_NEW', 'en', 'Unread messages'),
(239, 'TELLUS_QLIST_READ', 'en', 'Read messages'),
(240, 'TELLUS_QLIST_ALL', 'en', 'Total'),
(241, 'TELLUS_QLIST_MESSAGES', 'en', 'Messages'),
(242, 'TELLUS_QLIST_SELALL', 'en', 'All'),
(243, 'TELLUS_QLIST_SELNONE', 'en', 'None'),
(244, 'TELLUS_QLIST_SELNEW', 'en', 'Unread'),
(245, 'TELLUS_QLIST_SELREAD', 'en', 'Read'),
(246, 'TELLUS_QLIST_ADDED', 'en', 'Added'),
(247, 'TELLUS_QLIST_BY', 'en', 'by'),
(248, 'TELLUS_QLIST_SETQUEUE', 'en', 'Change queue'),
(249, 'TELLUS_QLIST_MAKEARTICLE', 'en', 'Create article'),
(250, 'TELLUS_QLIST_MARKREAD', 'en', 'Mark as read'),
(251, 'TELLUS_QLIST_REJECT', 'en', 'Reject'),
(252, 'TELLUS_QLIST_DELETE', 'en', 'Delete'),
(253, 'TELLUS_QLIST_EMAIL', 'en', 'Email author'),
(254, 'TELLUS_QLIST_MSGVIEW', 'en', 'View message'),
(255, 'TELLUS_QLIST_REJTITLE', 'en', 'Reject messages'),
(256, 'TELLUS_QLIST_REJFORM', 'en', 'You are about to reject one or more Tell Us messages. If you want to send a rejection notification to the message author, you can enter some appropriate text in the box below. The same notification will be sent to the author of each rejected message. If you do not want to send a rejection notification, leave the text box empty.'),
(257, 'TELLUS_QLIST_ERR_NOMOVETOPERM', 'en', 'You do not have permission to move messages to the selected queue.'),
(258, 'TELLUS_QLIST_ERR_NOMOVEPERM', 'en', 'You do not have permission to move one or more selected messages.'),
(259, 'TELLUS_QLIST_ERR_NOMSGID', 'en', 'No message ID specified.'),
(260, 'TELLUS_QLIST_ERR_NOVIEWPERM', 'en', 'You do not have permission to view this message.'),
(261, 'TELLUS_QLIST_ERR_NODELPERM', 'en', 'You do not have permission to delete one or more selected messages.'),
(262, 'TELLUS_QLIST_ERR_NOREJPERM', 'en', 'You do not have permission to reject one or more selected messages.'),
(263, 'TELLUS_QLIST_ERR_NOPROMPERM', 'en', 'You do not have permission to promote messages in the selected queue.'),
(264, 'TELLUS_QLIST_ERR_BADREASON', 'en', 'Rejection reason'),
(265, 'TELLUS_QLIST_POP_CANCEL', 'en', 'Close'),
(266, 'EMAIL_SIG', 'en', 'The {V_[sitename]} Team'),
(267, 'SITE_CONTINUE', 'en', 'Continue'),
(268, 'TIMES_JUSTNOW', 'en', 'just now'),
(269, 'TIMES_SECONDS', 'en', '%t seconds ago'),
(270, 'TIMES_MINUTE', 'en', 'a minute ago'),
(271, 'TIMES_MINUTES', 'en', '%t minutes ago'),
(272, 'TIMES_HOUR', 'en', 'an hour ago'),
(273, 'TIMES_HOURS', 'en', '%t hours ago'),
(274, 'TIMES_DAY', 'en', 'a day ago'),
(275, 'TIMES_DAYS', 'en', '%t days ago'),
(276, 'TIMES_WEEK', 'en', 'a week ago'),
(277, 'TIMES_WEEKS', 'en', '%t weeks ago'),
(278, 'TIMES_MONTH', 'en', 'a month ago'),
(279, 'TIMES_MONTHS', 'en', '%t months ago'),
(280, 'TIMES_YEAR', 'en', 'a year ago'),
(281, 'TIMES_YEARS', 'en', '%t years ago'),
(282, 'FUTURE_JUSTNOW', 'en', 'shortly'),
(283, 'FUTURE_SECONDS', 'en', 'in %t seconds'),
(284, 'FUTURE_MINUTE', 'en', 'in a minute'),
(285, 'FUTURE_MINUTES', 'en', 'in %t minutes'),
(286, 'FUTURE_HOUR', 'en', 'in an hour'),
(287, 'FUTURE_HOURS', 'en', 'in %t hours'),
(288, 'FUTURE_DAY', 'en', 'in a day'),
(289, 'FUTURE_DAYS', 'en', 'in %t days'),
(290, 'FUTURE_WEEK', 'en', 'in a week'),
(291, 'FUTURE_WEEKS', 'en', 'in %t weeks'),
(292, 'FUTURE_MONTH', 'en', 'in a month'),
(293, 'FUTURE_MONTHS', 'en', 'in %t months'),
(294, 'FUTURE_YEAR', 'en', 'in a year'),
(295, 'FUTURE_YEARS', 'en', 'in %t years'),
(296, 'BLOCK_BLOCK_DISPLAY', 'en', 'Direct call to unimplemented block_display()'),
(297, 'BLOCK_SECTION_DISPLAY', 'en', 'Direct call to unimplemented section_display()'),
(298, 'PAGE_ERROR', 'en', 'Error'),
(299, 'PAGE_ERROROK', 'en', 'Okay'),
(300, 'PAGE_POPUP', 'en', 'Information'),
(301, 'PAGE_CONTINUE', 'en', 'Continue'),
(302, 'FATAL_ERROR', 'en', 'Fatal Error'),
(303, 'FATAL_ERROR_SUMMARY', 'en', 'The system has encountered a fatal error and can not continue. The error is shown below.'),
(304, 'MONTH_LONG1', 'en', 'January'),
(305, 'MONTH_LONG2', 'en', 'February'),
(306, 'MONTH_LONG3', 'en', 'March'),
(307, 'MONTH_LONG4', 'en', 'April'),
(308, 'MONTH_LONG5', 'en', 'May'),
(309, 'MONTH_LONG6', 'en', 'June'),
(310, 'MONTH_LONG7', 'en', 'July'),
(311, 'MONTH_LONG8', 'en', 'August'),
(312, 'MONTH_LONG9', 'en', 'September'),
(313, 'MONTH_LONG10', 'en', 'October'),
(314, 'MONTH_LONG11', 'en', 'November'),
(315, 'MONTH_LONG12', 'en', 'December'),
(316, 'COMPOSE_FORM_TITLE', 'en', 'Compose article'),
(317, 'FORM_OPTIONAL', 'en', '<span class="helptext">(optional)</span>'),
(318, 'COMPOSE_TITLE', 'en', 'Subject'),
(319, 'COMPOSE_URL', 'en', 'Link to more information'),
(320, 'COMPOSE_SUMMARY', 'en', 'Summary'),
(321, 'COMPOSE_SUMM_INFO', 'en', '<span class="helptext">Enter a short summary of your article here (<span id="sumchars"></span> characters left)</span>'),
(322, 'COMPOSE_DESC', 'en', 'Full text'),
(323, 'COMPOSE_RELMODE', 'en', 'Release mode'),
(324, 'COMPOSE_BATCH', 'en', 'Newsletter'),
(325, 'COMPOSE_NORMAL', 'en', 'Normal Article'),
(326, 'COMPOSE_IMAGEA', 'en', 'Lead Image'),
(327, 'COMPOSE_IMAGEB', 'en', 'Article Image'),
(328, 'COMPOSE_PUBLICATION', 'en', 'Publication options'),
(329, 'COMPOSE_FEED', 'en', 'Show in feed'),
(330, 'COMPOSE_LEVEL', 'en', 'Visibility levels'),
(331, 'COMPOSE_RELEASE', 'en', 'Publish'),
(332, 'COMPOSE_RELNOW', 'en', 'Immediately'),
(333, 'COMPOSE_RELTIME', 'en', 'At the specified time'),
(334, 'COMPOSE_RELNONE', 'en', 'Never (save as draft)'),
(335, 'COMPOSE_RELDATE', 'en', 'Publish time'),
(336, 'COMPOSE_RELPRESET', 'en', 'Template (not published)'),
(337, 'COMPOSE_PRESETNAME', 'en', 'Template name'),
(338, 'COMPOSE_STICKY', 'en', 'Sticky'),
(339, 'COMPOSE_NOTSTICKY', 'en', 'Article is not sticky'),
(340, 'COMPOSE_STICKYDAYS1', 'en', 'Sticky for 1 day'),
(341, 'COMPOSE_STICKYDAYS2', 'en', 'Sticky for 2 days'),
(342, 'COMPOSE_STICKYDAYS3', 'en', 'Sticky for 3 days'),
(343, 'COMPOSE_STICKYDAYS4', 'en', 'Sticky for 4 days'),
(344, 'COMPOSE_STICKYDAYS5', 'en', 'Sticky for 5 days'),
(345, 'COMPOSE_STICKYDAYS6', 'en', 'Sticky for 6 days'),
(346, 'COMPOSE_STICKYDAYS7', 'en', 'Sticky for 7 days'),
(347, 'COMPOSE_FULLSUMMARY', 'en', 'Summary display'),
(348, 'COMPOSE_FULLSUMOPT', 'en', 'Show summary in full article view.'),
(349, 'COMPOSE_NOSCHEDULE', 'en', 'You do not currently have access to any scheduled releases.'),
(350, 'COMPOSE_SCHEDULE', 'en', 'Newsletter'),
(351, 'COMPOSE_NEXTREL', 'en', 'Next release'),
(352, 'COMPOSE_SECTION', 'en', 'Section'),
(353, 'COMPOSE_PRIORITY', 'en', 'Priority'),
(354, 'COMPOSE_PRI_LOWEST', 'en', 'Lowest'),
(355, 'COMPOSE_PRI_LOW', 'en', 'Low'),
(356, 'COMPOSE_PRI_NORM', 'en', 'Normal'),
(357, 'COMPOSE_PRI_HIGH', 'en', 'High'),
(358, 'COMPOSE_PRI_HIGHEST', 'en', 'Highest'),
(359, 'COMPOSE_RELNEXT', 'en', 'In next publication'),
(360, 'COMPOSE_RELLATER', 'en', 'After the specified time'),
(361, 'COMPOSE_RELAFTER', 'en', 'Publish at or after'),
(362, 'COMPOSE_SHED_MANUAL', 'en', 'Manual release'),
(363, 'COMPOSE_SUBMIT', 'en', 'Create article'),
(364, 'COMPOSE_FAILED', 'en', 'Unable to create new article, the following errors were encountered:'),
(365, 'COMPOSE_ARTICLE', 'en', 'Article'),
(366, 'COMPOSE_SETTINGS', 'en', 'Settings'),
(367, 'COMPOSE_IMAGESFILES', 'en', 'Images and files'),
(368, 'COMPOSE_IMAGES', 'en', 'Images'),
(369, 'COMPOSE_FILES', 'en', 'Files'),
(370, 'COMPOSE_IMGNONE', 'en', 'No image'),
(371, 'COMPOSE_IMGURL', 'en', 'Image URL'),
(372, 'COMPOSE_IMG', 'en', 'Use existing or upload new image'),
(373, 'COMPOSE_MEDIALIB', 'en', 'Click to select image'),
(374, 'COMPOSE_IMGURL_DESC', 'en', 'The image URL must be an absolute URL stating http:// or https://'),
(375, 'COMPOSE_IMGFILE_ERRNOFILE', 'en', 'No file has been selected for ***field***'),
(376, 'COMPOSE_IMGFILE_ERRNOTMP', 'en', 'An internal error (no upload temp file) occurred when processing ***field***'),
(377, 'COMPOSE_LEVEL_ERRNONE', 'en', 'No visibility levels have been selected, or all selected visibility levels have been excluded. You must select at least one visibility level.'),
(378, 'COMPOSE_LEVEL_ERRNOCOMMON', 'en', 'After checking the visibility levels you are allowed to post articles at for all the selected feeds, all the visibility levels were excluded. You will not be able to continue unless you request increased permissions, or remove feeds from your selection.'),
(379, 'COMPOSE_FEED_ERRNONE', 'en', 'No feeds have been selected, or all the selected feeds were excluded after checking your posting permissions.'),
(380, 'COMPOSE_ERR_NOSUMMARYARTICLE', 'en', 'No text has been entered for the summary or article.'),
(381, 'COMPOSE_ERR_NORELTIME', 'en', 'Your article has been set to be published at or after a specific time, but no time has been set for the release.'),
(382, 'COMPOSE_ADDED_TITLE', 'en', 'Article Added'),
(383, 'COMPOSE_ADDED_SUMMARY', 'en', 'Article created and added to the system successfully.'),
(384, 'COMPOSE_ADDED_DESC', 'en', 'Your article has been added to the system. If you set it for immediate publication, it should be visible on feeds now; timed articles will be released when the selected time has passed. Click ''Continue'' to go to your message list.'),
(385, 'COMPOSE_NOTIFICATION', 'en', 'Notification options'),
(386, 'COMPOSE_ACYEAR', 'en', 'Academic Year'),
(387, 'COMPOSE_RECIPIENTS', 'en', 'Recipients'),
(388, 'MATRIX_DELAYNOTE', 'en', '<span class="helptext">Note: all notifications are held for at least 5 minutes before being sent in order to allow notifications to be cancelled or edited.</span>'),
(389, 'COMPOSE_CONFIRM', 'en', 'Confirmation requested'),
(390, 'COMPOSE_CONFIRM_INTRO', 'en', 'Before your article is created, please check the information provided here.'),
(391, 'COMPOSE_CONFIRM_STOP', 'en', 'Do not ask me for confirmation again.'),
(392, 'COMPOSE_CANCEL', 'en', 'Cancel'),
(393, 'COMPOSE_ERRORS', 'en', 'Your article can not be added to the system at this time because:'),
(394, 'COMPOSE_CONFIRM_SHOWN', 'en', 'Once published, this article will be syndicated in the following places. Note that this list is not exhaustive, and your article may be syndicated elsewhere if clients request the feed your article is in at the appropriate visibility level.'),
(395, 'COMPOSE_CONFIRM_HOME', 'en', '<b>This article will appear on the School of CS home page!</b>'),
(396, 'COMPOSE_CONFIRM_LEADER', 'en', 'This article <i>may</i> appear on a leader page on the School of CS website. See <a href=''https://wiki.cs.manchester.ac.uk/index.php/Newsagent/Feeds#Current_feeds_and_syndication'' target=''_blank''>this wiki page</a> for more information.'),
(397, 'COMPOSE_CONFIRM_GROUP', 'en', 'This article will be visible on internal pages that request the feed set for the article.'),
(398, 'COMPOSE_CONFIRM_NOTIFY', 'en', 'Copies of the article will be sent to the following recipients via'),
(399, 'COMPOSE_CONFIRM_COUNTING', 'en', 'Fetching recipient counts...'),
(400, 'COMPOSE_CONFIRM_COUNTWARN', 'en', '<b>NOTE:</b> where available, the number of users who will receive notifications are shown in [ ] above. These numbers should be treated as <b>approximations</b>: the real number may be lower or higher, depending on overlap between recipients and whether any of the recipients are mailing lists managed outside Newsagent.'),
(401, 'COMPOSE_ERR_NOPRESET', 'en', 'This article has been set to be published as a template, but no template name has been entered.'),
(402, 'COMPOSE_ISPRESET', 'en', '<b>This article has been set to be published as a template</b>. It will never be published, and is only visible to you (and admins) within the system. The following publication information only applies to articles created from this template.'),
(403, 'COMPOSE_NOTIFY_MODE', 'en', 'Send notifications'),
(404, 'COMPOSE_SMODE_IMMED', 'en', 'Immediately on publication'),
(405, 'COMPOSE_SMODE_DELAY', 'en', 'After 5 min safety delay'),
(406, 'COMPOSE_SMODE_TIMED', 'en', 'At the specified time:'),
(407, 'COMPOSE_SMODE_NOMODES', 'en', 'No notification send time specifications set. This should not happen.'),
(408, 'COMPOSE_EDITWARN', 'en', 'Leaving this page may cause to to lose any changes you have made.'),
(409, 'COMPOSE_AUTOSAVE_SAVED', 'en', 'Autosaved ***time***'),
(410, 'COMPOSE_AUTOSAVE_NONE', 'en', 'No autosave available'),
(411, 'COMPOSE_AUTOSAVE_FAIL', 'en', 'Autosave failed'),
(412, 'COMPOSE_AUTOSAVE_PERM', 'en', 'You do not have permission to autosave'),
(413, 'COMPOSE_AUTOSAVE_SAVE', 'en', 'Save now'),
(414, 'COMPOSE_AUTOSAVE_LOAD', 'en', 'Restore autosave'),
(415, 'COMPOSE_AUTOSAVE_CHECKING', 'en', 'Checking for autosave...'),
(416, 'COMPOSE_AUTOSAVE_LOADING', 'en', 'Restoring autosave...'),
(417, 'COMPOSE_AUTOSAVE_SAVING', 'en', 'Saving autosave...'),
(418, 'COMPOSE_ERR_BADSCHEDULE', 'en', 'Unable to locate an ID for the selected schedule.'),
(419, 'COMPOSE_MODE_NORMAL', 'en', 'Your article will be published as a normal article.'),
(420, 'COMPOSE_MODE_NEWSLETTER', 'en', 'Your article will be included in a newsletter.'),
(421, 'COMPOSE_NEWSLETTER_INTRO', 'en', 'Your article will appear in the following newsletter and section:'),
(422, 'COMPOSE_SAVEDRAFT', 'en', 'Your article will be saved as a draft message and will not be published in its current form. You can edit or clone the article through your article list when you are ready to edit it for release.'),
(423, 'COMPOSE_TIMED_NORMAL', 'en', 'Your article has been set to be released at a specific date and time. If the date has already past, your article will appear in feeds as if it had been published at that time. The release time you have set is:'),
(424, 'COMPOSE_TIMED_NEWSLETTER', 'en', 'Your article has been set to be published in a newsletter at or after a specific time. It will not be published in newsletters before that time, and it will appear in the next newsletter published after that time. The release time you have set is:'),
(425, 'LOGIN_TITLE', 'en', 'Log in'),
(426, 'LOGIN_LOGINFORM', 'en', 'Log in'),
(427, 'LOGIN_INTRO', 'en', 'Enter your username and password to log in.'),
(428, 'LOGIN_USERNAME', 'en', 'Username'),
(429, 'LOGIN_PASSWORD', 'en', 'Password'),
(430, 'LOGIN_EMAIL', 'en', 'Email address'),
(431, 'LOGIN_PERSIST', 'en', 'Remember me'),
(432, 'LOGIN_LOGIN', 'en', 'Log in'),
(433, 'LOGIN_FAILED', 'en', 'Login failed'),
(434, 'LOGIN_RECOVER', 'en', 'Forgotten your username or password?'),
(435, 'LOGIN_SENDACT', 'en', 'Click to resend your activation code'),
(436, 'PERSIST_WARNING', 'en', '<strong>WARNING</strong>: do not enable the "Remember me" option on shared, cluster, or public computers. This option should only be enabled on machines you have exclusive access to.'),
(437, 'LOGIN_DONETITLE', 'en', 'Logged in'),
(438, 'LOGIN_SUMMARY', 'en', 'You have successfully logged into the system.'),
(439, 'LOGIN_LONGDESC', 'en', 'You have successfully logged in, and you will be redirected shortly. If you do not want to wait, click continue. Alternatively, <a href="{V_[scriptpath]}">Click here</a> to return to the front page.'),
(440, 'LOGIN_NOREDIRECT', 'en', 'You have successfully logged in, but warnings were encountered during login. Please check the warning messages, and <a href="mailto:***supportaddr***">contact support</a> if a serious problem has been encountered, otherwise, click continue. Alternatively, <a href="{V_[scriptpath]}">Click here</a> to return to the front page.'),
(441, 'LOGOUT_TITLE', 'en', 'Logged out'),
(442, 'LOGOUT_SUMMARY', 'en', 'You have successfully logged out.'),
(443, 'LOGOUT_LONGDESC', 'en', 'You have successfully logged out, and you will be redirected shortly. If you do not want to wait, click continue. Alternatively, <a href="{V_[scriptpath]}">Click here</a> to return to the front page.'),
(444, 'LOGIN_ERR_BADUSERCHAR', 'en', 'Illegal character in username. Usernames may only contain alphanumeric characters, underscores, or hyphens.'),
(445, 'LOGIN_ERR_INVALID', 'en', 'Login failed: unknown username or password provided.'),
(446, 'LOGIN_REGISTER', 'en', 'Sign up'),
(447, 'LOGIN_REG_INTRO', 'en', 'Create an account by choosing a username and giving a valid email address. A password will be emailed to you.'),
(448, 'LOGIN_SECURITY', 'en', 'Security question'),
(449, 'LOGIN_SEC_INTRO', 'en', 'In order to prevent abuse by automated spamming systems, please answer the following question to prove that you are a human.<br/>Note: the answer is not case sensitive.'),
(450, 'LOGIN_SEC_SUBMIT', 'en', 'Sign up'),
(451, 'LOGIN_ERR_NOSELFREG', 'en', 'Self-registration is not currently permitted.'),
(452, 'LOGIN_ERR_REGFAILED', 'en', 'Registration failed'),
(453, 'LOGIN_ERR_BADSECURE', 'en', 'You did not answer the security question correctly, please check your answer and try again.'),
(454, 'LOGIN_ERR_BADEMAIL', 'en', 'The specified email address does not appear to be valid.'),
(455, 'LOGIN_ERR_USERINUSE', 'en', 'The specified username is already in use. If you can''t remember your password, <strong>please use the <a href="***url-recover***">account recovery</a> facility</strong> rather than attempt to make a new account.'),
(456, 'LOGIN_ERR_EMAILINUSE', 'en', 'The specified email address is already in use. If you can''t remember your username or password, <strong>please use the <a href="***url-recover***">account recovery</a> facility</strong> rather than attempt to make a new account.'),
(457, 'LOGIN_ERR_INACTIVE', 'en', 'Your account is currently inactive. Please check your email for an ''Activation Required'' email and follow the link it contains to activate your account. If you have not received an actication email, or need a new one, <a href="***url-resend***">request a new activation email</a>.'),
(458, 'LOGIN_REG_DONETITLE', 'en', 'Registration successful'),
(459, 'LOGIN_REG_SUMMARY', 'en', 'Activation required!'),
(460, 'LOGIN_REG_LONGDESC', 'en', 'A new user account has been created for you, and an email has been sent to you with your new account password and an activation link.<br /><br />Please check your email for a message with the subject ''{V_[sitename]} account created - Activation required!'' and follow the instructions it contains to activate your account.'),
(461, 'LOGIN_REG_SUBJECT', 'en', '{V_[sitename]} account created - Activation required!'),
(462, 'LOGIN_REG_GREETING', 'en', 'Hi ***username***'),
(463, 'LOGIN_REG_CREATED', 'en', 'A new account in the {V_[sitename]} system has just been created for you. Your username and password for the system are given below.'),
(464, 'LOGIN_REG_ACTNEEDED', 'en', 'Before you can log in, you must activate your account. To activate your account, please click on the following link, or copy and paste it into your web browser:'),
(465, 'LOGIN_REG_ALTACT', 'en', 'Alternatively, enter the following code in the account activation form:'),
(466, 'LOGIN_REG_ENJOY', 'en', 'Thank you for registering!'),
(467, 'LOGIN_ACTCODE', 'en', 'Activation code'),
(468, 'LOGIN_ACTFAILED', 'en', 'User account activation failed'),
(469, 'LOGIN_ACTFORM', 'en', 'Activate account'),
(470, 'LOGIN_ACTINTRO', 'en', 'Please enter your 64 character activation code here.'),
(471, 'LOGIN_ACTIVATE', 'en', 'Activate account'),
(472, 'LOGIN_ERR_BADACTCHAR', 'en', 'Activation codes may only contain alphanumeric characters.'),
(473, 'LOGIN_ERR_BADCODE', 'en', 'The provided activation code is invalid: either your account is already active, or you entered the code incorrectly. Note that the code is case sensitive - upper and lower case characters are treated differently. Please check you entered the code correctly.'),
(474, 'LOGIN_ACT_DONETITLE', 'en', 'Account activated'),
(475, 'LOGIN_ACT_SUMMARY', 'en', 'Activation successful!'),
(476, 'LOGIN_ACT_LONGDESC', 'en', 'Your new account has been acivated, and you can now <a href="***url-login***">log in</a> using your username and the password emailed to you.'),
(477, 'LOGIN_RECFORM', 'en', 'Recover account details'),
(478, 'LOGIN_RECINTRO', 'en', 'If you have forgotten your username or password, enter the email address associated with your account in the field below. An email will be sent to you containing your username, and a link to click on to reset your password. If you do not have access to the email address associated with your account, please contact the site owner.'),
(479, 'LOGIN_RECEMAIL', 'en', 'Email address'),
(480, 'LOGIN_DORECOVER', 'en', 'Recover account'),
(481, 'LOGIN_RECOVER_SUBJECT', 'en', 'Your {V_[sitename]} account'),
(482, 'LOGIN_RECOVER_GREET', 'en', 'Hi ***username***'),
(483, 'LOGIN_RECOVER_INTRO', 'en', 'You, or someone pretending to be you, has requested that your password be reset. In order to reset your account, please click on the following link, or copy and paste it into your web browser.'),
(484, 'LOGIN_RECOVER_IGNORE', 'en', 'If you did not request this reset, please either ignore this email or report it to the {V_[sitename]} administrator.'),
(485, 'LOGIN_RECOVER_FAILED', 'en', 'Account recovery failed'),
(486, 'LOGIN_RECOVER_DONETITLE', 'en', 'Account recovery code sent'),
(487, 'LOGIN_RECOVER_SUMMARY', 'en', 'Recovery code sent!'),
(488, 'LOGIN_RECOVER_LONGDESC', 'en', 'An account recovery code has been send to your email address.<br /><br />Please check your email for a message with the subject ''Your {V_[sitename]} account'' and follow the instructions it contains.'),
(489, 'LOGIN_ERR_NOUID', 'en', 'No user id specified.'),
(490, 'LOGIN_ERR_BADUID', 'en', 'The specfied user id is not valid.'),
(491, 'LOGIN_ERR_BADRECCHAR', 'en', 'Account reset codes may only contain alphanumeric characters.'),
(492, 'LOGIN_ERR_BADRECCODE', 'en', 'The provided account reset code is invalid. Note that the code is case sensitive - upper and lower case characters are treated differently. Please check you entered the code correctly.'),
(493, 'LOGIN_ERR_NORECINACT', 'en', 'Your account is inactive, and therefore can not be recovered. In order to access your account, please request a new activation code and password.'),
(494, 'LOGIN_RESET_SUBJECT', 'en', 'Your {V_[sitename]} account'),
(495, 'LOGIN_RESET_GREET', 'en', 'Hi ***username***'),
(496, 'LOGIN_RESET_INTRO', 'en', 'Your password has been reset, and your username and new password are given below:'),
(497, 'LOGIN_RESET_LOGIN', 'en', 'To log into the {V_[sitename]}, please go to the following form and enter the username and password above. Once you have logged in, please change your password.'),
(498, 'LOGIN_RESET_DONETITLE', 'en', 'Account reset complete'),
(499, 'LOGIN_RESET_SUMMARY', 'en', 'Password reset successfully'),
(500, 'LOGIN_RESET_LONGDESC', 'en', 'Your username and a new password have been sent to your email address. Please look for an email with the subject ''Your {V_[sitename]} account'', you can use the account information it contains to log into the system by clicking the ''Log in'' button below.'),
(501, 'LOGIN_RESET_ERRTITLE', 'en', 'Account reset failed'),
(502, 'LOGIN_RESET_ERRSUMMARY', 'en', 'Password reset failed'),
(503, 'LOGIN_RESET_ERRDESC', 'en', 'The system has been unable to reset your account. The error encountered was:<br /><br/>***reason***'),
(504, 'LOGIN_RESENDFORM', 'en', 'Resend activation code'),
(505, 'LOGIN_RESENDINTRO', 'en', 'If you have accidentally deleted your activation email, or you have not received an an activation email more than 30 minutes after creating an account, enter your account email address below to be sent your activation code again.<br /><br/><strong>IMPORTANT</strong>: requesting a new copy of your activation code will also reset your password. If you later receive the original registration email, the code and password it contains will not work and should be ignored.'),
(506, 'LOGIN_RESENDEMAIL', 'en', 'Email address'),
(507, 'LOGIN_DORESEND', 'en', 'Resend code'),
(508, 'LOGIN_ERR_BADUSER', 'en', 'The email address provided does not appear to belong to any account in the system.'),
(509, 'LOGIN_ERR_BADAUTH', 'en', 'The user account with the provided email address does not have a valid authentication method associated with it. This should not happen!'),
(510, 'LOGIN_ERR_ALREADYACT', 'en', 'The user account with the provided email address is already active, and does not need a code to be activated.'),
(511, 'LOGIN_RESEND_SUBJECT', 'en', 'Your {V_[sitename]} activation code'),
(512, 'LOGIN_RESEND_GREET', 'en', 'Hi ***username***'),
(513, 'LOGIN_RESEND_INTRO', 'en', 'You, or someone pretending to be you, has requested that another copy of your activation code be sent to your email address.'),
(514, 'LOGIN_RESEND_ALTACT', 'en', 'Alternatively, enter the following code in the account activation form:'),
(515, 'LOGIN_RESEND_ENJOY', 'en', 'Thank you for registering!'),
(516, 'LOGIN_RESEND_FAILED', 'en', 'Activation code resend failed'),
(517, 'LOGIN_RESEND_DONETITLE', 'en', 'Activation code resent'),
(518, 'LOGIN_RESEND_SUMMARY', 'en', 'Resend successful!'),
(519, 'LOGIN_RESEND_LONGDESC', 'en', 'A new password and an activation link have been send to your email address.<br /><br />Please check your email for a message with the subject ''Your {V_[sitename]} activation code'' and follow the instructions it contains to activate your account.'),
(520, 'LOGIN_PASSCHANGE', 'en', 'Change password'),
(521, 'LOGIN_FORCECHANGE_INTRO', 'en', 'Before you continue, please choose a new password to set for your account.'),
(522, 'LOGIN_FORCECHANGE_TEMP', 'en', 'Your account is currently set up with a temporary password.'),
(523, 'LOGIN_FORCECHANGE_OLD', 'en', 'The password on your account has expired as a result of age limits enforced by the site''s password policy.'),
(524, 'LOGIN_NEWPASSWORD', 'en', 'New password'),
(525, 'LOGIN_CONFPASS', 'en', 'Confirm password'),
(526, 'LOGIN_OLDPASS', 'en', 'Your current password'),
(527, 'LOGIN_SETPASS', 'en', 'Change password'),
(528, 'LOGIN_PASSCHANGE_FAILED', 'en', 'Password change failed'),
(529, 'LOGIN_PASSCHANGE_ERRNOUSER', 'en', 'No logged in user detected, password change unsupported.'),
(530, 'LOGIN_PASSCHANGE_ERRMATCH', 'en', 'The new password specified does not match the confirm password.'),
(531, 'LOGIN_PASSCHANGE_ERRSAME', 'en', 'The new password can not be the same as the old password.'),
(532, 'LOGIN_PASSCHANGE_ERRVALID', 'en', 'The specified old password is not correct. You must enter the password you used to log in.'),
(533, 'LOGIN_POLICY', 'en', 'Password policy'),
(534, 'LOGIN_POLICY_INTRO', 'en', 'When choosing a new password, keep in mind that:'),
(535, 'LOGIN_POLICY_NONE', 'en', 'No password policy is currently in place, you may use any password you want.'),
(536, 'LOGIN_POLICY_MIN_LENGTH', 'en', 'Minimum length is ***value*** characters.'),
(537, 'LOGIN_POLICY_MIN_LOWERCASE', 'en', 'At least ***value*** lowercase letters are needed.'),
(538, 'LOGIN_POLICY_MIN_UPPERCASE', 'en', 'At least ***value*** uppercase letters are needed.'),
(539, 'LOGIN_POLICY_MIN_DIGITS', 'en', 'At least ***value*** numbers must be included.'),
(540, 'LOGIN_POLICY_MIN_OTHER', 'en', '***value*** non-alphanumeric chars are needed.'),
(541, 'LOGIN_POLICY_MIN_ENTROPY', 'en', 'Passwords must pass a strength check.'),
(542, 'LOGIN_POLICY_USE_CRACKLIB', 'en', 'Cracklib is used to test passwords.'),
(543, 'LOGIN_POLICY_MIN_LENGTHERR', 'en', 'Password is only ***set*** characters, minimum is ***require***.'),
(544, 'LOGIN_POLICY_MIN_LOWERCASEERR', 'en', 'Only ***set*** of ***require*** lowercase letters provided.'),
(545, 'LOGIN_POLICY_MIN_UPPERCASEERR', 'en', 'Only ***set*** of ***require*** uppercase letters provided.'),
(546, 'LOGIN_POLICY_MIN_DIGITSERRR', 'en', 'Only ***set*** of ***require*** digits included.'),
(547, 'LOGIN_POLICY_MIN_OTHERERR', 'en', 'Only ***set*** of ***require*** non-alphanumeric chars included.'),
(548, 'LOGIN_POLICY_MIN_ENTROPYERR', 'en', 'The supplied password is not strong enough.'),
(549, 'LOGIN_POLICY_USE_CRACKLIBERR', 'en', '***set***'),
(550, 'LOGIN_POLICY_MAX_PASSWORDAGE', 'en', 'Passwords must be changed after ***value*** days.'),
(551, 'LOGIN_POLICY_MAX_LOGINFAIL', 'en', 'You can log in incorrectly ***value*** times before your account needs reactivation.'),
(552, 'LOGIN_CRACKLIB_WAYSHORT', 'en', 'The password is far too short.'),
(553, 'LOGIN_CRACKLIB_TOOSHORT', 'en', 'The password is too short.'),
(554, 'LOGIN_CRACKLIB_MORECHARS', 'en', 'A greater range of characters are needed in the password.'),
(555, 'LOGIN_CRACKLIB_WHITESPACE', 'en', 'Passwords can not be entirely whitespace!'),
(556, 'LOGIN_CRACKLIB_SIMPLISTIC', 'en', 'The password is too simplistic or systematic.'),
(557, 'LOGIN_CRACKLIB_NINUMBER', 'en', 'You can not use a NI number as a password.'),
(558, 'LOGIN_CRACKLIB_DICTWORD', 'en', 'The password is based on a dictionary word.'),
(559, 'LOGIN_CRACKLIB_DICTBACK', 'en', 'The password is based on a reversed dictionary word.'),
(560, 'LOGIN_FAILLIMIT', 'en', 'You have used ***failcount*** of ***faillimit*** login attempts. If you exceed the limit, your account will be deactivated. If you can not remember your account details, please use the <a href="***url-recover***">account recovery form</a>'),
(561, 'LOGIN_LOCKEDOUT', 'en', 'You have exceeded the number of login failures permitted by the system, and your account has been deactivated. An email has been sent to the address associated with your account explaining how to reactivate your account.'),
(562, 'LOGIN_LOCKOUT_SUBJECT', 'en', '{V_[sitename]} account locked'),
(563, 'LOGIN_LOCKOUT_GREETING', 'en', 'Hi'),
(564, 'LOGIN_LOCKOUT_MESSAGE', 'en', 'Your ''{V_[sitename]}'' account has deactivated and your password has been changed because more than ***faillimit*** login failures have been recorded for your account. This may be the result of attempted unauthorised access to your account - if you are not responsible for these login attempts you should probably contact the site administator to report that your account may be under attack. Your username and new password for the site are:'),
(565, 'LOGIN_LOCKOUT_ACTNEEDED', 'en', 'As your account has been deactivated, before you can successfully log in you will need to reactivate your account. To do this, please click on the following link, or copy and paste it into your web browser:'),
(566, 'LOGIN_LOCKOUT_ALTACT', 'en', 'Alternatively, enter the following code in the account activation form:'),
(567, 'LOGIN_EXPIRED', 'en', 'Your login session has expired, please log in again using the form below to continue.'),
(568, 'DEBUG_TIMEUSED', 'en', 'Execution time'),
(569, 'DEBUG_SECONDS', 'en', 'seconds'),
(570, 'DEBUG_USER', 'en', 'User time'),
(571, 'DEBUG_SYSTEM', 'en', 'System time'),
(572, 'DEBUG_MEMORY', 'en', 'Memory used'),
(573, 'BLOCK_VALIDATE_NOTSET', 'en', 'No value provided for ''***field***'', this field is required.'),
(574, 'BLOCK_VALIDATE_TOOLONG', 'en', 'The value provided for ''***field***'' is too long. No more than ***maxlen*** characters can be provided for this field.'),
(575, 'BLOCK_VALIDATE_BADCHARS', 'en', 'The value provided for ''***field***'' contains illegal characters. ***desc***'),
(576, 'BLOCK_VALIDATE_BADFORMAT', 'en', 'The value provided for ''***field***'' is not valid. ***desc***'),
(577, 'BLOCK_VALIDATE_DBERR', 'en', 'Unable to look up the value for ''***field***'' in the database. Error was: ***dberr***.'),
(578, 'BLOCK_VALIDATE_BADOPT', 'en', 'The value selected for ''***field***'' is not a valid option.'),
(579, 'BLOCK_VALIDATE_SCRUBFAIL', 'en', 'No content was left after cleaning the contents of html field ''***field***''.'),
(580, 'BLOCK_VALIDATE_TIDYFAIL', 'en', 'htmltidy failed for field ''***field***''.'),
(581, 'BLOCK_VALIDATE_CHKERRS', 'en', '***error*** html errors where encountered while validating ''***field***''. Clean up the html and try again.'),
(582, 'BLOCK_VALIDATE_CHKFAIL', 'en', 'Validation of ''***field***'' failed. Error from the W3C validator was: ***error***.'),
(583, 'BLOCK_VALIDATE_NOTNUMBER', 'en', 'The value provided for ''***field***'' is not a valid number.'),
(584, 'BLOCK_VALIDATE_RANGEMIN', 'en', 'The value provided for ''***field***'' is out of range (minimum is ***min***)'),
(585, 'BLOCK_VALIDATE_RANGEMAX', 'en', 'The value provided for ''***field***'' is out of range (maximum is ***max***)'),
(586, 'BLOCK_ERROR_TITLE', 'en', 'Fatal System Error'),
(587, 'BLOCK_ERROR_SUMMARY', 'en', 'The system has encountered an unrecoverable error.'),
(588, 'BLOCK_ERROR_TEXT', 'en', 'A serious error has been encountered while processing your request. The following information was generated by the system, please contact moodlesupport@cs.man.ac.uk about this, including this error and a description of what you were doing when it happened!<br /><br /><span class="error">***error***</span>'),
(589, 'METHOD_EMAIL_SETTINGS', 'en', 'Email settings'),
(590, 'METHOD_EMAIL_CC', 'en', 'CC recipients'),
(591, 'METHOD_EMAIL_MULTIPLE', 'en', '<span class="helptext">(optional, separate multiple recipients with commas)</span>'),
(592, 'METHOD_EMAIL_BCC', 'en', 'BCC recipients'),
(593, 'METHOD_EMAIL_REPLYTO', 'en', 'Reply To'),
(594, 'METHOD_EMAIL_PREFIX', 'en', 'Subject prefix'),
(595, 'METHOD_EMAIL_BCCME', 'en', 'Send me a copy of this article'),
(596, 'METHOD_EMAIL_ERR_SINGLEADDR', 'en', '***field*** contains more than one email address; it should contain a single address.'),
(597, 'METHOD_EMAIL_ERR_BADADDR', 'en', 'One or more email addresses specified in ***field*** are invalid.'),
(598, 'METHOD_TWITTER_SETTINGS', 'en', 'Twitter settings'),
(599, 'METHOD_TWITTER_MODE', 'en', 'Tweet text'),
(600, 'METHOD_TWEET_MODE_SUMM', 'en', 'Use article summary'),
(601, 'METHOD_TWEET_MODE_OWN', 'en', 'Use custom tweet text:');
INSERT INTO `language` (`id`, `name`, `lang`, `message`) VALUES
(602, 'METHOD_TWITTER_AUTO', 'en', 'Include link to full article viewer'),
(603, 'METHOD_TWEET_AUTO_LINK', 'en', 'Use default feed viewer URL'),
(604, 'METHOD_TWEET_AUTO_NEWS', 'en', 'Use internal Newsagent viewer URL'),
(605, 'METHOD_TWEET_AUTO_NONE', 'en', 'Do not include full article viewer link'),
(606, 'METHOD_STATE_INVALID', 'en', 'Invalid'),
(607, 'METHOD_STATE_DRAFT', 'en', 'Draft'),
(608, 'METHOD_STATE_PENDING', 'en', 'Pending'),
(609, 'METHOD_STATE_SENDING', 'en', 'Sending'),
(610, 'METHOD_STATE_SENT', 'en', 'Sent'),
(611, 'METHOD_STATE_CANCELLED', 'en', 'Aborted'),
(612, 'METHOD_STATE_FAILED', 'en', 'Failed'),
(613, 'METHOD_RECIP_COUNT', 'en', '***count*** recipients');

-- --------------------------------------------------------

--
-- Table structure for table `log`
--

CREATE TABLE IF NOT EXISTS `log` (
  `id` int(10) unsigned NOT NULL,
  `logtime` int(10) unsigned NOT NULL COMMENT 'The time the logged event happened at',
  `user_id` int(10) unsigned DEFAULT NULL COMMENT 'The id of the user who triggered the event, if any',
  `ipaddr` varchar(16) DEFAULT NULL COMMENT 'The IP address the event was triggered from',
  `logtype` varchar(64) NOT NULL COMMENT 'The event type',
  `logdata` text COMMENT 'Any data that might be appropriate to log for this event'
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Stores a log of events in the system.';

-- --------------------------------------------------------

--
-- Table structure for table `messages_queue`
--

CREATE TABLE IF NOT EXISTS `messages_queue` (
  `id` int(10) unsigned NOT NULL,
  `previous_id` int(10) unsigned DEFAULT NULL COMMENT 'Link to a previous message (for replies/followups/etc)',
  `created` int(10) unsigned NOT NULL COMMENT 'The unix timestamp of when this message was created',
  `creator_id` int(10) unsigned DEFAULT NULL COMMENT 'Who created this message (NULL = system)',
  `deleted` int(10) unsigned DEFAULT NULL COMMENT 'Timestamp of message deletion, marks deletion of /sending/ message.',
  `deleted_id` int(10) unsigned DEFAULT NULL COMMENT 'Who deleted the message?',
  `message_ident` varchar(128) COLLATE utf8_unicode_ci DEFAULT NULL COMMENT 'Generic identifier, may be used for message lookup after addition',
  `subject` varchar(255) COLLATE utf8_unicode_ci NOT NULL COMMENT 'The message subject',
  `body` text COLLATE utf8_unicode_ci NOT NULL COMMENT 'The message body',
  `format` enum('text','html') COLLATE utf8_unicode_ci NOT NULL DEFAULT 'text' COMMENT 'Message format, for possible extension',
  `send_after` int(10) unsigned DEFAULT NULL COMMENT 'Send message after this time (NULL = as soon as possible)'
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci COMMENT='Stores messages to be sent through Message:: modules';

-- --------------------------------------------------------

--
-- Table structure for table `messages_recipients`
--

CREATE TABLE IF NOT EXISTS `messages_recipients` (
  `message_id` int(10) unsigned NOT NULL COMMENT 'ID of the message this is a recipient entry for',
  `recipient_id` int(10) unsigned NOT NULL COMMENT 'ID of the user sho should get the email',
  `viewed` int(10) unsigned DEFAULT NULL COMMENT 'When did the recipient view this message (if at all)',
  `deleted` int(10) unsigned DEFAULT NULL COMMENT 'When did the recipient mark their view as deleted (if at all)'
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Stores the recipients of messages';

-- --------------------------------------------------------

--
-- Table structure for table `messages_sender`
--

CREATE TABLE IF NOT EXISTS `messages_sender` (
  `message_id` int(10) unsigned NOT NULL COMMENT 'ID of the message this is a sender record for',
  `sender_id` int(10) unsigned NOT NULL COMMENT 'ID of the user who sent the message',
  `deleted` int(10) unsigned NOT NULL COMMENT 'Has the sender deleted this message from their list (DOES NOT DELETE THE MESSAGE!)'
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Stores the sender of each message, and sender-specific infor';

-- --------------------------------------------------------

--
-- Table structure for table `messages_transports`
--

CREATE TABLE IF NOT EXISTS `messages_transports` (
  `id` int(10) unsigned NOT NULL,
  `name` varchar(24) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL COMMENT 'The transport name',
  `description` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL COMMENT 'Human readable description (or langvar name)',
  `perl_module` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL COMMENT 'The perl module implementing the message transport.',
  `enabled` tinyint(1) NOT NULL COMMENT 'Is the transport enabled?'
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Stores the list of modules that provide message delivery';

--
-- Dumping data for table `messages_transports`
--

INSERT INTO `messages_transports` (`id`, `name`, `description`, `perl_module`, `enabled`) VALUES
(1, 'email', '{L_MESSAGE_TRANSP_EMAIL}', 'Webperl::Message::Transport::Email', 1);

-- --------------------------------------------------------

--
-- Table structure for table `messages_transports_status`
--

CREATE TABLE IF NOT EXISTS `messages_transports_status` (
  `id` int(10) unsigned NOT NULL,
  `message_id` int(10) unsigned NOT NULL COMMENT 'The ID of the message this is a transport entry for',
  `transport_id` int(10) unsigned NOT NULL COMMENT 'The ID of the transport',
  `status_time` int(10) unsigned NOT NULL COMMENT 'The time the status was changed',
  `status` enum('pending','sent','failed') CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL DEFAULT 'pending' COMMENT 'The transport status',
  `status_message` text COMMENT 'human-readable status message (usually error messages)'
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Stores transport status information for messages';

-- --------------------------------------------------------

--
-- Table structure for table `messages_transports_userctrl`
--

CREATE TABLE IF NOT EXISTS `messages_transports_userctrl` (
  `transport_id` int(10) unsigned NOT NULL COMMENT 'ID of the transport the user has set a control on',
  `user_id` int(10) unsigned NOT NULL COMMENT 'User setting the control',
  `enabled` tinyint(1) unsigned NOT NULL DEFAULT '1' COMMENT 'contact the user through this transport?'
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Allows users to explicitly enable, or disable, specific mess';

-- --------------------------------------------------------

--
-- Table structure for table `modules`
--

CREATE TABLE IF NOT EXISTS `modules` (
  `module_id` smallint(5) unsigned NOT NULL COMMENT 'Unique module id',
  `name` varchar(80) NOT NULL COMMENT 'Short name for the module',
  `perl_module` varchar(128) NOT NULL COMMENT 'Name of the perl module in blocks/ (no .pm extension!)',
  `active` tinyint(1) unsigned NOT NULL COMMENT 'Is this module enabled?'
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Available site modules, perl module names, and status';

-- --------------------------------------------------------

--
-- Dumping data for table `modules`
--

INSERT INTO `modules` (`module_id`, `name`, `perl_module`, `active`) VALUES
(1, 'compose', 'Newsagent::Article::Compose', 1),
(2, 'login', 'Newsagent::Login', 1),
(3, 'rss', 'Newsagent::Feed::RSS', 1),
(4, 'html', 'Newsagent::Feed::HTML', 1),
(5, 'articles', 'Newsagent::Article::List', 1),
(6, 'edit', 'Newsagent::Article::Edit', 1),
(102, 'notify_moodle', 'Newsagent::Notification::Method::Moodle', 1),
(101, 'notify_email', 'Newsagent::Notification::Method::Email', 1),
(7, 'cron', 'Newsagent::Article::Cron', 1),
(8, 'webapi', 'Newsagent::Article::API', 1),
(9, 'feeds', 'Newsagent::FeedList', 1),
(103, 'notify_twitter', 'Newsagent::Notification::Method::Twitter', 1),
(10, 'import', 'Newsagent::Import', 1),
(201, 'uommedia', 'Newsagent::Importer::UoMMediaTeam', 1),
(11, 'tellus', 'Newsagent::TellUs::Compose', 1),
(12, 'queues', 'Newsagent::TellUs::List', 1),
(13, 'newsletters', 'Newsagent::Newsletter::List', 1);

-- --------------------------------------------------------

--
-- Table structure for table `news_articles`
--

CREATE TABLE IF NOT EXISTS `news_articles` (
  `id` int(10) unsigned NOT NULL,
  `previous_id` int(10) unsigned DEFAULT NULL COMMENT 'Previous revision of the article',
  `metadata_id` int(10) unsigned NOT NULL COMMENT 'ID of the metadata context associated with this article',
  `creator_id` int(10) unsigned NOT NULL COMMENT 'ID of the user who created the article',
  `created` int(10) unsigned NOT NULL COMMENT 'Unix timestamp of the creation date',
  `title` varchar(100) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `summary` varchar(240) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL,
  `article` text CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL,
  `preset` varchar(80) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL COMMENT 'Optional preset name for drafts',
  `release_mode` enum('hidden','visible','timed','draft','preset','edited','deleted','next','after','nldraft','used') CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL DEFAULT 'visible',
  `release_time` int(10) unsigned DEFAULT NULL COMMENT 'Unix timestamp at which to release this article',
  `updated` int(10) unsigned NOT NULL COMMENT 'When was this article last updated?',
  `updated_id` int(10) unsigned NOT NULL COMMENT 'Who performed the last update?',
  `sticky_until` int(10) unsigned DEFAULT NULL COMMENT 'When is the article sticky until?',
  `is_sticky` tinyint(4) NOT NULL DEFAULT '0' COMMENT 'Is the article currently sticky?',
  `full_summary` tinyint(3) unsigned NOT NULL DEFAULT '1' COMMENT 'Should the summary appear in the full article view?'
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Stores articles';

-- --------------------------------------------------------

--
-- Table structure for table `news_article_digest_section`
--

CREATE TABLE IF NOT EXISTS `news_article_digest_section` (
  `id` int(10) unsigned NOT NULL,
  `article_id` int(10) unsigned NOT NULL,
  `digest_id` int(10) unsigned NOT NULL COMMENT 'ID of the digest this article is attached to',
  `section_id` int(10) unsigned NOT NULL COMMENT 'The ID of the digest section this article is in',
  `sort_order` tinyint(3) unsigned NOT NULL COMMENT 'This article''s position in the section'
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `news_article_feeds`
--

CREATE TABLE IF NOT EXISTS `news_article_feeds` (
  `id` int(10) unsigned NOT NULL,
  `article_id` int(10) unsigned NOT NULL,
  `feed_id` int(10) unsigned NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Records which feeds an article has been posted in';

-- --------------------------------------------------------

--
-- Table structure for table `news_article_images`
--

CREATE TABLE IF NOT EXISTS `news_article_images` (
  `id` int(10) unsigned NOT NULL,
  `article_id` int(10) unsigned NOT NULL COMMENT 'The ID of the article this is a relation for',
  `image_id` int(10) unsigned NOT NULL COMMENT 'The ID of the iamge to associate with the article',
  `order` tinyint(3) unsigned NOT NULL COMMENT 'The position of this image in the article''s list (1=leader, 2=foot, etc)'
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Allows images to be attached to articles';

-- --------------------------------------------------------

--
-- Table structure for table `news_article_levels`
--

CREATE TABLE IF NOT EXISTS `news_article_levels` (
  `id` int(10) unsigned NOT NULL,
  `article_id` int(10) unsigned NOT NULL COMMENT 'The ID of the article this is a relation for',
  `level_id` int(10) unsigned NOT NULL COMMENT 'The ID of the level to associate with the article'
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Allows levels to be attached to articles';

-- --------------------------------------------------------

--
-- Table structure for table `news_article_notify`
--

CREATE TABLE IF NOT EXISTS `news_article_notify` (
  `id` int(10) unsigned NOT NULL,
  `article_id` int(10) unsigned NOT NULL COMMENT 'ID of the article this is a notification for',
  `method_id` int(10) unsigned NOT NULL COMMENT 'ID of the notification method doing the notify',
  `year_id` int(10) unsigned NOT NULL COMMENT 'ID of the academic year to use data for',
  `data_id` int(10) unsigned DEFAULT NULL COMMENT 'ID of the method-specific data for this notification',
  `send_after` int(10) unsigned NOT NULL DEFAULT '0' COMMENT 'When should the message be held until?',
  `send_mode` enum('immediate','delay','timed') CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL DEFAULT 'immediate' COMMENT 'How should release be handled?',
  `status` enum('invalid','draft','pending','sending','sent','cancelled','failed') CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL DEFAULT 'invalid' COMMENT 'Status of the notification',
  `message` text COMMENT 'Status message text',
  `updated` int(10) unsigned NOT NULL COMMENT 'Unix timestamp of the last update'
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `news_article_notify_emaildata`
--

CREATE TABLE IF NOT EXISTS `news_article_notify_emaildata` (
  `id` int(10) unsigned NOT NULL,
  `prefix_id` int(10) unsigned NOT NULL COMMENT 'Which prefix should be used in the email subject?',
  `cc` text CHARACTER SET utf8 COLLATE utf8_unicode_ci COMMENT 'Any CC recipients of this message',
  `bcc` text CHARACTER SET utf8 COLLATE utf8_unicode_ci COMMENT 'Any bcc recipients of the message',
  `reply_to` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL COMMENT 'Which email address should go in the reply-to?',
  `bcc_sender` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'Send a copy to the sender?'
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `news_article_notify_rms`
--

CREATE TABLE IF NOT EXISTS `news_article_notify_rms` (
  `id` int(10) unsigned NOT NULL,
  `article_notify_id` int(10) unsigned NOT NULL COMMENT 'ID of the article notification header',
  `recip_meth_id` int(11) NOT NULL COMMENT 'ID of the recipient method mapping to use'
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Stores which recipient methods have been selected for a give';

-- --------------------------------------------------------

--
-- Table structure for table `news_article_notify_twitterdata`
--

CREATE TABLE IF NOT EXISTS `news_article_notify_twitterdata` (
  `id` int(10) unsigned NOT NULL,
  `mode` enum('summary','custom') CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL DEFAULT 'summary' COMMENT 'Where is the tweet taken from?',
  `auto` enum('link','news','none') CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL DEFAULT 'link' COMMENT 'Should an automatically generated link be used?',
  `tweet` text CHARACTER SET utf8 COLLATE utf8_unicode_ci COMMENT 'Custom tweet text if mode = custom'
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `news_article_schedule_section`
--

CREATE TABLE IF NOT EXISTS `news_article_schedule_section` (
  `id` int(10) unsigned NOT NULL,
  `article_id` int(10) unsigned NOT NULL,
  `schedule_id` int(10) unsigned NOT NULL COMMENT 'ID of the schedule this article is attached to',
  `section_id` int(10) unsigned NOT NULL COMMENT 'The ID of the schedule section this article is in',
  `sort_order` tinyint(3) unsigned DEFAULT NULL COMMENT 'Explicit position in the list of articles in the selected section'
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `news_digest`
--

CREATE TABLE IF NOT EXISTS `news_digest` (
  `id` int(10) unsigned NOT NULL,
  `schedule_id` int(10) unsigned NOT NULL COMMENT 'The ID of the schedule this is a generated digest for',
  `article_id` int(10) unsigned NOT NULL COMMENT 'ID of the article generated by this digest',
  `generated` int(10) unsigned NOT NULL COMMENT 'Unix timestamp of the digest generation date'
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `news_doclinks`
--

CREATE TABLE IF NOT EXISTS `news_doclinks` (
  `id` int(10) unsigned NOT NULL,
  `name` varchar(80) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL COMMENT 'A human-readable name for the doc link',
  `url` text CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL COMMENT 'The URL the documentation resides at'
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Quick links to documentation for newsagent';

-- --------------------------------------------------------

--
-- Table structure for table `news_feeds`
--

CREATE TABLE IF NOT EXISTS `news_feeds` (
  `id` int(10) unsigned NOT NULL,
  `metadata_id` int(10) unsigned NOT NULL DEFAULT '1' COMMENT 'ID of the metadata context associated with this site',
  `name` varchar(24) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL COMMENT 'The name of the site (usually subdomain name)',
  `default_url` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL COMMENT 'Site URL to use if not defined in news_sites_urls',
  `description` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL COMMENT 'Human readable site title'
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `news_feeds_urls`
--

CREATE TABLE IF NOT EXISTS `news_feeds_urls` (
  `id` int(10) unsigned NOT NULL,
  `name` varchar(24) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL COMMENT 'The name to associate with this url',
  `url` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL COMMENT 'The URL of the article reader for this site at this level'
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Allows sites to have different URLs for article readers at d';

-- --------------------------------------------------------

--
-- Table structure for table `news_images`
--

CREATE TABLE IF NOT EXISTS `news_images` (
  `id` int(10) unsigned NOT NULL,
  `type` enum('url','file') CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL DEFAULT 'file' COMMENT 'Is this image a remote (url) image, or local (file)?',
  `md5` char(32) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL COMMENT 'The MD5 sum of the file',
  `name` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL COMMENT 'The name of the image (primarily for sorting)',
  `location` text NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Stores the locations of images used by articles';

-- --------------------------------------------------------

--
-- Table structure for table `news_import_metainfo`
--

CREATE TABLE IF NOT EXISTS `news_import_metainfo` (
  `id` int(10) unsigned NOT NULL,
  `importer_id` int(10) unsigned NOT NULL COMMENT 'The ID of the source this was imported from',
  `article_id` int(10) unsigned DEFAULT NULL COMMENT 'The ID the imported article',
  `source_id` varchar(80) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL COMMENT 'The ID the import source has given the article',
  `imported` int(10) unsigned NOT NULL COMMENT 'The timestamp of the initial import',
  `updated` int(10) unsigned NOT NULL COMMENT 'The timestamp of the last update'
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `news_import_sources`
--

CREATE TABLE IF NOT EXISTS `news_import_sources` (
  `id` int(10) unsigned NOT NULL,
  `module_id` int(10) unsigned NOT NULL COMMENT 'The ID of the module that implements the import',
  `shortname` varchar(32) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL,
  `name` varchar(80) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL COMMENT 'The name of the import',
  `frequency` int(10) unsigned NOT NULL DEFAULT '3600' COMMENT 'How often, in seconds, should the import run?',
  `last_run` int(10) unsigned NOT NULL DEFAULT '0' COMMENT 'When did the import last run?',
  `args` text
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `news_levels`
--

CREATE TABLE IF NOT EXISTS `news_levels` (
  `id` int(10) unsigned NOT NULL,
  `level` varchar(24) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL COMMENT 'The title of the article level',
  `description` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL COMMENT 'A longer human-readable description',
  `capability` varchar(80) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL COMMENT 'The capability the user must have to post at this level'
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Stores the article importance levels';

--
-- Dumping data for table `news_levels`
--

INSERT INTO `news_levels` (`id`, `level`, `description`, `capability`) VALUES
(1, 'home', 'Important (Home Page)', 'author_home'),
(2, 'leader', 'Medium (Leader Page)', 'author_leader'),
(3, 'group', 'Everything (Group Page)', 'author_group');

-- --------------------------------------------------------

--
-- Table structure for table `news_metadata`
--

CREATE TABLE IF NOT EXISTS `news_metadata` (
  `id` int(10) unsigned NOT NULL COMMENT 'id of this metadata context',
  `parent_id` int(10) unsigned DEFAULT NULL COMMENT 'id of this metadata context''s parent',
  `refcount` int(10) unsigned NOT NULL DEFAULT '0' COMMENT 'How many Thingies are currently attached to this metadata context?'
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Stores metadata context heirarchies';

--
-- Dumping data for table `news_metadata`
--

INSERT INTO `news_metadata` (`id`, `parent_id`, `refcount`) VALUES
(1, NULL, 0);

-- --------------------------------------------------------

--
-- Table structure for table `news_metadata_defrole`
--

CREATE TABLE IF NOT EXISTS `news_metadata_defrole` (
  `id` int(10) unsigned NOT NULL,
  `metadata_id` int(10) unsigned NOT NULL COMMENT 'ID of the metadata context this is a default role for',
  `role_id` int(10) unsigned NOT NULL COMMENT 'ID of the role to make the default in this context',
  `priority` tinyint(3) unsigned DEFAULT NULL COMMENT 'Role priority, overrides the priority normally set for the role if set.'
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci COMMENT='Stores default role data for metadata contexts';

-- --------------------------------------------------------

--
-- Table structure for table `news_metadata_roles`
--

CREATE TABLE IF NOT EXISTS `news_metadata_roles` (
  `id` int(10) unsigned NOT NULL COMMENT 'Relation id',
  `metadata_id` int(10) unsigned NOT NULL COMMENT 'ID of the metadata context this role is attached to',
  `role_id` int(10) unsigned NOT NULL COMMENT 'The id of the role attached to the context',
  `user_id` int(10) unsigned NOT NULL COMMENT 'The ID of the user being given the role in the metadata context',
  `source_id` int(10) unsigned DEFAULT NULL COMMENT 'The ID of the enrolment method that added this role',
  `group_id` int(10) unsigned DEFAULT NULL COMMENT 'Optional group id associated with this role assignment',
  `attached` int(10) unsigned NOT NULL COMMENT 'Date on which this role was attached to the metadata context',
  `touched` int(10) unsigned NOT NULL COMMENT 'The time this role assignment was last renewed or updated'
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Stores role assignments in metadata contexts';

-- --------------------------------------------------------

--
-- Table structure for table `news_metadata_tags`
--

CREATE TABLE IF NOT EXISTS `news_metadata_tags` (
  `id` int(10) unsigned NOT NULL COMMENT 'Relation id',
  `metadata_id` int(10) unsigned NOT NULL COMMENT 'ID of the metadata context the tag is attached to',
  `tag_id` int(10) unsigned NOT NULL COMMENT 'ID of the tag attached to the metadata context',
  `attached_by` int(10) unsigned NOT NULL COMMENT 'User ID of the user who attached the tag',
  `attached_date` int(10) unsigned NOT NULL COMMENT 'Date the tag was attached on',
  `rating` smallint(6) NOT NULL DEFAULT '0' COMMENT 'Tag rating'
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `news_metadata_tags_log`
--

CREATE TABLE IF NOT EXISTS `news_metadata_tags_log` (
  `id` int(10) unsigned NOT NULL COMMENT 'History ID',
  `metadata_id` int(10) unsigned NOT NULL COMMENT 'The id of the metadata context this event happened in',
  `tag_id` int(10) unsigned NOT NULL COMMENT 'The id if the tag being acted on',
  `event` enum('added','deleted','rate up','rate down','activate','deactivate') NOT NULL COMMENT 'What did the user do',
  `event_user` int(10) unsigned NOT NULL COMMENT 'ID of the user who did something',
  `event_time` int(10) unsigned NOT NULL COMMENT 'Timestamp of the event',
  `rating` smallint(6) NOT NULL COMMENT 'Rating set for the tag after the event'
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Stores the history of tagging actions in a metadata context';

-- --------------------------------------------------------

--
-- Table structure for table `news_notify_email_prefixes`
--

CREATE TABLE IF NOT EXISTS `news_notify_email_prefixes` (
  `id` smallint(5) unsigned NOT NULL,
  `prefix` varchar(16) COLLATE utf8_unicode_ci NOT NULL,
  `description` varchar(40) COLLATE utf8_unicode_ci NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci COMMENT='System-defined standard prefixes.';

--
-- Dumping data for table `news_notify_email_prefixes`
--

INSERT INTO `news_notify_email_prefixes` (`id`, `prefix`, `description`) VALUES
(1, '', 'No prefix');

-- --------------------------------------------------------

--
-- Table structure for table `news_notify_methods`
--

CREATE TABLE IF NOT EXISTS `news_notify_methods` (
  `id` int(10) unsigned NOT NULL,
  `name` varchar(80) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL COMMENT 'The name of the notification method',
  `module_id` int(10) unsigned NOT NULL COMMENT 'ID of the module that implements this method'
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `news_notify_methods_settings`
--

CREATE TABLE IF NOT EXISTS `news_notify_methods_settings` (
  `id` int(10) unsigned NOT NULL,
  `method_id` int(10) unsigned NOT NULL COMMENT 'ID of the method this is settings for',
  `name` varchar(80) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL COMMENT 'The name of the configuration setting',
  `value` text CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL COMMENT 'The value set for the configuration option'
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `news_notify_recipients`
--

CREATE TABLE IF NOT EXISTS `news_notify_recipients` (
  `id` int(10) unsigned NOT NULL,
  `parent` int(10) unsigned NOT NULL COMMENT 'If this is a subgroup of recipients, which recipient is its parent group?',
  `name` varchar(80) COLLATE utf8_unicode_ci NOT NULL,
  `shortname` varchar(16) COLLATE utf8_unicode_ci NOT NULL COMMENT 'Short version of the recipient name',
  `position` smallint(5) unsigned NOT NULL COMMENT 'Position within the list (or subgroup).'
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci COMMENT='Potential recipient names.';

-- --------------------------------------------------------

--
-- Table structure for table `news_notify_recipient_methods`
--

CREATE TABLE IF NOT EXISTS `news_notify_recipient_methods` (
  `id` int(10) unsigned NOT NULL,
  `metadata_id` int(10) unsigned NOT NULL COMMENT 'ID of the metadaata context this is attached to',
  `recipient_id` int(10) unsigned NOT NULL COMMENT 'The ID of the recipient group',
  `method_id` int(10) unsigned NOT NULL COMMENT 'ID of the method being used to contact them',
  `settings` text COMMENT 'Method-specific default settings'
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `news_notify_rm_year_settings`
--

CREATE TABLE IF NOT EXISTS `news_notify_rm_year_settings` (
  `id` int(10) unsigned NOT NULL,
  `rm_id` int(10) unsigned NOT NULL COMMENT 'ID of the recipient_methods relation this is data for',
  `year_id` int(10) unsigned NOT NULL COMMENT 'ID of the academic year this is data for',
  `settings` text NOT NULL COMMENT 'Year-specific settings for the recipient method relation'
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `news_roles`
--

CREATE TABLE IF NOT EXISTS `news_roles` (
  `id` int(11) NOT NULL COMMENT 'Unique ID for each role',
  `role_name` varchar(80) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL COMMENT 'The human-readable name of the role',
  `priority` tinyint(3) unsigned NOT NULL DEFAULT '0' COMMENT 'Role priority level, lower level means lower priority, higher priority overrides lower settings'
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Stores role ids and the names associated with those ids.';

--
-- Dumping data for table `news_roles`
--

INSERT INTO `news_roles` (`id`, `role_name`, `priority`) VALUES
(1, 'global_admin', 127),
(2, 'site_admin', 64),
(3, 'editor', 32),
(4, 'user', 0),
(5, 'author_group', 0),
(6, 'author_leader', 0),
(7, 'author_home', 0),
(8, 'author', 0),
(9, 'news_manage', 0);

-- --------------------------------------------------------

--
-- Table structure for table `news_role_capabilities`
--

CREATE TABLE IF NOT EXISTS `news_role_capabilities` (
  `id` int(10) unsigned NOT NULL COMMENT 'Unique role/capability ID',
  `role_id` int(10) unsigned NOT NULL COMMENT 'The ID of the role this is a capability for',
  `capability` varchar(80) COLLATE utf8_unicode_ci NOT NULL COMMENT 'The name of the capability to set on this role',
  `mode` enum('allow','deny') COLLATE utf8_unicode_ci NOT NULL DEFAULT 'allow' COMMENT 'Should the capability be allowed or denied?'
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci COMMENT='Stores the list of capabilities for each role';

--
-- Dumping data for table `news_role_capabilities`
--

INSERT INTO `news_role_capabilities` (`id`, `role_id`, `capability`, `mode`) VALUES
(1, 4, 'view', 'allow'),
(16, 2, 'author', 'allow'),
(3, 5, 'author_group', 'allow'),
(4, 6, 'author_leader', 'allow'),
(5, 7, 'author_home', 'allow'),
(6, 1, 'view', 'allow'),
(7, 1, 'compose', 'allow'),
(8, 1, 'author_group', 'allow'),
(9, 1, 'author_leader', 'allow'),
(10, 1, 'author_home', 'allow'),
(11, 8, 'listarticles', 'allow'),
(12, 1, 'listarticles', 'allow'),
(13, 1, 'edit', 'allow'),
(14, 2, 'edit', 'allow'),
(15, 3, 'edit', 'allow'),
(17, 2, 'author_leader', 'allow'),
(18, 2, 'author_home', 'allow'),
(22, 8, 'compose', 'allow'),
(24, 1, 'notify', 'allow'),
(25, 1, 'newsletter.schedule', 'allow'),
(26, 1, 'freeimg', 'allow'),
(27, 4, 'tellus.additem', 'allow'),
(28, 4, 'tellus', 'allow'),
(29, 1, 'tellus.manage', 'allow'),
(31, 1, 'newsletter', 'allow'),
(32, 1, 'newsletter.publishs', 'allow'),
(36, 1, 'newsletter.layout', 'allow');

-- --------------------------------------------------------

--
-- Table structure for table `news_schedule`
--

CREATE TABLE IF NOT EXISTS `news_schedule` (
  `id` int(10) unsigned NOT NULL,
  `metadata_id` int(10) unsigned NOT NULL COMMENT 'The ID of the metadata context associated with this schedule header',
  `name` varchar(32) NOT NULL COMMENT 'A short name for the schedule',
  `description` varchar(80) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL COMMENT 'Human readable name of the schedule',
  `article_subject` varchar(100) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL,
  `article_summary` varchar(240) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL,
  `template` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL COMMENT 'The name of the template to use for the overall release',
  `schedule` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL COMMENT 'The cron-style run schedule specification',
  `last_release` int(10) unsigned NOT NULL COMMENT 'The unix timestamp of the last time the schedule successfully released'
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `news_schedule_feeds`
--

CREATE TABLE IF NOT EXISTS `news_schedule_feeds` (
  `id` int(10) unsigned NOT NULL,
  `schedule_id` int(10) unsigned NOT NULL COMMENT 'The ID of the newsletter',
  `feed_id` int(10) unsigned NOT NULL COMMENT 'The ID of the feed to release the newsletter in'
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Records the feeds and visibility levels a newsletter should be released through.';

-- --------------------------------------------------------

--
-- Table structure for table `news_schedule_images`
--

CREATE TABLE IF NOT EXISTS `news_schedule_images` (
  `id` int(10) unsigned NOT NULL,
  `schedule_id` int(10) unsigned NOT NULL COMMENT 'The ID of the schedule this is an image setting for',
  `position` enum('a','b') CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL DEFAULT 'a' COMMENT 'Image type, a = leader, b= article',
  `image_id` int(10) unsigned NOT NULL COMMENT 'ID of the image to use'
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `news_schedule_levels`
--

CREATE TABLE IF NOT EXISTS `news_schedule_levels` (
  `id` int(10) unsigned NOT NULL,
  `schedule_id` int(10) unsigned NOT NULL COMMENT 'The ID of the newsletter',
  `level_id` int(10) unsigned NOT NULL COMMENT 'The ID of the visibility level'
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Which vis levels should newsletters be released at?';

-- --------------------------------------------------------

--
-- Table structure for table `news_schedule_methoddata`
--

CREATE TABLE IF NOT EXISTS `news_schedule_methoddata` (
  `id` int(10) unsigned NOT NULL,
  `schedule_id` int(10) unsigned NOT NULL,
  `method_id` int(10) unsigned NOT NULL,
  `data` text CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `news_schedule_notifications`
--

CREATE TABLE IF NOT EXISTS `news_schedule_notifications` (
  `id` int(10) unsigned NOT NULL,
  `schedule_id` int(10) unsigned NOT NULL,
  `notify_recipient_method_id` int(10) unsigned NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `news_schedule_sections`
--

CREATE TABLE IF NOT EXISTS `news_schedule_sections` (
  `id` int(10) unsigned NOT NULL,
  `metadata_id` int(10) unsigned NOT NULL COMMENT 'The ID of the metadata context',
  `schedule_id` int(10) unsigned NOT NULL COMMENT 'The schedule this is a section for.',
  `name` varchar(80) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL COMMENT 'Human-readable section name',
  `template` varchar(255) NOT NULL COMMENT 'Name of the template to use for this section',
  `article_tem` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL COMMENT 'The template file to wrap articles in',
  `empty_tem` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL COMMENT 'If set, use this template when section is empty',
  `required` tinyint(3) unsigned NOT NULL COMMENT 'Number of articles that must be pending in this section for release',
  `sort_order` tinyint(3) unsigned NOT NULL COMMENT 'Position within the scheduled document'
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `news_tags`
--

CREATE TABLE IF NOT EXISTS `news_tags` (
  `id` int(10) unsigned NOT NULL,
  `name` varchar(128) NOT NULL COMMENT 'The tag string',
  `creator_id` int(10) unsigned NOT NULL COMMENT 'User id of the tag creator',
  `created` int(10) unsigned NOT NULL COMMENT 'Date the tag was created'
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `news_tellus_messages`
--

CREATE TABLE IF NOT EXISTS `news_tellus_messages` (
  `id` int(10) unsigned NOT NULL,
  `creator_id` int(10) unsigned NOT NULL COMMENT 'ID of the user who submitted this',
  `created` int(10) unsigned NOT NULL COMMENT 'Unix timestamp of creation time',
  `queue_id` int(10) unsigned NOT NULL COMMENT 'ID of the queue this has been assigned to',
  `queued` int(10) unsigned NOT NULL COMMENT 'The time the queue was last updated',
  `type_id` int(10) unsigned NOT NULL COMMENT 'The type of article this is',
  `updated` int(10) unsigned NOT NULL COMMENT 'When was this article last updated?',
  `updated_by` int(10) unsigned DEFAULT NULL COMMENT 'Who updated the message last?',
  `state` enum('new','read','promoted','rejected','deleted') CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL DEFAULT 'new' COMMENT 'State of this entry',
  `reason` text CHARACTER SET utf8 COLLATE utf8_unicode_ci COMMENT 'Why was the message updated/state changed?',
  `message` text CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL COMMENT 'The text of the message'
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `news_tellus_queues`
--

CREATE TABLE IF NOT EXISTS `news_tellus_queues` (
  `id` int(10) unsigned NOT NULL,
  `metadata_id` int(10) unsigned NOT NULL COMMENT 'the Id of this queue''s metadata',
  `name` varchar(80) NOT NULL COMMENT 'The queue name',
  `position` int(10) unsigned NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `news_tellus_queues_notify`
--

CREATE TABLE IF NOT EXISTS `news_tellus_queues_notify` (
  `id` int(10) unsigned NOT NULL,
  `queue_id` int(10) unsigned NOT NULL COMMENT 'ID of the queue this is a user to notify for',
  `user_id` int(10) unsigned NOT NULL COMMENT 'ID of the user to notify about actions in this queue'
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `news_tellus_types`
--

CREATE TABLE IF NOT EXISTS `news_tellus_types` (
  `id` int(10) unsigned NOT NULL,
  `name` varchar(64) NOT NULL COMMENT 'The name of this type',
  `position` int(10) unsigned NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

--
-- Dumping data for table `news_tellus_types`
--

INSERT INTO `news_tellus_types` (`id`, `name`, `position`) VALUES
(1, 'News', 0),
(2, 'Event', 1),
(3, 'Seminar', 2),
(4, 'Other', 3);

-- --------------------------------------------------------

--
-- Table structure for table `news_twitter_autocache`
--

CREATE TABLE IF NOT EXISTS `news_twitter_autocache` (
  `id` int(10) unsigned NOT NULL,
  `screen_name` char(15) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL COMMENT 'The user''s twitter screen name',
  `name` char(20) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL COMMENT 'The user''s ''real'' name',
  `profile_img` text CHARACTER SET utf8 COLLATE utf8_unicode_ci COMMENT 'User''s profile image',
  `level` tinyint(3) unsigned NOT NULL COMMENT '0 = direct account friend/follower. 1 = fof, etc.',
  `updated` int(10) unsigned NOT NULL,
  `friend_scanned` int(10) unsigned DEFAULT NULL COMMENT 'When did the system last scan this user''s friends?',
  `follow_scanned` int(10) unsigned DEFAULT NULL COMMENT 'When did the system last scan this user''s followers?'
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `news_users_autosave`
--

CREATE TABLE IF NOT EXISTS `news_users_autosave` (
  `id` int(10) unsigned NOT NULL,
  `user_id` int(10) unsigned NOT NULL,
  `subject` varchar(100) NOT NULL,
  `summary` varchar(240) NOT NULL,
  `article` text NOT NULL,
  `saved` int(10) unsigned NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='store saved form content for the user.';

-- --------------------------------------------------------

--
-- Table structure for table `news_users_settings`
--

CREATE TABLE IF NOT EXISTS `news_users_settings` (
  `id` int(10) unsigned NOT NULL,
  `user_id` int(10) unsigned NOT NULL COMMENT 'The ID of the user this is a setting for',
  `name` varchar(80) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL COMMENT 'The name of the setting',
  `value` text CHARACTER SET utf8 COLLATE utf8_unicode_ci COMMENT 'The value for the setting for this user.'
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Saves user preferences';

-- --------------------------------------------------------

--
-- Table structure for table `sessions`
--

CREATE TABLE IF NOT EXISTS `sessions` (
  `session_id` char(32) NOT NULL,
  `session_user_id` int(10) unsigned NOT NULL,
  `session_start` int(11) unsigned NOT NULL,
  `session_time` int(11) unsigned NOT NULL,
  `session_ip` varchar(40) DEFAULT NULL,
  `session_autologin` tinyint(1) unsigned NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Website sessions';

-- --------------------------------------------------------

--
-- Table structure for table `session_keys`
--

CREATE TABLE IF NOT EXISTS `session_keys` (
  `key_id` char(32) COLLATE utf8_bin NOT NULL DEFAULT '',
  `user_id` int(10) unsigned NOT NULL DEFAULT '0',
  `last_ip` varchar(40) COLLATE utf8_bin NOT NULL DEFAULT '',
  `last_login` int(11) unsigned NOT NULL DEFAULT '0'
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_bin COMMENT='Autologin keys';

-- --------------------------------------------------------

--
-- Table structure for table `session_variables`
--

CREATE TABLE IF NOT EXISTS `session_variables` (
  `session_id` char(32) NOT NULL,
  `var_name` varchar(80) NOT NULL,
  `var_value` text NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Session-related variables';

-- --------------------------------------------------------

--
-- Table structure for table `settings`
--

CREATE TABLE IF NOT EXISTS `settings` (
  `name` varchar(255) COLLATE utf8_unicode_ci NOT NULL,
  `value` text COLLATE utf8_unicode_ci NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci COMMENT='Site settings';

--
-- Dumping data for table `settings`
--

INSERT INTO `settings` (`name`, `value`) VALUES
('base', '/var/www/path/to/newsagent'),
('scriptpath', '/newsagent'),
('cookie_name', 'newsagent'),
('cookie_path', '/'),
('cookie_domain', ''),
('cookie_secure', '0'),
('default_style', 'default'),
('logfile', ''),
('default_block', 'feeds'),
('Auth:allow_autologin', '1'),
('Auth:max_autologin_time', '30'),
('Auth:ip_check', '4'),
('Auth:session_length', '3600'),
('Auth:session_gc', '0'),
('Auth:unique_id', '1503'),
('Session:lastgc', '1421247858'),
('Core:envelope_address', 'your@email.address'),
('Log:all_the_things', '1'),
('timefmt', '%d %b %Y %H:%M:%S %Z'),
('datefmt', '%d %b %Y'),
('Core:admin_email', 'your@email.address'),
('Message::Transport::Email::smtp_host', 'localhost'),
('Message::Transport::Email::smtp_port', '25'),
('Login:allow_self_register', '1'),
('Login:self_register_answer', 'orange'),
('Login:self_register_question', 'Which of these colours is also a fruit? Blue, orange, red'),
('site_name', 'Newsagent'),
('default_authmethod', '1'),
('Article:upload_image_path', '/var/www/path/to/newsagent/images'),
('Article:upload_image_url', 'https://server.url/newsagent/images'),
('Feed:count', '10'),
('Feed:count_limit', '100'),
('RSS:editor', 'your@email.addy (Your Email)'),
('RSS:webmaster', 'your@email.addy (Your Email)'),
('RSS:title', 'Feed Title'),
('RSS:description', 'The latest news and events'),
('HTML:default_image', 'kilburn.jpg'),
('Feed:default_level', 'group'),
('Feed:max_age', '1y'),
('Article::List:count', '15'),
('Article:logo_img_url', 'https://server.url/newsagent/templates/default/images/uom_logo.png'),
('Notification:hold_delay', '1'),
('Article:multifeed_context_parent', '1'),
('Article::List:default_modes', 'hidden,visible,timed,released,next,after'),
('httphost', 'https://server.url/'),
('jsdirid', 'c4b839f'),
('newsletter:future_count', '104');

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE IF NOT EXISTS `users` (
  `user_id` int(10) unsigned NOT NULL,
  `user_auth` tinyint(3) unsigned DEFAULT NULL COMMENT 'Id of the user''s auth method',
  `user_type` tinyint(3) unsigned DEFAULT '0' COMMENT 'The user type, 0 = normal, 3 = admin',
  `username` varchar(32) NOT NULL,
  `realname` varchar(128) DEFAULT NULL,
  `password` char(59) DEFAULT NULL,
  `password_set` int(10) unsigned DEFAULT NULL,
  `force_change` tinyint(1) unsigned NOT NULL DEFAULT '0' COMMENT 'Should the user be forced to change the password?',
  `fail_count` tinyint(3) unsigned NOT NULL DEFAULT '0' COMMENT 'How many login failures has this user had?',
  `email` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL COMMENT 'User''s email address',
  `created` int(10) unsigned NOT NULL COMMENT 'The unix time at which this user was created',
  `activated` int(10) unsigned DEFAULT NULL COMMENT 'Is the user account active, and if so when was it activated?',
  `act_code` varchar(64) DEFAULT NULL COMMENT 'Activation code the user must provide when activating their account',
  `last_login` int(10) unsigned NOT NULL COMMENT 'The unix time of th euser''s last login'
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Stores the local user data for each user in the system';

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`user_id`, `user_auth`, `user_type`, `username`, `realname`, `password`, `password_set`, `force_change`, `fail_count`, `email`, `created`, `activated`, `act_code`, `last_login`) VALUES
(1, NULL, 0, 'anonymous', NULL, NULL, NULL, 0, 0, NULL, 1338463934, 1338463934, NULL, 1338463934);

--
-- Indexes for dumped tables
--

--
-- Indexes for table `auth_methods`
--
ALTER TABLE `auth_methods`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `auth_methods_params`
--
ALTER TABLE `auth_methods_params`
  ADD PRIMARY KEY (`id`), ADD KEY `method_id` (`method_id`);

--
-- Indexes for table `blocks`
--
ALTER TABLE `blocks`
  ADD PRIMARY KEY (`id`), ADD UNIQUE KEY `name` (`name`);

--
-- Indexes for table `language`
--
ALTER TABLE `language`
  ADD PRIMARY KEY (`id`), ADD KEY `name` (`name`,`lang`);

--
-- Indexes for table `log`
--
ALTER TABLE `log`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `messages_queue`
--
ALTER TABLE `messages_queue`
  ADD PRIMARY KEY (`id`), ADD KEY `created` (`created`), ADD KEY `deleted` (`deleted`), ADD KEY `message_ident` (`message_ident`), ADD KEY `previous_id` (`previous_id`);

--
-- Indexes for table `messages_recipients`
--
ALTER TABLE `messages_recipients`
  ADD KEY `email_id` (`message_id`), ADD KEY `recipient_id` (`recipient_id`);

--
-- Indexes for table `messages_sender`
--
ALTER TABLE `messages_sender`
  ADD KEY `message_id` (`message_id`), ADD KEY `sender_id` (`sender_id`);

--
-- Indexes for table `messages_transports`
--
ALTER TABLE `messages_transports`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `messages_transports_status`
--
ALTER TABLE `messages_transports_status`
  ADD PRIMARY KEY (`id`), ADD KEY `message_id` (`message_id`), ADD KEY `transport_id` (`transport_id`), ADD KEY `status` (`status`);

--
-- Indexes for table `messages_transports_userctrl`
--
ALTER TABLE `messages_transports_userctrl`
  ADD KEY `transport_id` (`transport_id`), ADD KEY `user_id` (`user_id`), ADD KEY `transport_user` (`transport_id`,`user_id`);

--
-- Indexes for table `modules`
--
ALTER TABLE `modules`
  ADD PRIMARY KEY (`module_id`);

--
-- Indexes for table `news_articles`
--
ALTER TABLE `news_articles`
  ADD PRIMARY KEY (`id`), ADD KEY `previous_id` (`previous_id`), ADD KEY `creator_id` (`creator_id`), ADD KEY `preset` (`preset`), ADD KEY `release_mode` (`release_mode`), ADD KEY `release_time` (`release_time`), ADD KEY `created` (`created`);

--
-- Indexes for table `news_article_digest_section`
--
ALTER TABLE `news_article_digest_section`
  ADD PRIMARY KEY (`id`), ADD KEY `article_id` (`article_id`), ADD KEY `digest_id` (`digest_id`);

--
-- Indexes for table `news_article_feeds`
--
ALTER TABLE `news_article_feeds`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `news_article_images`
--
ALTER TABLE `news_article_images`
  ADD PRIMARY KEY (`id`), ADD KEY `article_id` (`article_id`), ADD KEY `order` (`order`);

--
-- Indexes for table `news_article_levels`
--
ALTER TABLE `news_article_levels`
  ADD PRIMARY KEY (`id`), ADD KEY `article_id` (`article_id`), ADD KEY `level_id` (`level_id`);

--
-- Indexes for table `news_article_notify`
--
ALTER TABLE `news_article_notify`
  ADD PRIMARY KEY (`id`), ADD KEY `article_id` (`article_id`), ADD KEY `status` (`status`);

--
-- Indexes for table `news_article_notify_emaildata`
--
ALTER TABLE `news_article_notify_emaildata`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `news_article_notify_rms`
--
ALTER TABLE `news_article_notify_rms`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `news_article_notify_twitterdata`
--
ALTER TABLE `news_article_notify_twitterdata`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `news_article_schedule_section`
--
ALTER TABLE `news_article_schedule_section`
  ADD PRIMARY KEY (`id`), ADD KEY `schedule_id` (`schedule_id`);

--
-- Indexes for table `news_digest`
--
ALTER TABLE `news_digest`
  ADD PRIMARY KEY (`id`), ADD KEY `schedule_id` (`schedule_id`);

--
-- Indexes for table `news_doclinks`
--
ALTER TABLE `news_doclinks`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `news_feeds`
--
ALTER TABLE `news_feeds`
  ADD PRIMARY KEY (`id`), ADD KEY `name` (`name`);

--
-- Indexes for table `news_feeds_urls`
--
ALTER TABLE `news_feeds_urls`
  ADD PRIMARY KEY (`id`), ADD KEY `site_id` (`name`);

--
-- Indexes for table `news_images`
--
ALTER TABLE `news_images`
  ADD PRIMARY KEY (`id`), ADD KEY `type` (`type`), ADD KEY `name` (`name`), ADD KEY `md5` (`md5`);

--
-- Indexes for table `news_import_metainfo`
--
ALTER TABLE `news_import_metainfo`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `news_import_sources`
--
ALTER TABLE `news_import_sources`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `news_levels`
--
ALTER TABLE `news_levels`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `news_metadata`
--
ALTER TABLE `news_metadata`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `news_metadata_defrole`
--
ALTER TABLE `news_metadata_defrole`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `news_metadata_roles`
--
ALTER TABLE `news_metadata_roles`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `news_metadata_tags`
--
ALTER TABLE `news_metadata_tags`
  ADD PRIMARY KEY (`id`), ADD KEY `tag_id` (`tag_id`), ADD KEY `metadata_id` (`metadata_id`);

--
-- Indexes for table `news_metadata_tags_log`
--
ALTER TABLE `news_metadata_tags_log`
  ADD PRIMARY KEY (`id`), ADD KEY `event_time` (`event_time`);

--
-- Indexes for table `news_notify_email_prefixes`
--
ALTER TABLE `news_notify_email_prefixes`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `news_notify_methods`
--
ALTER TABLE `news_notify_methods`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `news_notify_methods_settings`
--
ALTER TABLE `news_notify_methods_settings`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `news_notify_recipients`
--
ALTER TABLE `news_notify_recipients`
  ADD PRIMARY KEY (`id`), ADD KEY `parent` (`parent`), ADD KEY `position` (`parent`,`position`);

--
-- Indexes for table `news_notify_recipient_methods`
--
ALTER TABLE `news_notify_recipient_methods`
  ADD PRIMARY KEY (`id`), ADD KEY `recipient_id` (`recipient_id`);

--
-- Indexes for table `news_notify_rm_year_settings`
--
ALTER TABLE `news_notify_rm_year_settings`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `news_roles`
--
ALTER TABLE `news_roles`
  ADD PRIMARY KEY (`id`), ADD KEY `role_name` (`role_name`);

--
-- Indexes for table `news_role_capabilities`
--
ALTER TABLE `news_role_capabilities`
  ADD PRIMARY KEY (`id`), ADD KEY `role_id` (`role_id`), ADD KEY `role_capability` (`role_id`,`capability`);

--
-- Indexes for table `news_schedule`
--
ALTER TABLE `news_schedule`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `news_schedule_feeds`
--
ALTER TABLE `news_schedule_feeds`
  ADD PRIMARY KEY (`id`), ADD KEY `schedule_id` (`schedule_id`);

--
-- Indexes for table `news_schedule_images`
--
ALTER TABLE `news_schedule_images`
  ADD PRIMARY KEY (`id`), ADD KEY `schedule_id` (`schedule_id`);

--
-- Indexes for table `news_schedule_levels`
--
ALTER TABLE `news_schedule_levels`
  ADD PRIMARY KEY (`id`), ADD KEY `schedule_id` (`schedule_id`);

--
-- Indexes for table `news_schedule_methoddata`
--
ALTER TABLE `news_schedule_methoddata`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `news_schedule_notifications`
--
ALTER TABLE `news_schedule_notifications`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `news_schedule_sections`
--
ALTER TABLE `news_schedule_sections`
  ADD PRIMARY KEY (`id`), ADD KEY `schedule_id` (`schedule_id`);

--
-- Indexes for table `news_tags`
--
ALTER TABLE `news_tags`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `news_tellus_messages`
--
ALTER TABLE `news_tellus_messages`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `news_tellus_queues`
--
ALTER TABLE `news_tellus_queues`
  ADD PRIMARY KEY (`id`), ADD KEY `position` (`position`);

--
-- Indexes for table `news_tellus_queues_notify`
--
ALTER TABLE `news_tellus_queues_notify`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `news_tellus_types`
--
ALTER TABLE `news_tellus_types`
  ADD PRIMARY KEY (`id`), ADD KEY `position` (`position`);

--
-- Indexes for table `news_twitter_autocache`
--
ALTER TABLE `news_twitter_autocache`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `news_users_autosave`
--
ALTER TABLE `news_users_autosave`
  ADD PRIMARY KEY (`id`), ADD UNIQUE KEY `user_id` (`user_id`);

--
-- Indexes for table `news_users_settings`
--
ALTER TABLE `news_users_settings`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `sessions`
--
ALTER TABLE `sessions`
  ADD PRIMARY KEY (`session_id`), ADD KEY `session_time` (`session_time`), ADD KEY `session_user_id` (`session_user_id`);

--
-- Indexes for table `session_keys`
--
ALTER TABLE `session_keys`
  ADD PRIMARY KEY (`key_id`,`user_id`), ADD KEY `last_login` (`last_login`);

--
-- Indexes for table `session_variables`
--
ALTER TABLE `session_variables`
  ADD KEY `session_id` (`session_id`), ADD KEY `sess_name_map` (`session_id`,`var_name`);

--
-- Indexes for table `settings`
--
ALTER TABLE `settings`
  ADD PRIMARY KEY (`name`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`user_id`), ADD UNIQUE KEY `username` (`username`), ADD KEY `email` (`email`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `auth_methods`
--
ALTER TABLE `auth_methods`
  MODIFY `id` tinyint(3) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `auth_methods_params`
--
ALTER TABLE `auth_methods_params`
  MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `blocks`
--
ALTER TABLE `blocks`
  MODIFY `id` smallint(5) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Unique ID for this block entry';
--
-- AUTO_INCREMENT for table `language`
--
ALTER TABLE `language`
  MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `log`
--
ALTER TABLE `log`
  MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `messages_queue`
--
ALTER TABLE `messages_queue`
  MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `messages_transports`
--
ALTER TABLE `messages_transports`
  MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `messages_transports_status`
--
ALTER TABLE `messages_transports_status`
  MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `modules`
--
ALTER TABLE `modules`
  MODIFY `module_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Unique module id';
--
-- AUTO_INCREMENT for table `news_articles`
--
ALTER TABLE `news_articles`
  MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `news_article_digest_section`
--
ALTER TABLE `news_article_digest_section`
  MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `news_article_feeds`
--
ALTER TABLE `news_article_feeds`
  MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `news_article_images`
--
ALTER TABLE `news_article_images`
  MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `news_article_levels`
--
ALTER TABLE `news_article_levels`
  MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `news_article_notify`
--
ALTER TABLE `news_article_notify`
  MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `news_article_notify_emaildata`
--
ALTER TABLE `news_article_notify_emaildata`
  MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `news_article_notify_rms`
--
ALTER TABLE `news_article_notify_rms`
  MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `news_article_notify_twitterdata`
--
ALTER TABLE `news_article_notify_twitterdata`
  MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `news_article_schedule_section`
--
ALTER TABLE `news_article_schedule_section`
  MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `news_digest`
--
ALTER TABLE `news_digest`
  MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `news_doclinks`
--
ALTER TABLE `news_doclinks`
  MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `news_feeds`
--
ALTER TABLE `news_feeds`
  MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `news_feeds_urls`
--
ALTER TABLE `news_feeds_urls`
  MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `news_images`
--
ALTER TABLE `news_images`
  MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `news_import_metainfo`
--
ALTER TABLE `news_import_metainfo`
  MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `news_import_sources`
--
ALTER TABLE `news_import_sources`
  MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `news_levels`
--
ALTER TABLE `news_levels`
  MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `news_metadata`
--
ALTER TABLE `news_metadata`
  MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'id of this metadata context';
--
-- AUTO_INCREMENT for table `news_metadata_defrole`
--
ALTER TABLE `news_metadata_defrole`
  MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `news_metadata_roles`
--
ALTER TABLE `news_metadata_roles`
  MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Relation id';
--
-- AUTO_INCREMENT for table `news_metadata_tags`
--
ALTER TABLE `news_metadata_tags`
  MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Relation id';
--
-- AUTO_INCREMENT for table `news_metadata_tags_log`
--
ALTER TABLE `news_metadata_tags_log`
  MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'History ID';
--
-- AUTO_INCREMENT for table `news_notify_email_prefixes`
--
ALTER TABLE `news_notify_email_prefixes`
  MODIFY `id` smallint(5) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `news_notify_methods`
--
ALTER TABLE `news_notify_methods`
  MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `news_notify_methods_settings`
--
ALTER TABLE `news_notify_methods_settings`
  MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `news_notify_recipients`
--
ALTER TABLE `news_notify_recipients`
  MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `news_notify_recipient_methods`
--
ALTER TABLE `news_notify_recipient_methods`
  MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `news_notify_rm_year_settings`
--
ALTER TABLE `news_notify_rm_year_settings`
  MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `news_roles`
--
ALTER TABLE `news_roles`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT COMMENT 'Unique ID for each role';
--
-- AUTO_INCREMENT for table `news_role_capabilities`
--
ALTER TABLE `news_role_capabilities`
  MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Unique role/capability ID';
--
-- AUTO_INCREMENT for table `news_schedule`
--
ALTER TABLE `news_schedule`
  MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `news_schedule_feeds`
--
ALTER TABLE `news_schedule_feeds`
  MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `news_schedule_images`
--
ALTER TABLE `news_schedule_images`
  MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `news_schedule_levels`
--
ALTER TABLE `news_schedule_levels`
  MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `news_schedule_methoddata`
--
ALTER TABLE `news_schedule_methoddata`
  MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `news_schedule_notifications`
--
ALTER TABLE `news_schedule_notifications`
  MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `news_schedule_sections`
--
ALTER TABLE `news_schedule_sections`
  MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `news_tags`
--
ALTER TABLE `news_tags`
  MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `news_tellus_messages`
--
ALTER TABLE `news_tellus_messages`
  MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `news_tellus_queues`
--
ALTER TABLE `news_tellus_queues`
  MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `news_tellus_queues_notify`
--
ALTER TABLE `news_tellus_queues_notify`
  MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `news_tellus_types`
--
ALTER TABLE `news_tellus_types`
  MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `news_users_autosave`
--
ALTER TABLE `news_users_autosave`
  MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `news_users_settings`
--
ALTER TABLE `news_users_settings`
  MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `user_id` int(10) unsigned NOT NULL AUTO_INCREMENT;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
