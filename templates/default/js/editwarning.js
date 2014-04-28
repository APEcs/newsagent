var savedOnBeforeUnload;

function ckeditor_data(fieldname)
{
    var value = $(fieldname).get('value');

    if(CKEDITOR && CKEDITOR.instances['comp-desc']) {
        return CKEDITOR.instances['comp-desc'].getData();
    }

    return value;
}


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

    $('comp-desc').store('initialValue', ckeditor_data('comp-desc'));

    window.onbeforeunload = warnUnload;

    window.addEvent('pageshow', function() {
        if(!window.onbeforeunload) {
            window.onbeforeunload = savedOnBeforeUnload;
        }
    });
});