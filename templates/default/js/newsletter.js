var sortlist;
var savetimer;
var saving = false;
var toggling = false;

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


var do_publish = function()
{
    if(!saving) {
        var req = new Request({ url: api_request_path("newsletters", "publish"),
                                onRequest: function() {
                                    $('statespin').fade('in');
                                    $('statemsg').set('html', messages['publishing']);
                                },
                                onSuccess: function(respText, respXML) {
                                    $('statespin').fade('out');
                                    $('statemsg').set('html', '');

                                    var err = respXML.getElementsByTagName("error")[0];
                                    if(err) {
                                        $('errboxmsg').set('html', '<p class="error">'+err.getAttribute('info')+'</p>');
                                        errbox.open();

                                        // No error, we have a response
                                    } else {
                                        var result = respXML.getElementsByTagName('result')[0];
                                        var status = result.getAttribute('status');

                                        $('popbody').empty().set('html', result.textContent);
                                        popbox.setButtons( [ { title: messages['continue'], color: 'blue', event: function() {
                                                                   location.reload();
                                                               }
                                                             }
                                                           ]);
                                        popbox.open();
                                    }
                                }
                              });
        var args = { name: newsname };

        req.post(args);
    }
}


function check_readiness()
{
    var not_ready_count = $$('td.readymark.notdone').length;

    // If all are ready, do the publishing.
    if(!not_ready_count) {
        confbox.setButtons([ { title: messages['publish'], color: 'blue', event: function() { do_publish(); confbox.close(); } },
                             { title: messages['cancel'] , color: 'blue', event: function() { confbox.close(); } }
                           ]);
        $('confboxmsg').set('html', messages['confpublish']);
        confbox.open();

    // Otherwise one or more contributors are not marked as ready, show the warning
    } else {
        confbox.setButtons([ { title: messages['publish'], color: 'red', event: function() { do_publish(); confbox.close(); } },
                             { title: messages['cancel'] , color: 'blue', event: function() { confbox.close(); } }
                           ]);
        $('confboxmsg').set('html', messages['notready']);
        confbox.open();
    }
}


function check_required_sections()
{
    var empty_required = false;

    $$('div.section.required').each(function(element) {
        var subid = element.get('id').substr(4);
        var count = element.getFirst('ul.section').getChildren().length;
        var required = $('req'+subid).textContent;

        // Does the UL inside this element have any children?
        if(count < required) {
            empty_required = true;
            element.addClass('empty');
        } else {
            element.removeClass('empty');
        }

        $('count'+subid).set('html', count);
    });

    var publish = $('publishbtn');
    if(publish) {
        var mode = 'publish';
        if(empty_required) {
            publish.addClass('disabled');
            mode = 'blocked';
            publish.removeEvents('click');
        } else {
            publish.removeClass('disabled');
            publish.addEvent('click', function() { check_readiness(); });
        }

        publish.setProperty('title', messages[mode]);
        publish.getFirst('img').setProperty('src', pubimg[mode]);
    }
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
    check_required_sections();
}


function set_issue_date(date)
{
    location.href = issueurl + "/" +  date.getFullYear() + "/" + (date.getMonth() + 1) + "/" + date.getDate();
}


function attach_ready_toggle()
{
    $$('input.readytoggle').each(function(element) {
        element.removeEvents('change');

        element.addEvent('change', function() {
            if(!toggling) {
                toggling = true;

                var togglereq = new Request.HTML({url: api_request_path("newsletters", "toggleready"),
                                                  onRequest: function() { element.set('disabled', true); },
                                                  onSuccess: function(respTree, respElems, respHTML) {
                                                      $('newsletcontribs').getChildren().destroy().empty();
                                                      $('newsletcontribs').set('html', respHTML);

                                                      attach_ready_toggle();
                                                      toggling = false;
                                                  }
                                                 });
                togglereq.post({ name: newsname });
            }
        });
    });
}


function update_ready_list()
{
    if(!toggling) {
        // kill the toggle boxes to prevent it scewing with the reload
        $$('input.readytoggle').each(function(element) { element.set('disabled', true); });

        var req = new Request.HTML({url: api_request_path("newsletters", "contributors"),
                                    onSuccess: function(respTree, respElems, respHTML) {
                                        $('newsletcontribs').getChildren().destroy().empty();
                                        $('newsletcontribs').set('html', respHTML);

                                        attach_ready_toggle();
                                        setTimeout(update_ready_list, 30000);
                                    }
                                   });
        req.post({ name: newsname });
    } else {
        setTimeout(update_ready_list, 30000);
    }
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

    check_required_sections();
    attach_ready_toggle();

    // Update the ready list 30 seconds from now.
    setTimeout(update_ready_list, 30000);
});