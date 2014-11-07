var sortlist;
var savetimer;
var saving = false;

/** Add a click handler to the specified newsletter list element to switch
 *  the newsletter view to a different newsletter.
 *
 * @param element The element to attach the click event handler to.
 */
function setup_newsletter_link(element)
{
    element.addEvent("click", function(event) {
        var id   = event.target.get('id');
        var name = id.substr(5);

        location.href = nlisturl + "/" + name;
    });
}


function save_sort_order()
{
    savetimer = null;

    if(!saving) {
        saving = true;

        var values = JSON.encode(sortlist.serialize(function(element, index) { sec = element.getParent().getProperty('id'); return sec+"_"+element.getProperty('id'); }).flatten());

        var req = new Request({ url: api_request_path("newsletters", "sortorder"),
                                onRequest: function() { $('statemsg').addClass("saving"); },
                                onSuccess: function(respText, respXML) {
                                    $('statemsg').removeClass("saving");

                                    var err = respXML.getElementsByTagName("error")[0];
                                    if(err) {
                                        $('errboxmsg').set('html', '<p class="error">'+err.getAttribute('info')+'</p>');
                                        errbox.open();

                                        // No error, we have a response
                                    } else {
                                        var result = respXML.getElementsByTagName('result')[0];
                                        var status = result.getAttribute('status');

                                        $('statespin').fade('out');
                                        $('statemsg').set('html', status);
                                    }
                                    saving = false;
                                }
                              });
        req.post({sortinfo: values
                  // probably needs somethign here for dates
                 });
    }
}

function abort_save()
{
    clearTimeout(savetimer);
    savetimer = null;
}


function queue_save()
{
    if(savetimer) {
        clearTimeout(savetimer);
        savetimer = null;
    } else {
        $('statespin').fade('in');
        $('statemsg').set('html', messages['saving']);
    }

    savetimer = setTimeout(function() { save_sort_order(); }, 1000);
}


function set_issue_date(date)
{
    location.href = issueurl + "/" + date.getFullYear() + "/" + (date.getMonth() + 1) + "/" + date.getDate();
}

window.addEvent('domready', function() {
    // Enable newsletter selection
    $$('div.newstitle').each(function(element) { setup_newsletter_link(element); });

    sortlist = new CustomSortable('#messagebrowser div.edit ul', {
		                              clone: true,
		                              revert: true,
		                              opacity: 0.5,
                                      dropClass: 'droplist',
                                      onStart: function() { abort_save(); },
                                      onComplete: function() { queue_save(); }
	                              });

    sortlist.removeItems($$('#messagebrowser div.edit ul li.dummy'));

    $$('li.msgctrl-preview').each(function(element) {
        element.addEvent('click', function() {
            window.open(preview, 'preview');
        });
    });
});