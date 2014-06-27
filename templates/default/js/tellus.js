var selects;
var controls;

function setup_queue_link(element)
{
    element.addEvent("click", function(event) {
        var id   = event.target.get('id');
        var name = id.substr(6);

        location.href = mlisturl + "/" + name;
    });
}


function move_messages(destqueue, messageids)
{
    var req = new Request({ url: api_request_path("queues", "move", basepath),
                            onSuccess: function(respText, respXML) {
                                var err = respXML.getElementsByTagName("error")[0];
                                if(err) {
                                    $('errboxmsg').set('html', '<p class="error">'+err.getAttribute('info')+'</p>');
                                    errbox.open();

                                // No error, we have a response
                                } else {
                                    var queues = respXML.getElementsByTagName("queue");
                                    Array.each(queues, function(queue) {
                                                   var name = queue.getAttribute("name");
                                                   var node = $("queue-"+name);
                                                   node.set('html', queue.getAttribute("value"));

                                                   if(queue.getAttribute("hasnew") > 0) {
                                                       node.getParent().getParent().addClass("hasnew");
                                                   } else {
                                                       node.getParent().getParent().removeClass("hasnew");
                                                   }
                                               });
                                }
                            }
                          });
    req.post({dest: destqueue,
              msgids: messageids.join(",")});
}


window.addEvent('domready', function() {
    // Enable queue selection
    $$('div.queuetitle').each(function(element) { setup_queue_link(element) });

    // Allow URLs in information to be clickable
    $$("table.listtable li.info a").each(function(elem) {
        elem.addEvent("click", function(event) { event.stopPropagation(); });
    });

    // set up the control menu
    controls = new MessageControl('message-controls', {onMoveMsg: function(dest, vals) { move_messages(dest, vals); }
                                                      });

    // set up the select menu. Changes in this menu need to trigger visibility
    // checks in the controls box.
    selects = new SelectControl('select-ctrl', {onUpdate: function() { controls.updateVis(); }});

});