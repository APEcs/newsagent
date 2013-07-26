
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



window.addEvent('domready', function() {

    $$('ul.reciplist li.haschild div.recipient').each(function(element) {
        element.addEvent('click', function() { toggle_matrix_fold(element) });
    });

    $$('ul#matrix > li').each(function(element) { fold_matrix(element); });

});