/** \file
 *  Login check. Functions to determine whether the user is logged in, and
 *  provide them with a login form if they are not.
 */

/** \fn void check_login(callback)
 * Determine whether the user is logged in. If the user is logged in, the specified
 * callback is called, otherwise the login popup is opened to allow the user to
 * log in.
 *
 * \param callback A function to call when the user has logged in.
 */
function check_login(callback)
{
    var req = new Request({ url: api_request_path("login", "check", basepath),
                            onRequest: function() {
                                $('submitarticle').addClass('disabled').disabled = true;
                            },
                            onSuccess: function(respText, respXML) {
                                $('submitarticle').removeClass('disabled').disabled = false;

                                var err = respXML.getElementsByTagName("error")[0];
                                if(err) {
                                    $('errboxmsg').set('html', '<p class="error">'+err.getAttribute('info')+'</p>');
                                    errbox.open();

                                // No error, we have a response
                                } else {
                                    var login = respXML.getElementsByTagName('login');
                                    var logged_in = login[0].getAttribute('loggedin');

                                    if(logged_in == 'yes') {
                                        callback();
                                    } else {
                                        open_login_popup(callback);
                                    }
                                }
                            }
                          });
    req.post();
}


function open_login_popup(callback)
{
    var req = new Request.HTML({ url: api_request_path("login", "loginform", basepath),
                                 method: 'post',
                                 onRequest: function() {
                                     $('submitarticle').addClass('disabled').disabled = true;
                                 },
                                 onSuccess: function(respTree, respElems, respHTML) {
                                     $('submitarticle').removeClass('disabled').disabled = false;
                                     var err = respHTML.match(/^<div id="apierror"/);

                                     if(err) {
                                         $('errboxmsg').set('html', respHTML);
                                         errbox.open();

                                     // No error, content should be form.
                                     } else {
                                         var buttons  = [ { title: respElems[0].get('title'), color: 'blue', event: function() { check_login_popup(callback); } },
                                                          { title: confirm_messages['cancel'] , color: 'blue', event: function() { popbox.close(); popbox.footer.empty(); }} ];

                                         $('poptitle').set('text', respElems[0].get('title'));
                                         $('popbody').empty().adopt(respElems);
                                         popbox.setButtons(buttons);
                                         new Element("img", {'id': 'popspinner',
                                                             'src': spinner_url,
                                                             width: 16,
                                                             height: 16,
                                                             'class': 'workspin'}).inject(popbox.footer, 'top');
                                         popbox.open();
                                     }
                                 }
                               });
    req.post();
}


function check_login_popup(callback)
{
    var req = new Request({ url: api_request_path("login", "login", basepath),
                            onRequest: function() {
                                $('popspinner').fade('in');
                                popbox.disableButtons(true);
                            },
                            onSuccess: function(respText, respXML) {

                                var err = respXML.getElementsByTagName("error")[0];
                                if(err) {
                                    $('errboxmsg').set('html', '<p class="error">'+err.getAttribute('info')+'</p>');
                                    errbox.open();

                                // No error, we have a response
                                } else {
                                    $('popspinner').fade('out');
                                    var login = respXML.getElementsByTagName('login');
                                    var logged_in = login[0].getAttribute('loggedin');

                                    if(logged_in == 'yes') {
                                        set_session_cookies(respXML.getElementsByTagName('cookies'));

                                        popbox.close();
                                        popbox.footer.empty();
                                        callback();
                                    } else {
                                        $('apiloginerr').set('html', login[0].textContent);
                                    }

                                    popbox.disableButtons(false);
                                }
                            }
                          });
    req.post({username: $('apiuser').get('value'),
              password: $('apipass').get('value')});
}


function set_session_cookies(cookies)
{
    for(var i = 0; i < cookies.length; ++i) {
        var cookie = cookies[i];
        var name   = cookie.getAttribute('name');
        if(name) {
            var expire = cookie.getAttribute('expires');
            var path   = cookie.getAttribute('path');
            var value  = cookie.getElementsByTagName('value')[0].textContent;

            document.cookie = name+"="+value+"; expires="+expire+"; path="+path;
        }
    }
}
