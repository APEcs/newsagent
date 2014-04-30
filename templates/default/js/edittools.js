/* onbeforeunload edit warning handling. This is based on the technique
 * used in mediawiki - the onbeforeunload handler must be removed as
 * part of the submission process, or the onbeforeunload warning dialog
 * will be shown during submission as well as normal navigation.
 */
var savedOnBeforeUnload;

/** Fetch the value stored in a text area that may be being replaced
 *  by a ckeditor instance. This is required to allow the initial value
 *  recording to work even if ckeditor hasn't loaded and replaced the
 *  textarea yet.
 */
function ckeditor_data(fieldname)
{
    var value = $(fieldname).get('value');

    if(CKEDITOR && CKEDITOR.instances['comp-desc']) {
        return CKEDITOR.instances['comp-desc'].getData();
    }

    return value;
}

/** Handle the beforeunload event. This will return a warning message
 *  to show in the dialog if the user should be prompted to confirm
 *  unload, and undef if no edits have been made.
 *
 * @return A warning message to show in the beforeunload dialog, or
 *         undef if a warning message is not needed.
 */
function warnUnload()
{
    var warnmsg;

    if($('comp-title').get('value') !== $('comp-title').retrieve('initialValue') ||
       $('comp-summ').get('value')  !== $('comp-summ').retrieve('initialValue') ||
       ckeditor_data('comp-desc')   !== $('comp-desc').retrieve('initialValue')) {
        warnmsg = confirm_messages['editwarn'];
    }

    savedOnBeforeUnload = window.onbeforeunload;
    window.onbeforeunload = null;
    if(warnmsg !== undefined) {
        setTimeout(function() { window.onbeforeunload = savedOnBeforeUnload; }, 1);
        return warnmsg;
    }
}


window.addEvent('domready', function() {

    // Get the original values of the important elements
    $$('#comp-title, #comp-summ').each(function(element) {
        element.store('initialValue', element.get('value'));
    });

    // fetch the initial value of the article content
    $('comp-desc').store('initialValue', ckeditor_data('comp-desc'));

    // addEvent doesn't work for this for some bizarre reason,
    // so hook the warnUnload function straight into the event
    window.onbeforeunload = warnUnload;

    // Make sure the handler is set when the page is show if needed.
    window.addEvent('pageshow', function() {
        if(!window.onbeforeunload) {
            window.onbeforeunload = savedOnBeforeUnload;
        }
    });
});