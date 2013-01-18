## @file
# This file contains the implementation of the login/logout facility.
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
# A 'stand alone' login implementation. This presents the user with a
# login form, checks the credentials they enter, and then redirects
# them back to the task they were performing that required a login.
package Newsagent::Login;

use strict;
use base qw(Newsagent); # This class extends the Newsagent block class
use Webperl::Utils qw(path_join is_defined_numeric);


# ============================================================================
#  Emailer functions

## @method $ send_reg_email($user, $password)
# Send a registration welcome message to the specified user. This send an email
# to the user including their username, password, and a link to the activation
# page for their account.
#
# @param user     A reference to a user record hash.
# @param password The unencrypted version of the password set for the user.
# @return undef on success, otherwise an error message.
sub send_reg_email {
    my $self     = shift;
    my $user     = shift;
    my $password = shift;

    my $acturl  = $self -> build_url("fullurl"  => 1,
                                     "block"    => "login",
                                     "itempath" => [],
                                     "params"   => "actcode=".$user -> {"act_code"});
    my $actform = $self -> build_url("fullurl"  => 1,
                                     "block"    => "login",
                                     "itempath" => [ "activate" ]);

    return $self -> {"template"} -> email_template("login/email_registered.tem",
                                                   {"***from***"     => $self -> {"settings"} -> {"config"} -> {"Core:admin_email"},
                                                    "***to***"       => $user -> {"email"},
                                                    "***subject***"  => $self -> {"template"} -> replace_langvar("LOGIN_REG_SUBJECT"),
                                                    "***username***" => $user -> {"username"},
                                                    "***password***" => $password,
                                                    "***act_code***" => $user -> {"act_code"},
                                                    "***act_url***"  => $acturl,
                                                    "***act_form***" => $actform,
                                                   });
}


## @method $ resend_act_email($user, $password)
# Send another copy of the user's activation code to their email address.
#
# @param user     A reference to a user record hash.
# @param password The unencrypted version of the password set for the user.
# @return undef on success, otherwise an error message.
sub resend_act_email {
    my $self     = shift;
    my $user     = shift;
    my $password = shift;

    my $acturl  = $self -> build_url("fullurl"  => 1,
                                     "block"    => "login",
                                     "itempath" => [],
                                     "params"   => "actcode=".$user -> {"act_code"});
    my $actform = $self -> build_url("fullurl"  => 1,
                                     "block"    => "login",
                                     "itempath" => [ "activate" ]);

    return $self -> {"template"} -> email_template("login/email_actcode.tem",
                                                   {"***from***"     => $self -> {"settings"} -> {"config"} -> {"Core:admin_email"},
                                                    "***to***"       => $user -> {"email"},
                                                    "***subject***"  => $self -> {"template"} -> replace_langvar("LOGIN_RESEND_SUBJECT"),
                                                    "***username***" => $user -> {"username"},
                                                    "***password***" => $password,
                                                    "***act_code***" => $user -> {"act_code"},
                                                    "***act_url***"  => $acturl,
                                                    "***act_form***" => $actform,
                                                   });
}


## @method $ recover_email$user, $actcode)
# Send a copy of the user's username and new actcode to their email address.
#
# @param user     A reference to a user record hash.
# @param actcode The unencrypted version of the actcode set for the user.
# @return undef on success, otherwise an error message.
sub recover_email {
    my $self    = shift;
    my $user    = shift;
    my $actcode = shift;

    my $reseturl = $self -> build_url("fullurl"  => 1,
                                      "block"    => "login",
                                      "params"   => { "uid"       => $user -> {"user_id"},
                                                      "resetcode" => $actcode},
                                      "joinstr"  => "&",
                                      "itempath" => []);

    return $self -> {"template"} -> email_template("login/email_recover.tem",
                                                   {"***from***"      => $self -> {"settings"} -> {"config"} -> {"Core:admin_email"},
                                                    "***to***"        => $user -> {"email"},
                                                    "***subject***"   => $self -> {"template"} -> replace_langvar("LOGIN_RECOVER_SUBJECT"),
                                                    "***username***"  => $user -> {"username"},
                                                    "***reset_url***" => $reseturl,
                                                   });
}


## @method $ reset_email($user, $password)
# Send the user's username and random reset password to them
#
# @param user     A reference to a user record hash.
# @param password The unencrypted version of the password set for the user.
# @return undef on success, otherwise an error message.
sub reset_email {
    my $self     = shift;
    my $user     = shift;
    my $password = shift;

    my $loginform = $self -> build_url("fullurl"  => 1,
                                       "block"    => "login",
                                       "itempath" => [ ]);

    return $self -> {"template"} -> email_template("login/email_reset.tem",
                                                   {"***from***"      => $self -> {"settings"} -> {"config"} -> {"Core:admin_email"},
                                                    "***to***"        => $user -> {"email"},
                                                    "***subject***"   => $self -> {"template"} -> replace_langvar("LOGIN_RESET_SUBJECT"),
                                                    "***username***"  => $user -> {"username"},
                                                    "***password***"  => $password,
                                                    "***login_url***" => $loginform,
                                                   });
}


# ============================================================================
#  Validation functions

## @method private @ validate_login()
# Determine whether the username and password provided by the user are valid. If
# they are, return the user's data.
#
# @return An array of two values: A reference to the user's data on success,
#         or an error string if the login failed, and a reference to a hash of
#         arguments that passed validation.
sub validate_login {
    my $self   = shift;
    my $error  = "";
    my $args   = {};

    # Check that the username is provided and valid
    ($args -> {"username"}, $error) = $self -> validate_string("username", {"required"   => 1,
                                                                            "nicename"   => $self -> {"template"} -> replace_langvar("LOGIN_USERNAME"),
                                                                            "minlen"     => 2,
                                                                            "maxlen"     => 32,
                                                                            "formattest" => '^[-\w]+$',
                                                                            "formatdesc" => $self -> {"template"} -> replace_langvar("LOGIN_ERR_BADUSERCHAR")});
    # Bomb out at this point if the username is not valid.
    return ($self -> {"template"} -> load_template("login/error.tem", {"***reason***" => $error}), $args)
        if($error);

    # Do the same with the password...
    ($args -> {"password"}, $error) = $self -> validate_string("password", {"required"   => 1,
                                                                            "nicename"   => $self -> {"template"} -> replace_langvar("LOGIN_PASSWORD"),
                                                                            "minlen"     => 2,
                                                                            "maxlen"     => 255});
    return ($self -> {"template"} -> load_template("login/error.tem", {"***reason***" => $error}), $args)
        if($error);

    # Username and password appear to be present and contain sane characters. Try to log the user in...
    my $user = $self -> {"session"} -> {"auth"} -> valid_user($args -> {"username"}, $args -> {"password"});

    # If the user is valid, is the account active?
    if($user) {
        # If the account is active, the user is good to go
        if($user -> {"activated"}) {
            return ($user, $args);
        } else {
            # Otherwise, send back the 'account needs activating' error
            return ($self -> {"template"} -> load_template("login/error.tem",
                                                           {"***reason***" => $self -> {"template"} -> replace_langvar("LOGIN_ERR_INACTIVE",
                                                                                                                       { "***url-resend***" => $self -> build_url("block" => "login", "itempath" => [ "resend" ]) })
                                                           }), $args);
        }
    }

    # User is valid!
    return ($user, $args) if($user);

    # User is not valid, does the auth's errstr contain anything?
    return ($self -> {"template"} -> load_template("login/error.tem", {"***reason***" => $self -> {"session"} -> auth_error()}), $args)
        if($self -> {"session"} -> auth_error());

    # Nothing useful, just return a fallback
    return ($self -> {"template"} -> load_template("login/error.tem", {"***reason***" => $self -> {"template"} -> replace_langvar("LOGIN_ERR_INVALID")}), $args);
}


## @method private @ validate_register()
# Determine whether the username, email, and security question provided by the user
# are valid. If they are, return true.
#
# @return The new user's record on success, an error string if the register failed.
sub validate_register {
    my $self   = shift;
    my $error  = "";
    my $errors = "";
    my $args   = {};

    # User attempted self-register when it is disabled? Naughty user, no cookie!
    return ($self -> {"template"} -> load_template("login/reg_error.tem", {"***reason***" => $self -> {"template"} -> replace_langvar("LOGIN_ERR_NOSELFREG")}), $args)
        unless($self -> {"settings"} -> {"config"} -> {"Newsagent::Login:allow_self_register"});

    # Check that the username is provided and valid
    ($args -> {"regname"}, $error) = $self -> validate_string("regname", {"required"   => 1,
                                                                          "nicename"   => $self -> {"template"} -> replace_langvar("LOGIN_USERNAME"),
                                                                          "minlen"     => 2,
                                                                          "maxlen"     => 32,
                                                                          "formattest" => '^[-\w]+$',
                                                                          "formatdesc" => $self -> {"template"} -> replace_langvar("LOGIN_ERR_BADUSERCHAR")
                                                              });
    # Is the username valid?
    if($error) {
        $errors .= $self -> {"template"} -> load_template("login/reg_error.tem", {"***reason***" => $error});
    } else {
        # Is the username in use?
        my $user = $self -> {"session"} -> get_user($args -> {"regname"});
        $errors .= $self -> {"template"} -> load_template("login/reg_error.tem",
                                                          {"***reason***" => $self -> {"template"} -> replace_langvar("LOGIN_ERR_USERINUSE",
                                                                                                                      { "***url-recover***" => $self -> build_url("block" => "login", "itempath" => [ "recover" ]) })
                                                          })
            if($user);
    }

    # And the email
    ($args -> {"email"}, $error) = $self -> validate_string("email", {"required"   => 1,
                                                                      "nicename"   => $self -> {"template"} -> replace_langvar("LOGIN_EMAIL"),
                                                                      "minlen"     => 2,
                                                                      "maxlen"     => 256
                                                            });
    if($error) {
        $errors .= $self -> {"template"} -> load_template("login/reg_error.tem", {"***reason***" => $error});
    } else {

        # Check that the address is structured in a vaguely valid way
        # Yes, this is not fully RFC compliant, but frankly going down that road invites a
        # level of utter madness that would make Azathoth himself utter "I say, steady on now..."
        $errors .= $self -> {"template"} -> load_template("login/reg_error.tem", {"***reason***" => $self -> {"template"} -> replace_langvar("LOGIN_ERR_BADEMAIL")})
            if($args -> {"email"} !~ /^[\w.+-]+\@([\w-]+\.)+\w+$/);

        # Is the email address in use?
        my $user = $self -> {"session"} -> {"auth"} -> {"app"} -> get_user_byemail($args -> {"email"});
        $errors .= $self -> {"template"} -> load_template("login/reg_error.tem", {"***reason***" => $self -> {"template"} -> replace_langvar("LOGIN_ERR_EMAILINUSE",
                                                                                                                                             { "***url-recover***" => $self -> build_url("block" => "login", "itempath" => [ "recover" ]) })
                                                          })
            if($user);
    }

    # Did the user get the 'Are you a human' question right?
    ($args -> {"answer"}, $error) = $self -> validate_string("answer", {"required"   => 1,
                                                                        "nicename"   => $self -> {"template"} -> replace_langvar("LOGIN_SECURITY"),
                                                                        "minlen"     => 2,
                                                                        "maxlen"     => 255,
                                                             });
    if($error) {
        $errors .= $self -> {"template"} -> load_template("login/reg_error.tem", {"***reason***" => $error});
    } else {
        $errors .= $self -> {"template"} -> load_template("login/reg_error.tem", {"***reason***" => $self -> {"template"} -> replace_langvar("LOGIN_ERR_BADSECURE")})
            unless(lc($args -> {"answer"}) eq lc($self -> {"settings"} -> {"config"} -> {"Newsagent::Login:self_register_answer"}));
    }

    # Halt here if there are any problems.
    return ($self -> {"template"} -> load_template("login/reg_errorlist.tem", {"***errors***" => $errors}), $args)
        if($errors);

    # Get here an the user's details are okay, register the new user.
    my $methodimpl = $self -> {"session"} -> {"auth"} -> get_authmethod_module($self -> {"settings"} -> {"config"} -> {"default_authmethod"})
        or return ($self -> {"template"} -> load_template("login/reg_errorlist.tem",
                                                          {"***errors***" => $self -> {"template"} -> load_template("login/reg_error.tem",
                                                                                                                    {"***reason***" => $self -> {"session"} -> {"auth"} -> errstr()}) }),
                   $args);

    my ($user, $password) = $methodimpl -> create_user($args -> {"regname"}, $self -> {"settings"} -> {"config"} -> {"default_authmethod"}, $args -> {"email"});
    return ($self -> {"template"} -> load_template("login/reg_errorlist.tem",
                                                   {"***errors***" => $self -> {"template"} -> load_template("login/reg_error.tem", {"***reason***" => $methodimpl -> errstr()}) }),
            $args)
        if(!$user);

    # Send registration email
    my $err = $self -> send_reg_email($user, $password);
    return ($err, $args) if($err);

    # User is registered...
    return ($user, $args);
}


## @method private @ validate_actcode()
# Determine whether the activation code provided by the user is valid
#
# @return An array of two values: the first is a reference to the activated
#         user's data hash on success, an error message otherwise; the
#         second is the args parsed from the activation data.
sub validate_actcode {
    my $self = shift;
    my $args = {};
    my $error;

    # Check that the code has been provided and contains allowed characters
    ($args -> {"actcode"}, $error) = $self -> validate_string("actcode", {"required"   => 1,
                                                                          "nicename"   => $self -> {"template"} -> replace_langvar("LOGIN_ACTCODE"),
                                                                          "minlen"     => 64,
                                                                          "maxlen"     => 64,
                                                                          "formattest" => '^[a-zA-Z0-9]+$',
                                                                          "formatdesc" => $self -> {"template"} -> replace_langvar("LOGIN_ERR_BADACTCHAR")});
    # Bomb out at this point if the code is not valid.
    return $self -> {"template"} -> load_template("login/act_error.tem", {"***reason***" => $error})
        if($error);

    # Act code is valid, can a user be activated?
    my $user = $self -> {"session"} -> {"auth"} -> activate_user($args -> {"actcode"});
    return ($self -> {"template"} -> load_template("login/act_error.tem", {"***reason***" => $self -> {"template"} -> replace_langvar("LOGIN_ERR_BADCODE")}), $args)
        unless($user);

    # User is active
    return ($user, $args);
}


## @method private @ validate_resend()
# Determine whether the email address the user entered is valid, and whether the
# the account needs to be (or can be) activated. If it is, generate a new password
# and activation code to send to the user.
#
# @return Two values: a reference to the user whose activation code has been send
#         on success, or an error message, and a reference to a hash containing
#         the data entered by the user.
sub validate_resend {
    my $self   = shift;
    my $args   = {};
    my $error;

    ($args -> {"email"}, $error) = $self -> validate_string("email", {"required"   => 1,
                                                                      "nicename"   => $self -> {"template"} -> replace_langvar("LOGIN_RESENDEMAIL"),
                                                                      "minlen"     => 2,
                                                                      "maxlen"     => 256
                                                            });
    return ($self -> {"template"} -> load_template("login/resend_error.tem", {"***reason***" => $error}), $args)
        if($error);

    # Does the email look remotely valid?
    return ($self -> {"template"} -> load_template("login/resend_error.tem", {"***reason***" => $self -> {"template"} -> replace_langvar("LOGIN_ERR_BADEMAIL")}), $args)
        if($args -> {"email"} !~ /^[\w.+-]+\@([\w-]+\.)+\w+$/);

    # Does the address correspond to an actual user?
    my $user = $self -> {"session"} -> {"auth"} -> {"app"} -> get_user_byemail($args -> {"email"});
    return ($self -> {"template"} -> load_template("login/resend_error.tem", {"***reason***" => $self -> {"template"} -> replace_langvar("LOGIN_ERR_BADUSER")}), $args)
        if(!$user);

    # Does the user's authmethod support activation anyway?
    return ($self -> {"template"} -> load_template("login/resend_error.tem", {"***reason***" => $self -> {"session"} -> {"auth"} -> noactivate_message($user -> {"username"})}), $args)
        if(!$self -> {"session"} -> {"auth"} -> require_activate($user -> {"username"}));

    # no point in resending an activation code to an active account
    return ($self -> {"template"} -> load_template("login/resend_error.tem", {"***reason***" => $self -> {"template"} -> replace_langvar("LOGIN_ERR_ALREADYACT")}), $args)
        if($self -> {"session"} -> {"auth"} -> activated($user -> {"username"}));

    my $newpass;
    ($newpass, $user -> {"act_code"}) = $self -> {"session"} -> {"auth"} -> reset_password_actcode($user -> {"username"});
    return ($self -> {"template"} -> load_template("login/resend_error.tem", {"***reason***" => $self -> {"session"} -> {"auth"} -> {"app"} -> errstr()}), $args)
        if(!$newpass);

    # Get here and the user's account isn't active, needs to be activated, and can be emailed a code...
    $self -> resend_act_email($user, $newpass);

    return($user, $args);
}


## @method private @ validate_recover()
# Determine whether the email address the user entered is valid, and if so generate
# an act code to start the reset process.
#
# @return Two values: a reference to the user whose reset code has been send
#         on success, or an error message, and a reference to a hash containing
#         the data entered by the user.
sub validate_recover {
    my $self   = shift;
    my $args   = {};
    my $error;

    ($args -> {"email"}, $error) = $self -> validate_string("email", {"required"   => 1,
                                                                      "nicename"   => $self -> {"template"} -> replace_langvar("LOGIN_RECOVER_EMAIL"),
                                                                      "minlen"     => 2,
                                                                      "maxlen"     => 256
                                                            });
    return ($self -> {"template"} -> load_template("login/recover_error.tem", {"***reason***" => $error}), $args)
        if($error);

    # Does the email look remotely valid?
    return ($self -> {"template"} -> load_template("login/recover_error.tem", {"***reason***" => $self -> {"template"} -> replace_langvar("LOGIN_ERR_BADEMAIL")}), $args)
        if($args -> {"email"} !~ /^[\w.+-]+\@([\w-]+\.)+\w+$/);

    # Does the address correspond to an actual user?
    my $user = $self -> {"session"} -> {"auth"} -> {"app"} -> get_user_byemail($args -> {"email"});
    return ($self -> {"template"} -> load_template("login/recover_error.tem", {"***reason***" => $self -> {"template"} -> replace_langvar("LOGIN_ERR_BADUSER")}), $args)
        if(!$user);

    # Users can not recover an inactive account - they need to get a new act code
    return ($self -> {"template"} -> load_template("login/recover_error.tem", {"***reason***" => $self -> {"template"} -> replace_langvar("LOGIN_ERR_NORECINACT")}), $args)
        if($self -> {"session"} -> {"auth"} -> require_activate($user -> {"username"}) &&
           !$self -> {"session"} -> {"auth"} -> activated($user -> {"username"}));

    # Does the user's authmethod support activation anyway?
    return ($self -> {"template"} -> load_template("login/recover_error.tem", {"***reason***" => $self -> {"session"} -> {"auth"} -> norecover_message($user -> {"username"})}), $args)
        if(!$self -> {"session"} -> {"auth"} -> supports_recovery($user -> {"username"}));

    my $newcode = $self -> {"session"} -> {"auth"} -> generate_actcode($user -> {"username"});
    return ($self -> {"template"} -> load_template("login/recover_error.tem", {"***reason***" => $self -> {"session"} -> {"auth"} -> {"app"} -> errstr()}), $args)
        if(!$newcode);

    # Get here and the user's account has been reset
    $self -> recover_email($user, $newcode);

    return($user, $args);
}


## @method private @ validate_reset()
# Pull the userid and activation code out of the submitted data, and determine
# whether they are valid (and that the user's authmethod allows for resets). If
# so, reset the user's password and send and email to them with the new details.
#
# @return Two values: a reference to the user whose password has been reset
#         on success, or an error message, and a reference to a hash containing
#         the data entered by the user.
sub validate_reset {
    my $self = shift;
    my $args   = {};
    my $error;

    my $uid = is_defined_numeric($self -> {"cgi"}, "uid")
        or return ($self -> {"template"} -> replace_langvar("LOGIN_ERR_NOUID"), $args);

    my $user = $self -> {"session"} -> {"auth"} -> {"app"} -> get_user_byid($uid)
        or return ($self -> {"template"} -> replace_langvar("LOGIN_ERR_BADUID"), $args);

    ($args -> {"resetcode"}, $error) = $self -> validate_string("resetcode", {"required"   => 1,
                                                                              "nicename"   => $self -> {"template"} -> replace_langvar("LOGIN_RESETCODE"),
                                                                              "minlen"     => 64,
                                                                              "maxlen"     => 64,
                                                                              "formattest" => '^[a-zA-Z0-9]+$',
                                                                              "formatdesc" => $self -> {"template"} -> replace_langvar("LOGIN_ERR_BADRECCHAR")});
    return ($error, $args) if($error);

    # Does the reset code match the one set for the user?
    return ($self -> {"template"} -> replace_langvar("LOGIN_ERR_BADRECCODE"), $args)
        unless($user -> {"act_code"} && $user -> {"act_code"} eq $args -> {"resetcode"});

    # Users can not recover an inactive account - they need to get a new act code
    return ($self -> {"template"} -> replace_langvar("LOGIN_ERR_NORECINACT"), $args)
        if($self -> {"session"} -> {"auth"} -> require_activate($user -> {"username"}) &&
           !$self -> {"session"} -> {"auth"} -> activated($user -> {"username"}));

    # double-check the authmethod supports resets, just to be on the safe side (the code should never
    # get here if it does not, but better safe than sorry)
    return ($self -> {"session"} -> {"auth"} -> norecover_message($user -> {"username"}), $args)
        if(!$self -> {"session"} -> {"auth"} -> supports_recovery($user -> {"username"}));

    # Okay, user is valid, authcode checks out, auth module supports resets, generate a new
    # password and send it
    my $newpass  = $self -> {"session"} -> {"auth"} -> reset_password($user -> {"username"});
    return ($self -> {"template"} -> load_template("login/recover_error.tem", {"***reason***" => $self -> {"session"} -> {"auth"} -> errstr()}), $args)
        if(!$newpass);

    # Get here and the user's account has been reset
    $self -> reset_email($user, $newpass);

    return($user, $args);
}


# ============================================================================
#  Form generators

## @method private $ generate_login_form($error, $args)
# Generate the content of the login form.
#
# @param error A string containing errors related to logging in, or undef.
# @param args  A reference to a hash of intiial values.
# @return An array of two values: the page title, and a string containing
#         the login form.
sub generate_login_form {
    my $self  = shift;
    my $error = shift;
    my $args  = shift;

    # Wrap the error message in a message box if we have one.
    $error = $self -> {"template"} -> load_template("login/error_box.tem", {"***message***" => $error})
        if($error);

    # Persist length is always in seconds, so convert it to something more readable
    my $persist_length = $self -> {"template"} -> humanise_seconds($self -> {"session"} -> {"auth"} -> get_config("max_autologin_time"));

    # if self-registration is enabled, turn on the option
    my $self_register = $self -> {"settings"} -> {"config"} -> {"Newsagent::Login:allow_self_register"} ?
                        $self -> {"template"} -> load_template("login/selfreg.tem") :
                        $self -> {"template"} -> load_template("login/no_selfreg.tem");

    return ($self -> {"template"} -> replace_langvar("LOGIN_TITLE"),
            $self -> {"template"} -> load_template("login/form.tem", {"***error***"       => $error,
                                                                      "***persistlen***"  => $persist_length,
                                                                      "***selfreg***"     => $self_register,
                                                                      "***url-actform***" => $self -> build_url("block" => "login", "itempath" => [ "activate" ]),
                                                                      "***url-recform***" => $self -> build_url("block" => "login", "itempath" => [ "recover" ]),
                                                                      "***target***"      => $self -> build_url("block" => "login"),
                                                                      "***course***"      => $self -> {"cgi"} -> param("course") || "",
                                                                      "***question***"    => $self -> {"settings"} -> {"config"} -> {"Newsagent::Login:self_register_question"},
                                                                      "***username***"    => $args -> {"username"},
                                                                      "***regname***"     => $args -> {"regname"},
                                                                      "***email***"       => $args -> {"email"}}));
}


## @method private @ generate_actcode_form($error)
# Generate a form through which the user may specify an activation code.
#
# @param error A string containing errors related to activating, or undef.
# @return An array of two values: the page title string, the code form
sub generate_actcode_form {
    my $self  = shift;
    my $error = shift;

    # Wrap the error message in a message box if we have one.
    $error = $self -> {"template"} -> load_template("login/error_box.tem", {"***message***" => $error})
        if($error);

    return ($self -> {"template"} -> replace_langvar("LOGIN_TITLE"),
            $self -> {"template"} -> load_template("login/act_form.tem", {"***error***"      => $error,
                                                                          "***target***"     => $self -> build_url("block" => "login"),
                                                                          "***url-resend***" => $self -> build_url("block" => "login", "itempath" => [ "resend" ]),}));
}


## @method private @ generate_recover_form($error)
# Generate a form through which the user may recover their account details.
#
# @param error A string containing errors related to recovery, or undef.
# @return An array of two values: the page title string, the code form
sub generate_recover_form {
    my $self  = shift;
    my $error = shift;

    # Wrap the error message in a message box if we have one.
    $error = $self -> {"template"} -> load_template("login/error_box.tem", {"***message***" => $error})
        if($error);

    return ($self -> {"template"} -> replace_langvar("LOGIN_TITLE"),
            $self -> {"template"} -> load_template("login/recover_form.tem", {"***error***"  => $error,
                                                                              "***target***" => $self -> build_url("block" => "login")}));
}


## @method private @ generate_resend_form($error)
# Generate a form through which the user may resend their account activation code.
#
# @param error A string containing errors related to resending, or undef.
# @return An array of two values: the page title string, the code form
sub generate_resend_form {
    my $self  = shift;
    my $error = shift;

    # Wrap the error message in a message box if we have one.
    $error = $self -> {"template"} -> load_template("login/error_box.tem", {"***message***" => $error})
        if($error);

    return ($self -> {"template"} -> replace_langvar("LOGIN_TITLE"),
            $self -> {"template"} -> load_template("login/resend_form.tem", {"***error***"  => $error,
                                                                             "***target***" => $self -> build_url("block" => "login")}));
}


# ============================================================================
#  Response generators

## @method private @ generate_loggedin()
# Generate the contents of a page telling the user that they have successfully logged in.
#
# @return An array of three values: the page title string, the 'logged in' message, and
#         a meta element to insert into the head element to redirect the user.
sub generate_loggedin {
    my $self = shift;

    my $url = $self -> build_return_url();
    my $warning = "";

    # The user validation might have thrown up warning, so check that.
    $warning = $self -> {"template"} -> load_template("login/warning_box.tem", {"***message***" => $self -> {"session"} -> auth_error()})
        if($self -> {"session"} -> auth_error());

    my ($content, $extrahead);

    # If any warnings were encountered, send back a different logged-in page to avoid
    # confusing users.
    if(!$warning) {
        # Note that, while it would be nice to immediately redirect users at this point,
        $content = $self -> {"template"} -> message_box($self -> {"template"} -> replace_langvar("LOGIN_DONETITLE"),
                                                        "security",
                                                        $self -> {"template"} -> replace_langvar("LOGIN_SUMMARY"),
                                                        $self -> {"template"} -> replace_langvar("LOGIN_LONGDESC", {"***url***" => $url}),
                                                        undef,
                                                        "logincore",
                                                        [ {"message" => $self -> {"template"} -> replace_langvar("SITE_CONTINUE"),
                                                           "colour"  => "blue",
                                                           "action"  => "location.href='$url'"} ]);
        $extrahead = $self -> {"template"} -> load_template("refreshmeta.tem", {"***url***" => $url});

    # Users who have encountered warnings during login always get a login confirmation page, as it has
    # to show them the warning message box.
    } else {
        my $message = $self -> {"template"} -> message_box($self -> {"template"} -> replace_langvar("LOGIN_DONETITLE"),
                                                           "security",
                                                           $self -> {"template"} -> replace_langvar("LOGIN_SUMMARY"),
                                                           $self -> {"template"} -> replace_langvar("LOGIN_NOREDIRECT", {"***url***" => $url,
                                                                                                                         "***supportaddr***" => ""}),
                                                           undef,
                                                           "logincore",
                                                           [ {"message" => $self -> {"template"} -> replace_langvar("SITE_CONTINUE"),
                                                              "colour"  => "blue",
                                                              "action"  => "location.href='$url'"} ]);
        $content = $self -> {"template"} -> load_template("login/login_warn.tem", {"***message***" => $message,
                                                                                   "***warning***" => $warning});
    }

    # return the title, content, and extraheader. If the warning is set, do not include an autoredirect.
    return ($self -> {"template"} -> replace_langvar("LOGIN_DONETITLE"),
            $content,
            $extrahead);
}


## @method private @ generate_loggedout()
# Generate the contents of a page telling the user that they have successfully logged out.
#
# @return An array of three values: the page title string, the 'logged out' message, and
#         a meta element to insert into the head element to redirect the user.
sub generate_loggedout {
    my $self = shift;

    # NOTE: This is called **after** the session is deleted, so savestate will be undef. This
    # means that the user will be returned to a default (the login form, usually).
    my $url = $self -> build_return_url();

    # return the title, content, and extraheader
    return ($self -> {"template"} -> replace_langvar("LOGOUT_TITLE"),
            $self -> {"template"} -> message_box($self -> {"template"} -> replace_langvar("LOGOUT_TITLE"),
                                                 "security",
                                                 $self -> {"template"} -> replace_langvar("LOGOUT_SUMMARY"),
                                                 $self -> {"template"} -> replace_langvar("LOGOUT_LONGDESC", {"***url***" => $url}),
                                                 undef,
                                                 "logincore",
                                                 [ {"message" => $self -> {"template"} -> replace_langvar("SITE_CONTINUE"),
                                                    "colour"  => "blue",
                                                    "action"  => "location.href='$url'"} ]),
            $self -> {"template"} -> load_template("refreshmeta.tem", {"***url***" => $url}));
}


## @method private @ generate_activated($user)
# Generate the contents of a page telling the user that they have successfully activated
# their account.
#
# @return An array of two values: the page title string, the 'activated' message.
sub generate_activated {
    my $self = shift;

    my $target = $self -> build_url("block" => "login");

    return ($self -> {"template"} -> replace_langvar("LOGIN_ACT_DONETITLE"),
            $self -> {"template"} -> message_box($self -> {"template"} -> replace_langvar("LOGIN_ACT_DONETITLE"),
                                                 "security",
                                                 $self -> {"template"} -> replace_langvar("LOGIN_ACT_SUMMARY"),
                                                 $self -> {"template"} -> replace_langvar("LOGIN_ACT_LONGDESC",
                                                                                          {"***url-login***" => $self -> build_url("block" => "login")}),
                                                 undef,
                                                 "logincore",
                                                        [ {"message" => $self -> {"template"} -> replace_langvar("LOGIN_LOGIN"),
                                                           "colour"  => "blue",
                                                           "action"  => "location.href='$target'"} ]));
}


## @method private @ generate_registered()
# Generate the contents of a page telling the user that they have successfully created an
# inactive account.
#
# @return An array of two values: the page title string, the 'registered' message.
sub generate_registered {
    my $self = shift;

    my $url = $self -> build_url("block" => "login", "itempath" => [ "activate" ]);

    return ($self -> {"template"} -> replace_langvar("LOGIN_REG_DONETITLE"),
            $self -> {"template"} -> message_box($self -> {"template"} -> replace_langvar("LOGIN_REG_DONETITLE"),
                                                 "security",
                                                 $self -> {"template"} -> replace_langvar("LOGIN_REG_SUMMARY"),
                                                 $self -> {"template"} -> replace_langvar("LOGIN_REG_LONGDESC"),
                                                 undef,
                                                 "logincore",
                                                 [ {"message" => $self -> {"template"} -> replace_langvar("LOGIN_ACTIVATE"),
                                                    "colour"  => "blue",
                                                    "action"  => "location.href='$url'"} ]));
}


## @method private @ generate_resent()
# Generate the contents of a page telling the user that a new activation code has been
# sent to their email address.
#
# @return An array of two values: the page title string, the 'resent' message.
sub generate_resent {
    my $self = shift;

    my $url = $self -> build_url("block" => "login", "itempath" => [ "activate" ]);

    return ($self -> {"template"} -> replace_langvar("LOGIN_RESEND_DONETITLE"),
            $self -> {"template"} -> message_box($self -> {"template"} -> replace_langvar("LOGIN_RESEND_DONETITLE"),
                                                 "security",
                                                 $self -> {"template"} -> replace_langvar("LOGIN_RESEND_SUMMARY"),
                                                 $self -> {"template"} -> replace_langvar("LOGIN_RESEND_LONGDESC"),
                                                 undef,
                                                 "logincore",
                                                 [ {"message" => $self -> {"template"} -> replace_langvar("LOGIN_ACTIVATE"),
                                                    "colour"  => "blue",
                                                    "action"  => "location.href='$url'"} ]));
}


## @method private @ generate_recover()
# Generate the contents of a page telling the user that a new password has been
# sent to their email address.
#
# @return An array of two values: the page title string, the 'recover sent' message.
sub generate_recover {
    my $self = shift;

    my $url = $self -> build_url("block" => "login", "itempath" => []);

    return ($self -> {"template"} -> replace_langvar("LOGIN_RECOVER_DONETITLE"),
            $self -> {"template"} -> message_box($self -> {"template"} -> replace_langvar("LOGIN_RECOVER_DONETITLE"),
                                                 "security",
                                                 $self -> {"template"} -> replace_langvar("LOGIN_RECOVER_SUMMARY"),
                                                 $self -> {"template"} -> replace_langvar("LOGIN_RECOVER_LONGDESC"),
                                                 undef,
                                                 "logincore",
                                                 [ {"message" => $self -> {"template"} -> replace_langvar("LOGIN_LOGIN"),
                                                    "colour"  => "blue",
                                                    "action"  => "location.href='$url'"} ]));
}


## @method private @ generate_reset()
# Generate the contents of a page telling the user that a new password has been
# sent to their email address.
#
# @param  error If set, display an error message rather than a 'completed' message.
# @return An array of two values: the page title string, the 'resent' message.
sub generate_reset {
    my $self  = shift;
    my $error = shift;

    my $url = $self -> build_url("block" => "login", "itempath" => []);

    if(!$error) {
        return ($self -> {"template"} -> replace_langvar("LOGIN_RESET_DONETITLE"),
                $self -> {"template"} -> message_box($self -> {"template"} -> replace_langvar("LOGIN_RESET_DONETITLE"),
                                                     "security",
                                                     $self -> {"template"} -> replace_langvar("LOGIN_RESET_SUMMARY"),
                                                     $self -> {"template"} -> replace_langvar("LOGIN_RESET_LONGDESC"),
                                                     undef,
                                                     "logincore",
                                                     [ {"message" => $self -> {"template"} -> replace_langvar("LOGIN_LOGIN"),
                                                        "colour"  => "blue",
                                                        "action"  => "location.href='$url'"} ]));
    } else {
        return ($self -> {"template"} -> replace_langvar("LOGIN_RESET_ERRTITLE"),
                $self -> {"template"} -> message_box($self -> {"template"} -> replace_langvar("LOGIN_RESET_ERRTITLE"),
                                                     "error",
                                                     $self -> {"template"} -> replace_langvar("LOGIN_RESET_ERRSUMMARY"),
                                                     $self -> {"template"} -> replace_langvar("LOGIN_RESET_ERRDESC", {"***reason***" => $error}),
                                                     undef,
                                                     "logincore",
                                                     [ {"message" => $self -> {"template"} -> replace_langvar("LOGIN_LOGIN"),
                                                        "colour"  => "blue",
                                                        "action"  => "location.href='$url'"} ]));
    }
}


# ============================================================================
#  Interface functions

## @method $ page_display()
# Generate the page content for this module.
sub page_display {
    my $self = shift;

    # We need to determine what the page title should be, and the content to shove in it...
    my ($title, $body, $extrahead) = ("", "", "");
    my @itempath = $self -> {"cgi"} -> param("itempath");

    # If the user is not anonymous, they have logged in already.
    if(!$self -> {"session"} -> anonymous_session()) {

        # Is the user requesting a logout? If so, doo eet.
        if(defined($self -> {"cgi"} -> param("logout")) || ($itempath[0] && $itempath[0] eq "logout")) {
            $self -> log("logout", $self -> {"session"} -> get_session_userid());
            if($self -> {"session"} -> delete_session()) {
                ($title, $body, $extrahead) = $self -> generate_loggedout();
            } else {
                return $self -> generate_fatal($SessionHandler::errstr);
            }

        # Already logged in, huh. Send back the logged-in message to remind them...
        } else {
            ($title, $body, $extrahead) = $self -> generate_loggedin();
        }

    # User is anonymous - do we have a login?
    } elsif(defined($self -> {"cgi"} -> param("login"))) {

        # Validate the other fields...
        my ($user, $args) = $self -> validate_login();

        # Do we have any errors? If so, send back the login form with them
        if(!ref($user)) {
            $self -> log("login error", $user);
            ($title, $body) = $self -> generate_login_form($user, $args);

        # No errors, user is valid...
        } else {
            # should the login be made persistent?
            my $persist = defined($self -> {"cgi"} -> param("persist")) && $self -> {"cgi"} -> param("persist");

            # create the new logged-in session, copying over the savestate session variable
            $self -> {"session"} -> create_session($user -> {"user_id"},
                                                   $persist,
                                                   {"savestate" => $self -> get_saved_state()});

            $self -> log("login", $user -> {"username"});
            ($title, $body, $extrahead) = $self -> generate_loggedin();
        }

    # Has a registration attempt been made?
    } elsif(defined($self -> {"cgi"} -> param("register"))) {

        # Validate/perform the registration
        my ($user, $args) = $self -> validate_register();

        # Do we have any errors? If so, send back the login form with them
        if(!ref($user)) {
            $self -> log("registration error", $user);
            ($title, $body) = $self -> generate_login_form($user, $args);

        # No errors, user is registered
        } else {
            # Do not create a new session - the user needs to confirm the account.
            $self -> log("registered inactive", $user -> {"username"});
            ($title, $body) = $self -> generate_registered();
        }

    # Is the user attempting activation?
    } elsif(defined($self -> {"cgi"} -> param("actcode"))) {

        my ($user, $args) = $self -> validate_actcode();
        if(!ref($user)) {
            $self -> log("activation error", $user);
            ($title, $body) = $self -> generate_actcode_form($user);
        } else {
            $self -> log("activation success", $user -> {"username"});
            ($title, $body) = $self -> generate_activated($user);
        }

    # Password reset requested?
    } elsif(defined($self -> {"cgi"} -> param("dorecover"))) {

        my ($user, $args) = $self -> validate_recover();
        if(!ref($user)) {
            $self -> log("Reset error", $user);
            ($title, $body) = $self -> generate_recover_form($user);
        } else {
            $self -> log("Reset success", $user -> {"username"});
            ($title, $body) = $self -> generate_recover($user);
        }

    } elsif(defined($self -> {"cgi"} -> param("resetcode"))) {

        my ($user, $args) = $self -> validate_reset();
        ($title, $body) = $self -> generate_reset(!ref($user) ? $user : undef);
    # User wants a resend?
    } elsif(defined($self -> {"cgi"} -> param("doresend"))) {

        my ($user, $args) = $self -> validate_resend();
        if(!ref($user)) {
            $self -> log("Resend error", $user);
            ($title, $body) = $self -> generate_resend_form($user);
        } else {
            $self -> log("Resend success", $user -> {"username"});
            ($title, $body) = $self -> generate_resent($user);
        }


    } elsif(defined($self -> {"cgi"} -> param("activate")) || ($itempath[0] && $itempath[0] eq "activate")) {
        ($title, $body) = $self -> generate_actcode_form();

    } elsif(defined($self -> {"cgi"} -> param("recover")) || ($itempath[0] && $itempath[0] eq "recover")) {
        ($title, $body) = $self -> generate_recover_form();

    } elsif(defined($self -> {"cgi"} -> param("resend")) || ($itempath[0] && $itempath[0] eq "resend")) {
        ($title, $body) = $self -> generate_resend_form();

    # No session, no submission? Send back the login form...
    } else {
        ($title, $body) = $self -> generate_login_form();
    }

    # Done generating the page content, return the filled in page template
    return $self -> {"template"} -> load_template("login/page.tem", {"***title***"     => $title,
                                                                     "***extrahead***" => $extrahead,
                                                                     "***content***"   => $body,});
}

1;
