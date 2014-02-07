/** Edit an article - redirect the user to an edit page for now, popup editing
 *  may be an option in future...
 *
 * @param articleid The ID of the article to edit.
 */
function edit_article(articleid)
{
    location.href = edit_url + articleid;
}


/** Clone an article - redirect the user to an edit page for now, popup editing
 *  may be an option in future...
 *
 * @param articleid The ID of the article to edit.
 */
function clone_article(articleid)
{
    var uri = new URI(edit_url + articleid);
    uri.setData('clone', '1');

    uri.go();
}


/** Attempt to delete an article from the article list. This askes the
 *  server to delete the specified article entry and if the article is deleted
 *  it updates the row.
 *
 * @param articleid The ID of the article to attempt to delete.
 */
function delete_article(articleid)
{
    change_article_state(articleid, "delete", "deletebtn-a" + articleid);
}


/** Remove the deleted status from and article. This askes the server to
 *  'undelete' the specified article entry and if the article is restored
 *  it updates the row.
 *
 * @param articleid The ID of the article to attempt to undelete.
 */
function undelete_article(articleid)
{
    change_article_state(articleid, "undelete", "undeletebtn-a" + articleid);
}


/** Attempt to hide an article from the article list. This askes the
 *  server to hode the specified article entry and if the article is hidden
 *  it updates the row.
 *
 * @param articleid The ID of the article to attempt to hide.
 */
function hide_article(articleid)
{
    change_article_state(articleid, "hide", "hidebtn-a" + articleid);
}


/** Remove the hidden status from and article. This askes the server to
 *  'unhide' the specified article entry and if the article is restored
 *  it updates the row.
 *
 * @param articleid The ID of the article to attempt to unhide.
 */
function unhide_article(articleid)
{
    change_article_state(articleid, "unhide", "unhidebtn-a" + articleid);
}


/** Force an article to be published immediately, even if its time delay
 *  has not yet been reached.
 *
 * @param articleid The ID of the article to publish
 */
function publish_article(articleid)
{
    change_article_state(articleid, "publish", "pubbtn-a" + articleid);
}


/** Send an API request to update the status of an article, and update the
 *  corresponding table row as needed.
 *
 * @param articleid The ID of the article to update.
 * @param operation The operation to perform on the article.
 * @param control   The name of the element the user clicked on to trigger this.
 */
function change_article_state(articleid, operation, control)
{
    var req = new Request.HTML({ url: api_request_path("articlelist", operation+"/"+articleid),
                                 method: 'post',
                                 onRequest: function() {
                                     $(control).addClass('working');
                                     show_spinner($(control));
                                 },
                                 onSuccess: function(respTree, respElems, respHTML) {
                                     hide_spinner($(control));
                                     $(control).removeClass('working');

                                     var err = respHTML.match(/^<div id="apierror"/);

                                     if(err) {
                                         $('errboxmsg').set('html', respHTML);
                                         errbox.open();

                                     // No error, entry was flagged, the element provided should
                                     // be the new <tr>...
                                     } else {
                                         var tmp = new Element('table').set('html', respHTML);
                                         tmp = tmp.getChildren()[0];
                                         if(tmp) {
                                             tmp = tmp.getChildren()[0];

                                             if(tmp) {
                                                 var oldElem = $('artrow-'+articleid);
                                                 tmp.replaces(oldElem);
                                                 oldElem.destroy();
                                             } else {
                                                 $('errboxmsg').set('html', "<p>Malformed API response</p>");
                                                 errbox.open();
                                             }
                                         } else {
                                             $('errboxmsg').set('html', "<p>Malformed API response</p>");
                                             errbox.open();
                                         }
                                     }
                                 }
                               });
    req.send();
}


function fold_feedlist(element)
{
    // Fold feed lists over this length
    if(element.children.length > 3) {
        var more      = new Element('li', { 'html': '<i>' + (element.children.length - 2) + more_text + '</i>'});
        var showlist  = new Element("ul");
        var hidelist  = new Element("ul", { 'styles': { 'display': 'none' }});
        var container = new Element("div").adopt(showlist, hidelist);

        for(var elem = 0; elem < element.children.length; ++elem) {
            var dupe = element.children[elem].clone();

            if(elem < 2) {
                showlist.adopt(dupe);
            } else {
                hidelist.adopt(dupe);
            }
        }
        showlist.adopt(more);

        container.addEvent('mouseenter', function() { more.dissolve(); hidelist.reveal(); });
        container.addEvent('mouseleave', function() { more.reveal(); hidelist.dissolve(); });

        container.replaces(element);
    }
}

window.addEvent('domready', function() {
    Locale.use('en-GB');
    month_picker = new Picker.Date($('list_month'), { timePicker: false,
                                                      yearPicker: true,
                                                      positionOffset: {x: 5, y: 0},
                                                      pickerClass: 'datepicker_dashboard',
                                                      useFadeInOut: !Browser.ie,
                                                      pickOnly: 'months',
                                                      format: '%B %Y',
                                                      onSelect: function(date) {
                                                          location.href = basepath + "articles/" + date.format("%Y/%m");
                                                      }
                                                    });

     $$('ul.feedlist').each(function (element) { fold_feedlist(element); });
});
