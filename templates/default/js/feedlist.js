// If this is true, selected feeds and email address will be cleared
// when the user clicks the subscribe button.
var clear_on_sub = true;


function get_selected_feeds()
{
    var feeds = new Array();

    $$('input.selfeed:checked').each(function(element) {
        feeds.push(element.get('id').substr(5));
    });

    return feeds.join(",");
}


function get_selected_levels()
{
    var levels = new Array();

    $$('input.levels:checked').each(function(element) {
        levels.push(element.get('id').substr(6));
    });

    return levels.join(",");
}


function get_selected_fulltext()
{
    var fulltext = $('fulltext');
    var mode = fulltext.options[fulltext.selectedIndex].get('value');

    if(mode != "off") {
        return mode;
    }

    return "";
}


function get_selected_viewer()
{
    var viewer = $('viewer');
    return viewer.options[viewer.selectedIndex].get('value');
}


function get_descmode()
{
    var enabled = $('desc').get('checked');

    return enabled ? "fulltext" : "";
}


function change_count(inc)
{
    var current = parseInt($('count').get('value'), 10);

    // Check range before doing anything
    if(current < 1) current = 1;
    if(current > 100) current = 100;

    current += (inc ? 1 : -1);

    // and another range check. Could make the above conditional, but meh
    if(current < 1) current = 1;
    if(current > 100) current = 100;

    $('count').set('value', current);
    build_feedurl();
}


function get_count()
{
    var current = parseInt($('count').get('value'), 10);

    if(current < 1) current = 1;
    if(current > 100) current = 100;

    // If the current count is not the default, return it *as a string*
    // returnign 'current' as is will break the query builder loop in
    // build_feedurl()
    return (current == def_count ? "" : current + '');
}


function build_feedurl() {

    var url    = url_base;
    var params = {     'feed': get_selected_feeds(),
                      'level': get_selected_levels(),
                   'fulltext': get_selected_fulltext(),
                     'viewer': get_selected_viewer(),
                       'desc': get_descmode(),
                      'count': get_count()
                 };

    // Convert the object to something more easily joinable
    var query = new Array();
    for(var param in params) {
        if(params[param].length) {
            query.push(encodeURIComponent(param) + "=" + encodeURIComponent(params[param]));
        }
    }

    if(query.length) url += "?" + query.join("&");

    $('urlbox').set('value', url);
}


function set_subscribe_button() {
    $('subadd').set('disabled', $$('input.selfeed:checked').length == 0);
}


function subscribe(clear_feeds) {

    // must have one or more feeds selected
    if($$('input.selfeed:checked').length == 0) {
        $('errboxmsg').set('html', '<p>'+messages['subnofeeds']+'</p>');
        errbox.open();
        return false;
    }

    // Users without login must set email
    if($('user-login') && !$('subemail').get('value')) {
        $('errboxmsg').set('html', '<p>'+messages['subnoemail']+'</p>');
        errbox.open();
        return false;
    }

    // The subscribe button can be disabled here, as the feeds are cleared below.
    if(clear_feeds)
        $('subadd').set('disabled', true);

    var feeds = new Array();
    $$('input.selfeed:checked').each(function(element) {
        feeds.push(element.get('id').substr(5));

        if(clear_feeds)
            element.set('checked', false);  // No need to keep the selected feeds
    });

    var values = JSON.encode({'email': $('subemail').get('value'),
                              'feeds': feeds });

    // possible clear the email, too
    if(clear_feeds)
        $('subemail').set('value', '');

    var req = new Request({ url: api_request_path("subscribe", "add", basepath ),
                            onRequest: function() {
                                $('subspin').fade('in');
                                $('subemail').set('disabled', true);
                                $('subman').set('disabled', true);
                            },
                            onSuccess: function(respText, respXML) {
                                $('subspin').fade('out');
                                $('subemail').set('disabled', false);
                                $('subman').set('disabled', false);

                                var err = respXML.getElementsByTagName("error")[0];
                                if(err) {
                                    $('errboxmsg').set('html', '<p class="error">'+err.getAttribute('info')+'</p>');
                                    errbox.open();

                                    // No error, we have a response
                                } else {
                                    var res = respXML.getElementsByTagName("response")[0];
                                    var button   = res.getAttribute('button');

                                    var buttons = [  { title: button , color: 'blue', event: function() { popbox.close(); } } ];
                                    popbox.setButtons(buttons);
                                    popbox.setContent(res.innerHTML);
                                    popbox.open();

                                }
                            }
                          });
    req.post({'values': values });
}

window.addEvent('domready', function() {

    $$('input.selfeed').addEvent('change', function() { build_feedurl(); set_subscribe_button(); });
    $('fulltext').addEvent('change', function() { build_feedurl(); });
    $('desc').addEvent('change', function() { build_feedurl(); });
    $('viewer').addEvent('change', function() { build_feedurl(); });
    $('count').addEvent('change', function() { build_feedurl(); });

    $('countdec').addEvent('click', function() { change_count(false); });
    $('countinc').addEvent('click', function() { change_count(true); });

    if($('subscribe')) {
        $('subadd').addEvent('click', function() { subscribe(clear_on_sub); });
    }

    build_feedurl();
});
