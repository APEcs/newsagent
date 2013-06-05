-- phpMyAdmin SQL Dump
-- version 3.5.8
-- http://www.phpmyadmin.net
--
-- Host: localhost
-- Generation Time: Jun 05, 2013 at 02:03 PM
-- Server version: 5.1.67-log
-- PHP Version: 5.4.13--pl0-gentoo

SET SQL_MODE="NO_AUTO_VALUE_ON_ZERO";
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
  `id` tinyint(3) unsigned NOT NULL AUTO_INCREMENT,
  `perl_module` varchar(100) NOT NULL COMMENT 'The name of the AuthMethod (no .pm extension)',
  `priority` tinyint(4) NOT NULL COMMENT 'The authentication method''s priority. -128 = max, 127 = min',
  `enabled` tinyint(1) NOT NULL COMMENT 'Is this auth method usable?',
  PRIMARY KEY (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COMMENT='Stores the authentication methods supported by the system' AUTO_INCREMENT=2 ;

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
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `method_id` tinyint(4) NOT NULL COMMENT 'The id of the auth method',
  `name` varchar(40) NOT NULL COMMENT 'The parameter mame',
  `value` text NOT NULL COMMENT 'The value for the parameter',
  PRIMARY KEY (`id`),
  KEY `method_id` (`method_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COMMENT='Stores the settings for each auth method' AUTO_INCREMENT=7 ;

--
-- Dumping data for table `auth_methods_params`
--

INSERT INTO `auth_methods_params` (`id`, `method_id`, `name`, `value`) VALUES
(1, 1, 'table', 'users'),
(2, 1, 'userfield', 'username'),
(3, 1, 'passfield', 'password'),
(4, 1, 'policy_use_cracklib', '1'),
(5, 1, 'policy_min_length', '8'),
(6, 1, 'policy_max_loginfail', '5');

-- --------------------------------------------------------

--
-- Table structure for table `blocks`
--

CREATE TABLE IF NOT EXISTS `blocks` (
  `id` smallint(5) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Unique ID for this block entry',
  `name` varchar(32) NOT NULL,
  `module_id` smallint(5) unsigned NOT NULL COMMENT 'ID of the module implementing this block',
  `args` varchar(128) NOT NULL COMMENT 'Arguments passed verbatim to the block module',
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COMMENT='web-accessible page modules' AUTO_INCREMENT=7 ;

--
-- Dumping data for table `blocks`
--

INSERT INTO `blocks` (`id`, `name`, `module_id`, `args`) VALUES
(1, 'compose', 1, ''),
(2, 'login', 2, ''),
(3, 'rss', 3, ''),
(4, 'html', 4, ''),
(5, 'articles', 5, ''),
(6, 'edit', 6, '');

-- --------------------------------------------------------

--
-- Table structure for table `language`
--

CREATE TABLE IF NOT EXISTS `language` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8_unicode_ci NOT NULL COMMENT 'The language variable name',
  `lang` varchar(8) COLLATE utf8_unicode_ci NOT NULL DEFAULT 'en' COMMENT 'The language the variable is in',
  `message` text COLLATE utf8_unicode_ci NOT NULL COMMENT 'The language variable message',
  PRIMARY KEY (`id`),
  KEY `name` (`name`,`lang`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci COMMENT='Stores language variable definitions' AUTO_INCREMENT=283 ;

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
(11, 'ALIST_CTRLEDIT', 'en', 'Edit this article'),
(12, 'ALIST_CTRLHIDE', 'en', 'Unpublish (hide) this article'),
(13, 'ALIST_CTRLDELETE', 'en', 'Delete this article'),
(14, 'ALIST_CTRLUNDELETE', 'en', 'Restore this article'),
(15, 'ALIST_CTRLUNHIDE', 'en', 'Show this article'),
(16, 'ALIST_CTRLPUBLISH', 'en', 'Publish this article immediately'),
(17, 'USERBAR_PROFILE_EDIT', 'en', 'Edit Profile'),
(18, 'USERBAR_PROFILE_PREFS', 'en', 'Change Settings'),
(19, 'USERBAR_PROFILE_LOGOUT', 'en', 'Log out'),
(20, 'USERBAR_PROFILE_LOGIN', 'en', 'Log in'),
(21, 'USERBAR_ARTICLE_LIST', 'en', 'Article list'),
(22, 'USERBAR_COMPOSE', 'en', 'Add an article'),
(23, 'USERBAR_SITE_SETTINGS', 'en', 'Administer site'),
(24, 'EDIT_ERROR_TITLE', 'en', 'Edit error'),
(25, 'EDIT_ERROR_NOID_SUMMARY', 'en', 'No article ID specified.'),
(26, 'EDIT_ERROR_NOID_DESC', 'en', 'The system has been unable to determine which article you want to edit, as no ID has been passed to it. If you followed a link to this page, please report it to <a href="mailto:{V_[admin_email]}">{V_[admin_email]}</a>.'),
(27, 'EDIT_ERROR_BADID_SUMMARY', 'en', 'Unable to obtain the data for the requested article.'),
(28, 'EDIT_FORM_TITLE', 'en', 'Edit article'),
(29, 'EDIT_ARTICLE', 'en', 'Edit article'),
(30, 'EDIT_SUBMIT', 'en', 'Edit article'),
(31, 'EDIT_FAILED', 'en', 'Article editing failed'),
(32, 'EDIT_EDITED_TITLE', 'en', 'Article Edited'),
(33, 'EDIT_EDITED_SUMMARY', 'en', 'Article edited successfully.'),
(34, 'EDIT_EDITED_DESC', 'en', 'Your article has been updated successfully. If you set it for immediate publication, it should be visible on feeds now; timed articles will be released when the selected time has passed. You will be redirected to your article list shortly, or you can click ''continue'' to return to it now.'),
(35, 'PERMISSION_FAILED_TITLE', 'en', 'Access denied'),
(36, 'PERMISSION_FAILED_SUMMARY', 'en', 'You do not have permission to perform this operation.'),
(37, 'PERMISSION_VIEW_DESC', 'en', 'You do not have permission to view the requested resource. If you think this is incorrect, please contact <a href="mailto:{V_[admin_email]}">{V_[admin_email]}</a> for assistance.'),
(38, 'PERMISSION_COMPOSE_DESC', 'en', 'You do not have permission to compose articles. If you think this is incorrect, please contact <a href="mailto:{V_[admin_email]}">{V_[admin_email]}</a> for assistance.'),
(39, 'PERMISSION_LISTARTICLE_DESC', 'en', 'You do not have permission to view the list of articles. If you think this is incorrect, please contact <a href="mailto:{V_[admin_email]}">{V_[admin_email]}</a> for assistance.'),
(40, 'PERMISSION_EDIT_DESC', 'en', 'You do not have permission to edit this article. If you think this is incorrect, please contact <a href="mailto:{V_[admin_email]}">{V_[admin_email]}</a> for assistance.'),
(41, 'NAVBOX_PAGEOF', 'en', 'Page ***pagenum*** of ***maxpage***'),
(42, 'NAVBOX_FIRST', 'en', 'First'),
(43, 'NAVBOX_PREV', 'en', 'Prev'),
(44, 'NAVBOX_NEXT', 'en', 'Next'),
(45, 'NAVBOX_LAST', 'en', 'Last'),
(46, 'NAVBOX_SPACER', 'en', ''),
(47, 'EMAIL_SIG', 'en', 'The {V_[sitename]} Team'),
(48, 'SITE_CONTINUE', 'en', 'Continue'),
(49, 'API_BAD_OP', 'en', 'Unknown API operation requested.'),
(50, 'API_BAD_CALL', 'en', 'Incorrect invocation of an API-only module.'),
(51, 'API_ERROR', 'en', 'An internal API error has occurred: ***error***'),
(52, 'API_ERROR_NOAID', 'en', 'No article ID was included in the API request.'),
(53, 'TIMES_JUSTNOW', 'en', 'just now'),
(54, 'TIMES_SECONDS', 'en', '%t seconds ago'),
(55, 'TIMES_MINUTE', 'en', 'a minute ago'),
(56, 'TIMES_MINUTES', 'en', '%t minutes ago'),
(57, 'TIMES_HOUR', 'en', 'an hour ago'),
(58, 'TIMES_HOURS', 'en', '%t hours ago'),
(59, 'TIMES_DAY', 'en', 'a day ago'),
(60, 'TIMES_DAYS', 'en', '%t days ago'),
(61, 'TIMES_WEEK', 'en', 'a week ago'),
(62, 'TIMES_WEEKS', 'en', '%t weeks ago'),
(63, 'TIMES_MONTH', 'en', 'a month ago'),
(64, 'TIMES_MONTHS', 'en', '%t months ago'),
(65, 'TIMES_YEAR', 'en', 'a year ago'),
(66, 'TIMES_YEARS', 'en', '%t years ago'),
(67, 'FUTURE_JUSTNOW', 'en', 'shortly'),
(68, 'FUTURE_SECONDS', 'en', 'in %t seconds'),
(69, 'FUTURE_MINUTE', 'en', 'in a minute'),
(70, 'FUTURE_MINUTES', 'en', 'in %t minutes'),
(71, 'FUTURE_HOUR', 'en', 'in an hour'),
(72, 'FUTURE_HOURS', 'en', 'in %t hours'),
(73, 'FUTURE_DAY', 'en', 'in a day'),
(74, 'FUTURE_DAYS', 'en', 'in %t days'),
(75, 'FUTURE_WEEK', 'en', 'in a week'),
(76, 'FUTURE_WEEKS', 'en', 'in %t weeks'),
(77, 'FUTURE_MONTH', 'en', 'in a month'),
(78, 'FUTURE_MONTHS', 'en', 'in %t months'),
(79, 'FUTURE_YEAR', 'en', 'in a year'),
(80, 'FUTURE_YEARS', 'en', 'in %t years'),
(81, 'BLOCK_BLOCK_DISPLAY', 'en', 'Direct call to unimplemented block_display()'),
(82, 'BLOCK_SECTION_DISPLAY', 'en', 'Direct call to unimplemented section_display()'),
(83, 'PAGE_ERROR', 'en', 'Error'),
(84, 'PAGE_ERROROK', 'en', 'Okay'),
(85, 'COMPOSE_FORM_TITLE', 'en', 'Compose article'),
(86, 'FORM_OPTIONAL', 'en', '(optional)'),
(87, 'COMPOSE_TITLE', 'en', 'Title'),
(88, 'COMPOSE_URL', 'en', 'Link to more information'),
(89, 'COMPOSE_SUMMARY', 'en', 'Summary'),
(90, 'COMPOSE_SUMM_INFO', 'en', 'Enter a short summary of your article here (<span id="sumchars"></span> characters left)'),
(91, 'COMPOSE_DESC', 'en', 'Full text'),
(92, 'COMPOSE_RELMODE', 'en', 'Release mode'),
(93, 'COMPOSE_BATCH', 'en', 'Batch Release'),
(94, 'COMPOSE_NORMAL', 'en', 'Standard Release'),
(95, 'COMPOSE_IMAGEA', 'en', 'Lead Image'),
(96, 'COMPOSE_IMAGEB', 'en', 'Article Image'),
(97, 'COMPOSE_SITE', 'en', 'Post from'),
(98, 'COMPOSE_LEVEL', 'en', 'Visibility levels'),
(99, 'COMPOSE_RELEASE', 'en', 'Publish'),
(100, 'COMPOSE_RELNOW', 'en', 'Immediately'),
(101, 'COMPOSE_RELTIME', 'en', 'At the specified time'),
(102, 'COMPOSE_RELNONE', 'en', 'Never (save as draft)'),
(103, 'COMPOSE_RELDATE', 'en', 'Publish time'),
(104, 'COMPOSE_SUBMIT', 'en', 'Create article'),
(105, 'COMPOSE_FAILED', 'en', 'Unable to create new article, the following errors were encountered:'),
(106, 'COMPOSE_ARTICLE', 'en', 'Article'),
(107, 'COMPOSE_SETTINGS', 'en', 'Settings'),
(108, 'COMPOSE_IMAGES', 'en', 'Images'),
(109, 'COMPOSE_IMGNONE', 'en', 'No image'),
(110, 'COMPOSE_IMGURL', 'en', 'Image URL'),
(111, 'COMPOSE_IMGFILE', 'en', 'Upload image file'),
(112, 'COMPOSE_IMG', 'en', 'Existing image'),
(113, 'COMPOSE_IMGURL_DESC', 'en', 'The image URL must be an absolute URL stating http:// or https://'),
(114, 'COMPOSE_IMGFILE_ERRNOFILE', 'en', 'No file has been selected for ***field***'),
(115, 'COMPOSE_IMGFILE_ERRNOTMP', 'en', 'An internal error (no upload temp file) occurred when processing ***field***'),
(116, 'COMPOSE_LEVEL_ERRNONE', 'en', 'No visibility levels have been selected. You must select at least one visibility level.'),
(117, 'COMPOSE_ADDED_TITLE', 'en', 'Article Added'),
(118, 'COMPOSE_ADDED_SUMMARY', 'en', 'Article created and added to the system successfully.'),
(119, 'COMPOSE_ADDED_DESC', 'en', 'Your article has been added to the system. If you set it for immediate publication, it should be visible on feeds now; timed articles will be released when the selected time has passed. You will be redirected to the compose form shortly, or you can click ''continue'' to return to it now.'),
(120, 'LOGIN_TITLE', 'en', 'Log in'),
(121, 'LOGIN_LOGINFORM', 'en', 'Log in'),
(122, 'LOGIN_INTRO', 'en', 'Enter your username and password to log in.'),
(123, 'LOGIN_USERNAME', 'en', 'Username'),
(124, 'LOGIN_PASSWORD', 'en', 'Password'),
(125, 'LOGIN_EMAIL', 'en', 'Email address'),
(126, 'LOGIN_PERSIST', 'en', 'Remember me'),
(127, 'LOGIN_LOGIN', 'en', 'Log in'),
(128, 'LOGIN_FAILED', 'en', 'Login failed'),
(129, 'LOGIN_RECOVER', 'en', 'Forgotten your username or password?'),
(130, 'LOGIN_SENDACT', 'en', 'Click to resend your activation code'),
(131, 'PERSIST_WARNING', 'en', '<strong>WARNING</strong>: do not enable the "Remember me" option on shared, cluster, or public computers. This option should only be enabled on machines you have exclusive access to.'),
(132, 'LOGIN_DONETITLE', 'en', 'Logged in'),
(133, 'LOGIN_SUMMARY', 'en', 'You have successfully logged into the system.'),
(134, 'LOGIN_LONGDESC', 'en', 'You have successfully logged in, and you will be redirected shortly. If you do not want to wait, click continue. Alternatively, <a href="{V_[scriptpath]}">Click here</a> to return to the front page.'),
(135, 'LOGIN_NOREDIRECT', 'en', 'You have successfully logged in, but warnings were encountered during login. Please check the warning messages, and <a href="mailto:***supportaddr***">contact support</a> if a serious problem has been encountered, otherwise, click continue. Alternatively, <a href="{V_[scriptpath]}">Click here</a> to return to the front page.'),
(136, 'LOGOUT_TITLE', 'en', 'Logged out'),
(137, 'LOGOUT_SUMMARY', 'en', 'You have successfully logged out.'),
(138, 'LOGOUT_LONGDESC', 'en', 'You have successfully logged out, and you will be redirected shortly. If you do not want to wait, click continue. Alternatively, <a href="{V_[scriptpath]}">Click here</a> to return to the front page.'),
(139, 'LOGIN_ERR_BADUSERCHAR', 'en', 'Illegal character in username. Usernames may only contain alphanumeric characters, underscores, or hyphens.'),
(140, 'LOGIN_ERR_INVALID', 'en', 'Login failed: unknown username or password provided.'),
(141, 'LOGIN_REGISTER', 'en', 'Sign up'),
(142, 'LOGIN_REG_INTRO', 'en', 'Create an account by choosing a username and giving a valid email address. A password will be emailed to you.'),
(143, 'LOGIN_SECURITY', 'en', 'Security question'),
(144, 'LOGIN_SEC_INTRO', 'en', 'In order to prevent abuse by automated spamming systems, please answer the following question to prove that you are a human.<br/>Note: the answer is not case sensitive.'),
(145, 'LOGIN_SEC_SUBMIT', 'en', 'Sign up'),
(146, 'LOGIN_ERR_NOSELFREG', 'en', 'Self-registration is not currently permitted.'),
(147, 'LOGIN_ERR_REGFAILED', 'en', 'Registration failed'),
(148, 'LOGIN_ERR_BADSECURE', 'en', 'You did not answer the security question correctly, please check your answer and try again.'),
(149, 'LOGIN_ERR_BADEMAIL', 'en', 'The specified email address does not appear to be valid.'),
(150, 'LOGIN_ERR_USERINUSE', 'en', 'The specified username is already in use. If you can''t remember your password, <strong>please use the <a href="***url-recover***">account recovery</a> facility</strong> rather than attempt to make a new account.'),
(151, 'LOGIN_ERR_EMAILINUSE', 'en', 'The specified email address is already in use. If you can''t remember your username or password, <strong>please use the <a href="***url-recover***">account recovery</a> facility</strong> rather than attempt to make a new account.'),
(152, 'LOGIN_ERR_INACTIVE', 'en', 'Your account is currently inactive. Please check your email for an ''Activation Required'' email and follow the link it contains to activate your account. If you have not received an actication email, or need a new one, <a href="***url-resend***">request a new activation email</a>.'),
(153, 'LOGIN_REG_DONETITLE', 'en', 'Registration successful'),
(154, 'LOGIN_REG_SUMMARY', 'en', 'Activation required!'),
(155, 'LOGIN_REG_LONGDESC', 'en', 'A new user account has been created for you, and an email has been sent to you with your new account password and an activation link.<br /><br />Please check your email for a message with the subject ''{V_[sitename]} account created - Activation required!'' and follow the instructions it contains to activate your account.'),
(156, 'LOGIN_REG_SUBJECT', 'en', '{V_[sitename]} account created - Activation required!'),
(157, 'LOGIN_REG_GREETING', 'en', 'Hi ***username***'),
(158, 'LOGIN_REG_CREATED', 'en', 'A new account in the {V_[sitename]} system has just been created for you. Your username and password for the system are given below.'),
(159, 'LOGIN_REG_ACTNEEDED', 'en', 'Before you can log in, you must activate your account. To activate your account, please click on the following link, or copy and paste it into your web browser:'),
(160, 'LOGIN_REG_ALTACT', 'en', 'Alternatively, enter the following code in the account activation form:'),
(161, 'LOGIN_REG_ENJOY', 'en', 'Thank you for registering!'),
(162, 'LOGIN_ACTCODE', 'en', 'Activation code'),
(163, 'LOGIN_ACTFAILED', 'en', 'User account activation failed'),
(164, 'LOGIN_ACTFORM', 'en', 'Activate account'),
(165, 'LOGIN_ACTINTRO', 'en', 'Please enter your 64 character activation code here.'),
(166, 'LOGIN_ACTIVATE', 'en', 'Activate account'),
(167, 'LOGIN_ERR_BADACTCHAR', 'en', 'Activation codes may only contain alphanumeric characters.'),
(168, 'LOGIN_ERR_BADCODE', 'en', 'The provided activation code is invalid: either your account is already active, or you entered the code incorrectly. Note that the code is case sensitive - upper and lower case characters are treated differently. Please check you entered the code correctly.'),
(169, 'LOGIN_ACT_DONETITLE', 'en', 'Account activated'),
(170, 'LOGIN_ACT_SUMMARY', 'en', 'Activation successful!'),
(171, 'LOGIN_ACT_LONGDESC', 'en', 'Your new account has been acivated, and you can now <a href="***url-login***">log in</a> using your username and the password emailed to you.'),
(172, 'LOGIN_RECFORM', 'en', 'Recover account details'),
(173, 'LOGIN_RECINTRO', 'en', 'If you have forgotten your username or password, enter the email address associated with your account in the field below. An email will be sent to you containing your username, and a link to click on to reset your password. If you do not have access to the email address associated with your account, please contact the site owner.'),
(174, 'LOGIN_RECEMAIL', 'en', 'Email address'),
(175, 'LOGIN_DORECOVER', 'en', 'Recover account'),
(176, 'LOGIN_RECOVER_SUBJECT', 'en', 'Your {V_[sitename]} account'),
(177, 'LOGIN_RECOVER_GREET', 'en', 'Hi ***username***'),
(178, 'LOGIN_RECOVER_INTRO', 'en', 'You, or someone pretending to be you, has requested that your password be reset. In order to reset your account, please click on the following link, or copy and paste it into your web browser.'),
(179, 'LOGIN_RECOVER_IGNORE', 'en', 'If you did not request this reset, please either ignore this email or report it to the {V_[sitename]} administrator.'),
(180, 'LOGIN_RECOVER_FAILED', 'en', 'Account recovery failed'),
(181, 'LOGIN_RECOVER_DONETITLE', 'en', 'Account recovery code sent'),
(182, 'LOGIN_RECOVER_SUMMARY', 'en', 'Recovery code sent!'),
(183, 'LOGIN_RECOVER_LONGDESC', 'en', 'An account recovery code has been send to your email address.<br /><br />Please check your email for a message with the subject ''Your {V_[sitename]} account'' and follow the instructions it contains.'),
(184, 'LOGIN_ERR_NOUID', 'en', 'No user id specified.'),
(185, 'LOGIN_ERR_BADUID', 'en', 'The specfied user id is not valid.'),
(186, 'LOGIN_ERR_BADRECCHAR', 'en', 'Account reset codes may only contain alphanumeric characters.'),
(187, 'LOGIN_ERR_BADRECCODE', 'en', 'The provided account reset code is invalid. Note that the code is case sensitive - upper and lower case characters are treated differently. Please check you entered the code correctly.'),
(188, 'LOGIN_ERR_NORECINACT', 'en', 'Your account is inactive, and therefore can not be recovered. In order to access your account, please request a new activation code and password.'),
(189, 'LOGIN_RESET_SUBJECT', 'en', 'Your {V_[sitename]} account'),
(190, 'LOGIN_RESET_GREET', 'en', 'Hi ***username***'),
(191, 'LOGIN_RESET_INTRO', 'en', 'Your password has been reset, and your username and new password are given below:'),
(192, 'LOGIN_RESET_LOGIN', 'en', 'To log into the {V_[sitename]}, please go to the following form and enter the username and password above. Once you have logged in, please change your password.'),
(193, 'LOGIN_RESET_DONETITLE', 'en', 'Account reset complete'),
(194, 'LOGIN_RESET_SUMMARY', 'en', 'Password reset successfully'),
(195, 'LOGIN_RESET_LONGDESC', 'en', 'Your username and a new password have been sent to your email address. Please look for an email with the subject ''Your {V_[sitename]} account'', you can use the account information it contains to log into the system by clicking the ''Log in'' button below.'),
(196, 'LOGIN_RESET_ERRTITLE', 'en', 'Account reset failed'),
(197, 'LOGIN_RESET_ERRSUMMARY', 'en', 'Password reset failed'),
(198, 'LOGIN_RESET_ERRDESC', 'en', 'The system has been unable to reset your account. The error encountered was:<br /><br/>***reason***'),
(199, 'LOGIN_RESENDFORM', 'en', 'Resend activation code'),
(200, 'LOGIN_RESENDINTRO', 'en', 'If you have accidentally deleted your activation email, or you have not received an an activation email more than 30 minutes after creating an account, enter your account email address below to be sent your activation code again.<br /><br/><strong>IMPORTANT</strong>: requesting a new copy of your activation code will also reset your password. If you later receive the original registration email, the code and password it contains will not work and should be ignored.'),
(201, 'LOGIN_RESENDEMAIL', 'en', 'Email address'),
(202, 'LOGIN_DORESEND', 'en', 'Resend code'),
(203, 'LOGIN_ERR_BADUSER', 'en', 'The email address provided does not appear to belong to any account in the system.'),
(204, 'LOGIN_ERR_BADAUTH', 'en', 'The user account with the provided email address does not have a valid authentication method associated with it. This should not happen!'),
(205, 'LOGIN_ERR_ALREADYACT', 'en', 'The user account with the provided email address is already active, and does not need a code to be activated.'),
(206, 'LOGIN_RESEND_SUBJECT', 'en', 'Your {V_[sitename]} activation code'),
(207, 'LOGIN_RESEND_GREET', 'en', 'Hi ***username***'),
(208, 'LOGIN_RESEND_INTRO', 'en', 'You, or someone pretending to be you, has requested that another copy of your activation code be sent to your email address.'),
(209, 'LOGIN_RESEND_ALTACT', 'en', 'Alternatively, enter the following code in the account activation form:'),
(210, 'LOGIN_RESEND_ENJOY', 'en', 'Thank you for registering!'),
(211, 'LOGIN_RESEND_FAILED', 'en', 'Activation code resend failed'),
(212, 'LOGIN_RESEND_DONETITLE', 'en', 'Activation code resent'),
(213, 'LOGIN_RESEND_SUMMARY', 'en', 'Resend successful!'),
(214, 'LOGIN_RESEND_LONGDESC', 'en', 'A new password and an activation link have been send to your email address.<br /><br />Please check your email for a message with the subject ''Your {V_[sitename]} activation code'' and follow the instructions it contains to activate your account.'),
(215, 'LOGIN_PASSCHANGE', 'en', 'Change password'),
(216, 'LOGIN_FORCECHANGE_INTRO', 'en', 'Before you continue, please choose a new password to set for your account.'),
(217, 'LOGIN_FORCECHANGE_TEMP', 'en', 'Your account is currently set up with a temporary password.'),
(218, 'LOGIN_FORCECHANGE_OLD', 'en', 'The password on your account has expired as a result of age limits enforced by the site''s password policy.'),
(219, 'LOGIN_NEWPASSWORD', 'en', 'New password'),
(220, 'LOGIN_CONFPASS', 'en', 'Confirm password'),
(221, 'LOGIN_OLDPASS', 'en', 'Your current password'),
(222, 'LOGIN_SETPASS', 'en', 'Change password'),
(223, 'LOGIN_PASSCHANGE_FAILED', 'en', 'Password change failed'),
(224, 'LOGIN_PASSCHANGE_ERRNOUSER', 'en', 'No logged in user detected, password change unsupported.'),
(225, 'LOGIN_PASSCHANGE_ERRMATCH', 'en', 'The new password specified does not match the confirm password.'),
(226, 'LOGIN_PASSCHANGE_ERRSAME', 'en', 'The new password can not be the same as the old password.'),
(227, 'LOGIN_PASSCHANGE_ERRVALID', 'en', 'The specified old password is not correct. You must enter the password you used to log in.'),
(228, 'LOGIN_POLICY', 'en', 'Password policy'),
(229, 'LOGIN_POLICY_INTRO', 'en', 'When choosing a new password, keep in mind that:'),
(230, 'LOGIN_POLICY_NONE', 'en', 'No password policy is currently in place, you may use any password you want.'),
(231, 'LOGIN_POLICY_MIN_LENGTH', 'en', 'Minimum length is ***value*** characters.'),
(232, 'LOGIN_POLICY_MIN_LOWERCASE', 'en', 'At least ***value*** lowercase letters are needed.'),
(233, 'LOGIN_POLICY_MIN_UPPERCASE', 'en', 'At least ***value*** uppercase letters are needed.'),
(234, 'LOGIN_POLICY_MIN_DIGITS', 'en', 'At least ***value*** numbers must be included.'),
(235, 'LOGIN_POLICY_MIN_OTHER', 'en', '***value*** non-alphanumeric chars are needed.'),
(236, 'LOGIN_POLICY_MIN_ENTROPY', 'en', 'Passwords must pass a strength check.'),
(237, 'LOGIN_POLICY_USE_CRACKLIB', 'en', 'Cracklib is used to test passwords.'),
(238, 'LOGIN_POLICY_MIN_LENGTHERR', 'en', 'Password is only ***set*** characters, minimum is ***require***.'),
(239, 'LOGIN_POLICY_MIN_LOWERCASEERR', 'en', 'Only ***set*** of ***require*** lowercase letters provided.'),
(240, 'LOGIN_POLICY_MIN_UPPERCASEERR', 'en', 'Only ***set*** of ***require*** uppercase letters provided.'),
(241, 'LOGIN_POLICY_MIN_DIGITSERRR', 'en', 'Only ***set*** of ***require*** digits included.'),
(242, 'LOGIN_POLICY_MIN_OTHERERR', 'en', 'Only ***set*** of ***require*** non-alphanumeric chars included.'),
(243, 'LOGIN_POLICY_MIN_ENTROPYERR', 'en', 'The supplied password is not strong enough.'),
(244, 'LOGIN_POLICY_USE_CRACKLIBERR', 'en', '***set***'),
(245, 'LOGIN_POLICY_MAX_PASSWORDAGE', 'en', 'Passwords must be changed after ***value*** days.'),
(246, 'LOGIN_POLICY_MAX_LOGINFAIL', 'en', 'You can log in incorrectly ***value*** times before your account needs reactivation.'),
(247, 'LOGIN_CRACKLIB_WAYSHORT', 'en', 'The password is far too short.'),
(248, 'LOGIN_CRACKLIB_TOOSHORT', 'en', 'The password is too short.'),
(249, 'LOGIN_CRACKLIB_MORECHARS', 'en', 'A greater range of characters are needed in the password.'),
(250, 'LOGIN_CRACKLIB_WHITESPACE', 'en', 'Passwords can not be entirely whitespace!'),
(251, 'LOGIN_CRACKLIB_SIMPLISTIC', 'en', 'The password is too simplistic or systematic.'),
(252, 'LOGIN_CRACKLIB_NINUMBER', 'en', 'You can not use a NI number as a password.'),
(253, 'LOGIN_CRACKLIB_DICTWORD', 'en', 'The password is based on a dictionary word.'),
(254, 'LOGIN_CRACKLIB_DICTBACK', 'en', 'The password is based on a reversed dictionary word.'),
(255, 'LOGIN_FAILLIMIT', 'en', 'You have used ***failcount*** of ***faillimit*** login attempts. If you exceed the limit, your account will be deactivated. If you can not remember your account details, please use the <a href="***url-recover***">account recovery form</a>'),
(256, 'LOGIN_LOCKEDOUT', 'en', 'You have exceeded the number of login failures permitted by the system, and your account has been deactivated. An email has been sent to the address associated with your account explaining how to reactivate your account.'),
(257, 'LOGIN_LOCKOUT_SUBJECT', 'en', '{V_[sitename]} account locked'),
(258, 'LOGIN_LOCKOUT_GREETING', 'en', 'Hi'),
(259, 'LOGIN_LOCKOUT_MESSAGE', 'en', 'Your ''{V_[sitename]}'' account has deactivated and your password has been changed because more than ***faillimit*** login failures have been recorded for your account. This may be the result of attempted unauthorised access to your account - if you are not responsible for these login attempts you should probably contact the site administator to report that your account may be under attack. Your username and new password for the site are:'),
(260, 'LOGIN_LOCKOUT_ACTNEEDED', 'en', 'As your account has been deactivated, before you can successfully log in you will need to reactivate your account. To do this, please click on the following link, or copy and paste it into your web browser:'),
(261, 'LOGIN_LOCKOUT_ALTACT', 'en', 'Alternatively, enter the following code in the account activation form:'),
(262, 'DEBUG_TIMEUSED', 'en', 'Execution time'),
(263, 'DEBUG_SECONDS', 'en', 'seconds'),
(264, 'DEBUG_USER', 'en', 'User time'),
(265, 'DEBUG_SYSTEM', 'en', 'System time'),
(266, 'DEBUG_MEMORY', 'en', 'Memory used'),
(267, 'BLOCK_VALIDATE_NOTSET', 'en', 'No value provided for ''***field***'', this field is required.'),
(268, 'BLOCK_VALIDATE_TOOLONG', 'en', 'The value provided for ''***field***'' is too long. No more than ***maxlen*** characters can be provided for this field.'),
(269, 'BLOCK_VALIDATE_BADCHARS', 'en', 'The value provided for ''***field***'' contains illegal characters. ***desc***'),
(270, 'BLOCK_VALIDATE_BADFORMAT', 'en', 'The value provided for ''***field***'' is not valid. ***desc***'),
(271, 'BLOCK_VALIDATE_DBERR', 'en', 'Unable to look up the value for ''***field***'' in the database. Error was: ***dberr***.'),
(272, 'BLOCK_VALIDATE_BADOPT', 'en', 'The value selected for ''***field***'' is not a valid option.'),
(273, 'BLOCK_VALIDATE_SCRUBFAIL', 'en', 'No content was left after cleaning the contents of html field ''***field***''.'),
(274, 'BLOCK_VALIDATE_TIDYFAIL', 'en', 'htmltidy failed for field ''***field***''.'),
(275, 'BLOCK_VALIDATE_CHKERRS', 'en', '***error*** html errors where encountered while validating ''***field***''. Clean up the html and try again.'),
(276, 'BLOCK_VALIDATE_CHKFAIL', 'en', 'Validation of ''***field***'' failed. Error from the W3C validator was: ***error***.'),
(277, 'BLOCK_VALIDATE_NOTNUMBER', 'en', 'The value provided for ''***field***'' is not a valid number.'),
(278, 'BLOCK_VALIDATE_RANGEMIN', 'en', 'The value provided for ''***field***'' is out of range (minimum is ***min***)'),
(279, 'BLOCK_VALIDATE_RANGEMAX', 'en', 'The value provided for ''***field***'' is out of range (maximum is ***max***)'),
(280, 'BLOCK_ERROR_TITLE', 'en', 'Fatal System Error'),
(281, 'BLOCK_ERROR_SUMMARY', 'en', 'The system has encountered an unrecoverable error.'),
(282, 'BLOCK_ERROR_TEXT', 'en', 'A serious error has been encountered while processing your request. The following information was generated by the system, please contact moodlesupport@cs.man.ac.uk about this, including this error and a description of what you were doing when it happened!<br /><br /><span class="error">***error***</span>');

-- --------------------------------------------------------

--
-- Table structure for table `log`
--

CREATE TABLE IF NOT EXISTS `log` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `logtime` int(10) unsigned NOT NULL COMMENT 'The time the logged event happened at',
  `user_id` int(10) unsigned DEFAULT NULL COMMENT 'The id of the user who triggered the event, if any',
  `ipaddr` varchar(16) DEFAULT NULL COMMENT 'The IP address the event was triggered from',
  `logtype` varchar(64) NOT NULL COMMENT 'The event type',
  `logdata` text COMMENT 'Any data that might be appropriate to log for this event',
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Stores a log of events in the system.' AUTO_INCREMENT=1 ;

-- --------------------------------------------------------

--
-- Table structure for table `messages_queue`
--

CREATE TABLE IF NOT EXISTS `messages_queue` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `previous_id` int(10) unsigned DEFAULT NULL COMMENT 'Link to a previous message (for replies/followups/etc)',
  `created` int(10) unsigned NOT NULL COMMENT 'The unix timestamp of when this message was created',
  `creator_id` int(10) unsigned DEFAULT NULL COMMENT 'Who created this message (NULL = system)',
  `deleted` int(10) unsigned DEFAULT NULL COMMENT 'Timestamp of message deletion, marks deletion of /sending/ message.',
  `deleted_id` int(10) unsigned DEFAULT NULL COMMENT 'Who deleted the message?',
  `message_ident` varchar(128) COLLATE utf8_unicode_ci DEFAULT NULL COMMENT 'Generic identifier, may be used for message lookup after addition',
  `subject` varchar(255) COLLATE utf8_unicode_ci NOT NULL COMMENT 'The message subject',
  `body` text COLLATE utf8_unicode_ci NOT NULL COMMENT 'The message body',
  `format` enum('text','html') COLLATE utf8_unicode_ci NOT NULL DEFAULT 'text' COMMENT 'Message format, for possible extension',
  `send_after` int(10) unsigned DEFAULT NULL COMMENT 'Send message after this time (NULL = as soon as possible)',
  PRIMARY KEY (`id`),
  KEY `created` (`created`),
  KEY `deleted` (`deleted`),
  KEY `message_ident` (`message_ident`),
  KEY `previous_id` (`previous_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci COMMENT='Stores messages to be sent through Message:: modules' AUTO_INCREMENT=1 ;

-- --------------------------------------------------------

--
-- Table structure for table `messages_recipients`
--

CREATE TABLE IF NOT EXISTS `messages_recipients` (
  `message_id` int(10) unsigned NOT NULL COMMENT 'ID of the message this is a recipient entry for',
  `recipient_id` int(10) unsigned NOT NULL COMMENT 'ID of the user sho should get the email',
  `viewed` int(10) unsigned DEFAULT NULL COMMENT 'When did the recipient view this message (if at all)',
  `deleted` int(10) unsigned DEFAULT NULL COMMENT 'When did the recipient mark their view as deleted (if at all)',
  KEY `email_id` (`message_id`),
  KEY `recipient_id` (`recipient_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Stores the recipients of messages';

-- --------------------------------------------------------

--
-- Table structure for table `messages_sender`
--

CREATE TABLE IF NOT EXISTS `messages_sender` (
  `message_id` int(10) unsigned NOT NULL COMMENT 'ID of the message this is a sender record for',
  `sender_id` int(10) unsigned NOT NULL COMMENT 'ID of the user who sent the message',
  `deleted` int(10) unsigned NOT NULL COMMENT 'Has the sender deleted this message from their list (DOES NOT DELETE THE MESSAGE!)',
  KEY `message_id` (`message_id`),
  KEY `sender_id` (`sender_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Stores the sender of each message, and sender-specific infor';

-- --------------------------------------------------------

--
-- Table structure for table `messages_transports`
--

CREATE TABLE IF NOT EXISTS `messages_transports` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(24) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL COMMENT 'The transport name',
  `description` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL COMMENT 'Human readable description (or langvar name)',
  `perl_module` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL COMMENT 'The perl module implementing the message transport.',
  `enabled` tinyint(1) NOT NULL COMMENT 'Is the transport enabled?',
  PRIMARY KEY (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COMMENT='Stores the list of modules that provide message delivery' AUTO_INCREMENT=3 ;

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
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `message_id` int(10) unsigned NOT NULL COMMENT 'The ID of the message this is a transport entry for',
  `transport_id` int(10) unsigned NOT NULL COMMENT 'The ID of the transport',
  `status_time` int(10) unsigned NOT NULL COMMENT 'The time the status was changed',
  `status` enum('pending','sent','failed') CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL DEFAULT 'pending' COMMENT 'The transport status',
  `status_message` text COMMENT 'human-readable status message (usually error messages)',
  PRIMARY KEY (`id`),
  KEY `message_id` (`message_id`),
  KEY `transport_id` (`transport_id`),
  KEY `status` (`status`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Stores transport status information for messages' AUTO_INCREMENT=1 ;

-- --------------------------------------------------------

--
-- Table structure for table `messages_transports_userctrl`
--

CREATE TABLE IF NOT EXISTS `messages_transports_userctrl` (
  `transport_id` int(10) unsigned NOT NULL COMMENT 'ID of the transport the user has set a control on',
  `user_id` int(10) unsigned NOT NULL COMMENT 'User setting the control',
  `enabled` tinyint(1) unsigned NOT NULL DEFAULT '1' COMMENT 'contact the user through this transport?',
  KEY `transport_id` (`transport_id`),
  KEY `user_id` (`user_id`),
  KEY `transport_user` (`transport_id`,`user_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Allows users to explicitly enable, or disable, specific mess';

-- --------------------------------------------------------

--
-- Table structure for table `modules`
--

CREATE TABLE IF NOT EXISTS `modules` (
  `module_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Unique module id',
  `name` varchar(80) NOT NULL COMMENT 'Short name for the module',
  `perl_module` varchar(128) NOT NULL COMMENT 'Name of the perl module in blocks/ (no .pm extension!)',
  `active` tinyint(1) unsigned NOT NULL COMMENT 'Is this module enabled?',
  PRIMARY KEY (`module_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COMMENT='Available site modules, perl module names, and status' AUTO_INCREMENT=7 ;

--
-- Dumping data for table `modules`
--

INSERT INTO `modules` (`module_id`, `name`, `perl_module`, `active`) VALUES
(1, 'compose', 'Newsagent::Article::Compose', 1),
(2, 'login', 'Newsagent::Login', 1),
(3, 'rss', 'Newsagent::Feed::RSS', 1),
(4, 'html', 'Newsagent::Feed::HTML', 1),
(5, 'articles', 'Newsagent::Article::List', 1),
(6, 'edit', 'Newsagent::Article::Edit', 1);

-- --------------------------------------------------------

--
-- Table structure for table `news_articles`
--

CREATE TABLE IF NOT EXISTS `news_articles` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `previous_id` int(10) unsigned DEFAULT NULL COMMENT 'Previous revision of the article',
  `metadata_id` int(10) unsigned NOT NULL COMMENT 'The ID of the metadata context associated with this article',
  `creator_id` int(10) unsigned NOT NULL COMMENT 'ID of the user who created the article',
  `created` int(10) unsigned NOT NULL COMMENT 'Unix timestamp of the creation date',
  `site_id` int(10) unsigned NOT NULL COMMENT 'ID of the site this is posted on behalf of',
  `title` varchar(100) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `summary` varchar(240) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL,
  `article` text CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL,
  `release_mode` enum('hidden','visible','timed','draft','edited','deleted') CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL DEFAULT 'visible',
  `release_time` int(10) unsigned DEFAULT NULL COMMENT 'Unix timestamp at which to release this article',
  `updated` int(10) unsigned NOT NULL COMMENT 'the last update time for this article',
  `updated_id` int(10) unsigned NOT NULL COMMENT 'Who updated the article last?',
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Stores articles' AUTO_INCREMENT=1 ;

-- --------------------------------------------------------

--
-- Table structure for table `news_article_images`
--

CREATE TABLE IF NOT EXISTS `news_article_images` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `article_id` int(10) unsigned NOT NULL COMMENT 'The ID of the article this is a relation for',
  `image_id` int(10) unsigned NOT NULL COMMENT 'The ID of the iamge to associate with the article',
  `order` tinyint(3) unsigned NOT NULL COMMENT 'The position of this image in the article''s list (1=leader, 2=foot, etc)',
  PRIMARY KEY (`id`),
  KEY `article_id` (`article_id`),
  KEY `order` (`order`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Allows images to be attached to articles' AUTO_INCREMENT=1 ;

-- --------------------------------------------------------

--
-- Table structure for table `news_article_levels`
--

CREATE TABLE IF NOT EXISTS `news_article_levels` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `article_id` int(10) unsigned NOT NULL COMMENT 'The ID of the article this is a relation for',
  `level_id` int(10) unsigned NOT NULL COMMENT 'The ID of the level to associate with the article',
  PRIMARY KEY (`id`),
  KEY `article_id` (`article_id`),
  KEY `level_id` (`level_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Allows levels to be attached to articles' AUTO_INCREMENT=1 ;

-- --------------------------------------------------------

--
-- Table structure for table `news_images`
--

CREATE TABLE IF NOT EXISTS `news_images` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `type` enum('url','file') CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL DEFAULT 'file' COMMENT 'Is this image a remote (url) image, or local (file)?',
  `md5` char(32) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL COMMENT 'The MD5 sum of the file',
  `name` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL COMMENT 'The name of the image (primarily for sorting)',
  `location` text NOT NULL,
  PRIMARY KEY (`id`),
  KEY `type` (`type`),
  KEY `name` (`name`),
  KEY `md5` (`md5`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Stores the locations of images used by articles' AUTO_INCREMENT=1 ;

-- --------------------------------------------------------

--
-- Table structure for table `news_levels`
--

CREATE TABLE IF NOT EXISTS `news_levels` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `level` varchar(24) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL COMMENT 'The title of the article level',
  `description` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL COMMENT 'A longer human-readable description',
  `capability` varchar(80) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL COMMENT 'The capability the user must have to post at this level',
  PRIMARY KEY (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COMMENT='Stores the article importance levels' AUTO_INCREMENT=4 ;

--
-- Dumping data for table `news_levels`
--

INSERT INTO `news_levels` (`id`, `level`, `description`, `capability`) VALUES
(1, 'home', 'Important (School Home Page)', 'author_home'),
(2, 'leader', 'Medium (Section Leader Page)', 'author_leader'),
(3, 'group', 'Everything (Group Page)', 'author');

-- --------------------------------------------------------

--
-- Table structure for table `news_metadata`
--

CREATE TABLE IF NOT EXISTS `news_metadata` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'id of this metadata context',
  `parent_id` int(10) unsigned DEFAULT NULL COMMENT 'id of this metadata context''s parent',
  `refcount` int(10) unsigned NOT NULL DEFAULT '0' COMMENT 'How many Thingies are currently attached to this metadata context?',
  PRIMARY KEY (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COMMENT='Stores metadata context heirarchies' AUTO_INCREMENT=2 ;

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
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `metadata_id` int(10) unsigned NOT NULL COMMENT 'ID of the metadata context this is a default role for',
  `role_id` int(10) unsigned NOT NULL COMMENT 'ID of the role to make the default in this context',
  `priority` tinyint(3) unsigned DEFAULT NULL COMMENT 'Role priority, overrides the priority normally set for the role if set.',
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci COMMENT='Stores default role data for metadata contexts' AUTO_INCREMENT=1 ;

-- --------------------------------------------------------

--
-- Table structure for table `news_metadata_roles`
--

CREATE TABLE IF NOT EXISTS `news_metadata_roles` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Relation id',
  `metadata_id` int(10) unsigned NOT NULL COMMENT 'ID of the metadata context this role is attached to',
  `role_id` int(10) unsigned NOT NULL COMMENT 'The id of the role attached to the context',
  `user_id` int(10) unsigned NOT NULL COMMENT 'The ID of the user being given the role in the metadata context',
  `source_id` int(10) unsigned DEFAULT NULL COMMENT 'The ID of the enrolment method that added this role',
  `group_id` int(10) unsigned DEFAULT NULL COMMENT 'Optional group id associated with this role assignment',
  `attached` int(10) unsigned NOT NULL COMMENT 'Date on which this role was attached to the metadata context',
  `touched` int(10) unsigned NOT NULL COMMENT 'The time this role assignment was last renewed or updated',
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Stores role assignments in metadata contexts' AUTO_INCREMENT=1 ;

-- --------------------------------------------------------

--
-- Table structure for table `news_metadata_tags`
--

CREATE TABLE IF NOT EXISTS `news_metadata_tags` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Relation id',
  `metadata_id` int(10) unsigned NOT NULL COMMENT 'ID of the metadata context the tag is attached to',
  `tag_id` int(10) unsigned NOT NULL COMMENT 'ID of the tag attached to the metadata context',
  `attached_by` int(10) unsigned NOT NULL COMMENT 'User ID of the user who attached the tag',
  `attached_date` int(10) unsigned NOT NULL COMMENT 'Date the tag was attached on',
  `rating` smallint(6) NOT NULL DEFAULT '0' COMMENT 'Tag rating',
  PRIMARY KEY (`id`),
  KEY `tag_id` (`tag_id`),
  KEY `metadata_id` (`metadata_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 AUTO_INCREMENT=1 ;

-- --------------------------------------------------------

--
-- Table structure for table `news_metadata_tags_log`
--

CREATE TABLE IF NOT EXISTS `news_metadata_tags_log` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'History ID',
  `metadata_id` int(10) unsigned NOT NULL COMMENT 'The id of the metadata context this event happened in',
  `tag_id` int(10) unsigned NOT NULL COMMENT 'The id if the tag being acted on',
  `event` enum('added','deleted','rate up','rate down','activate','deactivate') NOT NULL COMMENT 'What did the user do',
  `event_user` int(10) unsigned NOT NULL COMMENT 'ID of the user who did something',
  `event_time` int(10) unsigned NOT NULL COMMENT 'Timestamp of the event',
  `rating` smallint(6) NOT NULL COMMENT 'Rating set for the tag after the event',
  PRIMARY KEY (`id`),
  KEY `event_time` (`event_time`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Stores the history of tagging actions in a metadata context' AUTO_INCREMENT=1 ;

-- --------------------------------------------------------

--
-- Table structure for table `news_roles`
--

CREATE TABLE IF NOT EXISTS `news_roles` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT 'Unique ID for each role',
  `role_name` varchar(80) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL COMMENT 'The human-readable name of the role',
  `priority` tinyint(3) unsigned NOT NULL DEFAULT '0' COMMENT 'Role priority level, lower level means lower priority, higher priority overrides lower settings',
  PRIMARY KEY (`id`),
  KEY `role_name` (`role_name`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COMMENT='Stores role ids and the names associated with those ids.' AUTO_INCREMENT=8 ;

--
-- Dumping data for table `news_roles`
--

INSERT INTO `news_roles` (`id`, `role_name`, `priority`) VALUES
(1, 'global_admin', 127),
(2, 'site_admin', 64),
(3, 'editor', 32),
(4, 'user', 0),
(5, 'author', 0),
(6, 'author_leader', 0),
(7, 'author_home', 0);

-- --------------------------------------------------------

--
-- Table structure for table `news_role_capabilities`
--

CREATE TABLE IF NOT EXISTS `news_role_capabilities` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Unique role/capability ID',
  `role_id` int(10) unsigned NOT NULL COMMENT 'The ID of the role this is a capability for',
  `capability` varchar(80) COLLATE utf8_unicode_ci NOT NULL COMMENT 'The name of the capability to set on this role',
  `mode` enum('allow','deny') COLLATE utf8_unicode_ci NOT NULL DEFAULT 'allow' COMMENT 'Should the capability be allowed or denied?',
  PRIMARY KEY (`id`),
  KEY `role_id` (`role_id`),
  KEY `role_capability` (`role_id`,`capability`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci COMMENT='Stores the list of capabilities for each role' AUTO_INCREMENT=16 ;

--
-- Dumping data for table `news_role_capabilities`
--

INSERT INTO `news_role_capabilities` (`id`, `role_id`, `capability`, `mode`) VALUES
(1, 4, 'view', 'allow'),
(16, 2, 'author', 'allow'),
(3, 5, 'author', 'allow'),
(4, 6, 'author_leader', 'allow'),
(5, 7, 'author_home', 'allow'),
(6, 1, 'view', 'allow'),
(7, 1, 'compose', 'allow'),
(8, 1, 'author', 'allow'),
(9, 1, 'author_leader', 'allow'),
(10, 1, 'author_home', 'allow'),
(11, 4, 'listarticles', 'allow'),
(12, 1, 'listarticles', 'allow'),
(13, 1, 'edit', 'allow'),
(14, 2, 'edit', 'allow'),
(15, 3, 'edit', 'allow'),
(17, 2, 'author_leader', 'allow'),
(18, 2, 'author_home', 'allow');

-- --------------------------------------------------------

--
-- Table structure for table `news_sites`
--

CREATE TABLE IF NOT EXISTS `news_sites` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `metadata_id` int(10) unsigned NOT NULL DEFAULT '1' COMMENT 'ID of the metadata context associated with this site',
  `name` varchar(24) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL COMMENT 'The name of the site (usually subdomain name)',
  `default_url` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL COMMENT 'Site URL to use if not defined in news_sites_urls',
  `description` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL COMMENT 'Human readable site title',
  PRIMARY KEY (`id`),
  KEY `name` (`name`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 AUTO_INCREMENT=1 ;

-- --------------------------------------------------------

--
-- Table structure for table `news_sites_urls`
--

CREATE TABLE IF NOT EXISTS `news_sites_urls` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `site_id` int(10) unsigned NOT NULL COMMENT 'The ID of the site this is a url for',
  `level_id` int(10) unsigned NOT NULL COMMENT 'The lvel at which this URL should be used',
  `url` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL COMMENT 'The URL of the article reader for this site at this level',
  PRIMARY KEY (`id`),
  KEY `site_id` (`site_id`,`level_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Allows sites to have different URLs for article readers at d' AUTO_INCREMENT=1 ;

-- --------------------------------------------------------

--
-- Table structure for table `news_tags`
--

CREATE TABLE IF NOT EXISTS `news_tags` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(128) NOT NULL COMMENT 'The tag string',
  `creator_id` int(10) unsigned NOT NULL COMMENT 'User id of the tag creator',
  `created` int(10) unsigned NOT NULL COMMENT 'Date the tag was created',
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 AUTO_INCREMENT=1 ;

-- --------------------------------------------------------

--
-- Table structure for table `sessions`
--

CREATE TABLE IF NOT EXISTS `sessions` (
  `session_id` char(32) NOT NULL,
  `session_user_id` int(10) unsigned NOT NULL,
  `session_start` int(11) unsigned NOT NULL,
  `session_time` int(11) unsigned NOT NULL,
  `session_ip` varchar(40) NOT NULL,
  `session_autologin` tinyint(1) unsigned NOT NULL,
  PRIMARY KEY (`session_id`),
  KEY `session_time` (`session_time`),
  KEY `session_user_id` (`session_user_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Website sessions';

-- --------------------------------------------------------

--
-- Table structure for table `session_keys`
--

CREATE TABLE IF NOT EXISTS `session_keys` (
  `key_id` char(32) COLLATE utf8_bin NOT NULL DEFAULT '',
  `user_id` int(10) unsigned NOT NULL DEFAULT '0',
  `last_ip` varchar(40) COLLATE utf8_bin NOT NULL DEFAULT '',
  `last_login` int(11) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`key_id`,`user_id`),
  KEY `last_login` (`last_login`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_bin COMMENT='Autologin keys';

-- --------------------------------------------------------

--
-- Table structure for table `session_variables`
--

CREATE TABLE IF NOT EXISTS `session_variables` (
  `session_id` char(32) NOT NULL,
  `var_name` varchar(80) NOT NULL,
  `var_value` text NOT NULL,
  KEY `session_id` (`session_id`),
  KEY `sess_name_map` (`session_id`,`var_name`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Session-related variables';

-- --------------------------------------------------------

--
-- Table structure for table `settings`
--

CREATE TABLE IF NOT EXISTS `settings` (
  `name` varchar(255) COLLATE utf8_unicode_ci NOT NULL,
  `value` text COLLATE utf8_unicode_ci NOT NULL,
  PRIMARY KEY (`name`)
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
('default_block', 'compose'),
('Auth:allow_autologin', '1'),
('Auth:max_autologin_time', '30'),
('Auth:ip_check', '4'),
('Auth:session_length', '3600'),
('Auth:session_gc', '0'),
('Auth:unique_id', '2543'),
('Session:lastgc', '0'),
('Core:envelope_address', 'your@email.addy'),
('Log:all_the_things', '1'),
('timefmt', '%d %b %Y %H:%M:%S %Z'),
('datefmt', '%d %b %Y'),
('Core:admin_email', 'your@email.addy'),
('Message::Transport::Email::smtp_host', 'localhost'),
('Message::Transport::Email::smtp_port', '25'),
('Login:allow_self_register', '1'),
('Login:self_register_answer', 'orange'),
('Login:self_register_question', 'Which of these colours is also a fruit? Blue, orange, red'),
('site_name', 'Newsagent'),
('default_authmethod', '1'),
('Article:upload_image_path', '/path/to/store/images'),
('Article:upload_image_url', 'https://urlof/newsagent/images'),
('Feed:count', '10'),
('Feed:count_limit', '100'),
('RSS:editor', 'your@email.addy (Your Email)'),
('RSS:webmaster', 'your@email.addy (Your Email)'),
('RSS:title', 'Feed title'),
('RSS:description', 'The latest news and events'),
('Feed:default_level', 'group'),
('HTML:default_image', ''),
('Feed:max_age', '1y');

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE IF NOT EXISTS `users` (
  `user_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
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
  `last_login` int(10) unsigned NOT NULL COMMENT 'The unix time of th euser''s last login',
  PRIMARY KEY (`user_id`),
  UNIQUE KEY `username` (`username`),
  KEY `email` (`email`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COMMENT='Stores the local user data for each user in the system' AUTO_INCREMENT=2 ;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`user_id`, `user_auth`, `user_type`, `username`, `realname`, `password`, `password_set`, `force_change`, `fail_count`, `email`, `created`, `activated`, `act_code`, `last_login`) VALUES
(1, NULL, 0, 'anonymous', NULL, NULL, NULL, 0, 0, NULL, UNIX_TIMESTAMP(), UNIX_TIMESTAMP(), NULL, UNIX_TIMESTAMP());

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
