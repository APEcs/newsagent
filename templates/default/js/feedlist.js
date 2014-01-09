
function get_selected_feeds()
{
    var feeds = new Array();

    $$('input.selfeed').each(function(element) {
        if(element.get('checked')) {
            feeds.push(element.get('id').substr(5));
        }
    });

    return feeds.join(",");
}


function get_selected_levels()
{
    var levels = new Array();

    $$('input.levels').each(function(element) {
        if(element.get('checked')) {
            levels.push(element.get('id').substr(6));
        }
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

window.addEvent('domready', function() {

    $$('input.selfeed').addEvent('change', function() { build_feedurl(); });
    $('fulltext').addEvent('change', function() { build_feedurl(); });
    $('desc').addEvent('change', function() { build_feedurl(); });
    $('count').addEvent('change', function() { build_feedurl(); });

    $('countdec').addEvent('click', function() { change_count(false); });
    $('countinc').addEvent('click', function() { change_count(true); });

    build_feedurl();
});
