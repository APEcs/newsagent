// If this is true, selected feeds and email address will be cleared
// when the user clicks the subscribe button.
var clear_on_sub = true;
var controls;
var selects;
var multiselfeed;

function subscribe()
{
    // must have one or more feeds selected
    if($$('input.feed:checked').length == 0) {
        $('errboxmsg').set('html', '<p>'+messages['subnofeeds']+'</p>');
        errbox.open();
        return false;
    }

    var feeds = new Array();
    $$('input.feed:checked').each(function(element) {
        feeds.push(element.get('id').substr(5));

        if(clear_on_sub)
            element.set('checked', false);  // No need to keep the selected feeds
    });

    multiselfeed.update();

    var values = JSON.encode({'feeds': feeds });

    var req = new Request({ url: api_request_path("subscribe", "append", basepath ),
                            onRequest: function() {
                                $('subspin').fade('in');
                                $('subadd').set('disabled', true);
                            },
                            onSuccess: function(respText, respXML) {
                                $('subspin').fade('out');
                                $('subadd').set('disabled', false);

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
    req.post({'values': values});
}


function unsubscribe(feeds)
{
    var values = JSON.encode({'feeds': feeds });

    var req = new Request({ url: api_request_path("subscribe", "rem", basepath ),
                            onRequest: function() {
                                $('subspin').fade('in');
                            },
                            onSuccess: function(respText, respXML) {
                                $('subspin').fade('out');

                                var err = respXML.getElementsByTagName("error")[0];
                                if(err) {
                                    $('errboxmsg').set('html', '<p class="error">'+err.getAttribute('info')+'</p>');
                                    errbox.open();

                                    // No error, we have a response
                                } else {
                                    var res = respXML.getElementsByTagName("response")[0];
                                    var button   = res.getAttribute('button');

                                    // drop the deleted rows...
                                    feeds.each(function(feedid) {
                                        var row = $('feedrow-' + feedid);
                                        if(row) {
                                            row.fade('out').get('tween').chain(function() { row.destroy();
                                                                                            controls.updateVis();
                                                                                            selects.updateMode();
                                                                                          });
                                        }
                                    });

                                    var buttons = [  { title: button , color: 'blue', event: function() { popbox.close(); } } ];
                                    popbox.setButtons(buttons);
                                    popbox.setContent(res.innerHTML);
                                    popbox.open();
                                }
                            }
                          });
    req.post({'values': values});
}


window.addEvent('domready', function() {
    controls = new MessageControl('message-controls', { onDeleteMsg: function(vals) { unsubscribe(vals); }
    });

    selects = new SelectControl('select-ctrl', { onUpdate: function() { controls.updateVis(); controls.updateSelected(); }});

    $('subadd').addEvent('click', function() { subscribe(clear_on_sub); });

});
