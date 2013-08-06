
function toggle_matrix_fold(element)
{
    var parent   = element.getParent();
    var children = parent.getElement('div.children');

    if(children) {
        if(parent.hasClass('open')) {
            parent.removeClass('open');
            children.dissolve();
        } else {
            parent.addClass('open');
            children.reveal();
        }
    }
}


function fold_matrix(level)
{
    var count = 0;
    var children = level.getElement('div.children');

    if(children) {
        children.getElements('ul.reciplist > li').each(function(item) {
                                                           if(item.hasClass('haschild')) {
                                                               count += fold_matrix(item);
                                                           } else {
                                                               var methods = item.getElement('div.recip-meths');
                                                               if(methods) {
                                                                   var checked = methods.getElements('input[type="checkbox"]').filter(function(box) { return box.get('checked'); });
                                                                   count += checked.length;
                                                               }
                                                           }
                                                       });

        if(count == 0) {
            level.removeClass('open');
            children.dissolve();
        } else {
            level.addClass('open');
        }
    } else {
        var methods = level.getElement('div.recip-meths');
        if(methods) {
            var checked = methods.getElements('input[type="checkbox"]').filter(function(box) { return box.get('checked'); });
            count += checked.length;
        }
    }

    return count;
}


function show_hide_block(method)
{
    // Does this method have any settings anyway?
    if($(method+'-settings')) {

        // Has this method been set for any recipients?
        var count = $$('input[type=checkbox].'+method).filter(function(box) { return box.get('checked'); }).length;

        if(count) {
            $(method+'-settings').reveal();
        } else {
            $(method+'-settings').dissolve();
        }
    }
}


function update_method_block(box)
{
    var method_patt = /^matrix (\w+)$/;
    var classes = box.get('class');

    var result = method_patt.exec(classes);
    if(result) {
        show_hide_block(result[1]);
    }
}


window.addEvent('domready', function() {

    $$('ul.reciplist li.haschild div.recipient').each(function(element) {
        element.addEvent('click', function() { toggle_matrix_fold(element) });
    });

    $$('ul#matrix > li').each(function(element) { fold_matrix(element); });

    var method_patt = /^shadowbox method (\w+)$/;
    $$('li.shadowbox.method').each(function(element) {
        var classes = element.get('class');

        var result = method_patt.exec(classes);
        if(result) {
            show_hide_block(result[1]);
        }
    });


});