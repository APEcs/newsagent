var selects;
var controls;

/** Add a click handler to the specified queue list element to switch
 *  the queue view to a different queue.
 *
 * @param element The element to attach the click event handler to.
 */
function setup_queue_link(element)
{
    element.addEvent("click", function(event) {
        var id   = event.target.get('id');
        var name = id.substr(6);

        location.href = mlisturl + "/" + name;
    });
}


/** Update the queue list shown on the page based on the array of XML
 *  elements provided. This goes through the elements in the specified
 *  list and uses the 'name', 'value' and 'hasnew' attributes to
 *  update the list of queues shown to the user.
 *
 * @param queues An array of XML queue elements.
 */
function update_queue_list(queues)
{
    // Go through the list of queue elements, and update the
    // text and new status for each queue shown to the user.
    Array.each(queues, function(queue) {
                   var name = queue.getAttribute("name");
                   var node = $("queue-"+name);

                   // It's possible that the list from the server includes a queue
                   // not currently in the page (no element exists for it), so only
                   // try updating if the queue element exists.
                   if(node) {
                       node.set('html', queue.getAttribute("value"));

                       if(queue.getAttribute("hasnew") > 0) {
                           node.getParent().getParent().addClass("hasnew");
                       } else {
                           node.getParent().getParent().removeClass("hasnew");
                       }
                   }
               });
}


/** Update the list of queues to show the current counts of new messages.
 *  This asks the server for an updated list of queues, and modifies the
 *  queue list in the page to reflect the new data.
 */
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
                                    update_queue_list(respXML.getElementsByTagName("queue"));
                                }
                                $('movespin').fade('out');
                            }
                          });
    req.post();
}


/** Handle the request to move messages into a different queue. This takes
 *  a destination queue id and an array of message ids to move. After
 *  asking the server to move the messages, if all is successful, it will
 *  update the queue list and remove the messages from the current queue
 *  view.
 *
 * @param destqueue  The ID of the queue the message(s) should be moved to.
 * @param messageids An array of message ids to move.
 */
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
                                    update_queue_list(respXML.getElementsByTagName("queue"));

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


/** Handle the request to promote a message to a Newsagent article. This takes
 *  the element of the message list the user clicked on the promote option for
 *  and uses its ID to identify which message to promote.
 *
 * @param element The element representing the message to promote.
 */
function promote_message(element)
{
    var msgid = element.getParent().get('id').substr(7);
    var uri = new URI(composeurl);
    uri.setData('tellusid', msgid);

    location.href = uri.toString();
}


/** Open a popup window containing the message selected. This takes the element of
 *  the message list the user clicked on and opens a popup window containing the
 *  text of the message, with options to promote, reject, or delete it.
 *
 * @param element The element representing the message to show.
 */
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
    $$('div.queuetitle').each(function(element) { setup_queue_link(element); });

    // Allow URLs in information to be clickable
    $$("table.listtable li.info a").each(function(elem) {
        elem.addEvent("click", function(event) { event.stopPropagation(); });
    });

    // Attach message viewer handlers to clicks on summary rows.
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