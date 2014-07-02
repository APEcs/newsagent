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


function refresh_queuelist()
{
    var req = new Request({ url: api_request_path("queues", "queues", basepath),
                            onRequest: function() {
                                $('movespin').fade('in');
                            },
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
                                $('movespin').fade('out');
                            }
                          });
    req.post();
}


function move_messages(destqueue, messageids)
{
    var req = new Request({ url: api_request_path("queues", "move", basepath),
                            onRequest: function() {
                                $('movespin').fade('in');
                            },
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

                                    var msgids = respXML.getElementsByTagName("message");
                                    Array.each(msgids, function(message) {
                                                   var id = message.get('text');
                                                   var elem = $('msgrow-'+id);
                                                   if(elem) elem.dissolve().get('reveal').chain(function() { elem.destroy(); });
                                               });
                                }
                                $('movespin').fade('out');
                            }
                          });
    req.post({dest: destqueue,
              msgids: messageids.join(",")});
}


function view_message(element)
{
    var msgid = element.getParent().get('id').substr(7);

    var req = new Request.HTML({ url: api_request_path("queues", "view", basepath),
                                 method: 'post',
                                 onRequest: function() {
                                     $('movespin').fade('in');
                                 },
                                 onSuccess: function(respTree, respElems, respHTML) {
                                     var err = respHTML.match(/^<div id="apierror"/);

                                     if(err) {
                                         $('errboxmsg').set('html', respHTML);
                                         errbox.open();

                                     // No error, content should be form.
                                     } else {
                                         element.removeClass("new");
                                         var buttons  = [ { title: messages['promote'], color: 'blue', event: function() { popbox.close(); promote_message(element); } },
                                                          { title: messages['reject'] , color: 'red' , event: function() { popbox.close(); reject_message(element);  } },
                                                          { title: messages['delete'] , color: 'red' , event: function() { popbox.close(); delete_message(element);  } },
                                                          { title: messages['cancel'] , color: 'blue', event: function() { popbox.close(); popbox.footer.empty();    } }
                                                        ];

                                         $('poptitle').set('text', messages['view']);
                                         $('popbody').empty().set('html', respHTML);
                                         popbox.setButtons(buttons);
                                         new Element("img", {'id': 'popspinner',
                                                             'src': spinner_url,
                                                             width: 16,
                                                             height: 16,
                                                             'class': 'workspin'}).inject(popbox.footer, 'top');
                                         popbox.open();
                                     }
                                     $('movespin').fade('out');
                                     refresh_queuelist();
                                 }
                               });
    req.post({'id': msgid});
}


window.addEvent('domready', function() {
    // Enable queue selection
    $$('div.queuetitle').each(function(element) { setup_queue_link(element) });

    // Allow URLs in information to be clickable
    $$("table.listtable li.info a").each(function(elem) {
        elem.addEvent("click", function(event) { event.stopPropagation(); });
    });

    $$("table.listtable td.summary").each(function(elem) {
        elem.addEvent("click", function(event) { view_message(elem); });
    });

    // set up the control menu
    controls = new MessageControl('message-controls', {onMoveMsg: function(dest, vals) { move_messages(dest, vals); }
                                                      });

    // set up the select menu. Changes in this menu need to trigger visibility
    // checks in the controls box.
    selects = new SelectControl('select-ctrl', {onUpdate: function() { controls.updateVis(); }});

});