var Matrix = new Class({

    Implements: [Events, Options],

    options: {
         recipdiv: 'ul.reciplist li.haschild div.recipient',
        reciplist: 'ul.reciplist > li',
         childdiv: 'div.children',
          methdiv: 'div.recip-meths'
    },

    initialize: function(options) {
        this.setOptions(options);

        $$(this.options.recipdiv).each(function(element) {
            console.log(this);
            element.addEvent('click', function() {
                                 console.log(this);
                                 this.toggle_matrix_fold(element);
                             }.bind(this));
        }, this);

        $$('ul#matrix > li').each(function(element) { this.fold_matrix(element); }, this);

        var method_patt = /^shadowbox method (\w+)$/;
        $$('li.shadowbox.method').each(function(element) {
            var classes = element.get('class');

            var result = method_patt.exec(classes);
            if(result) {
                this.show_hide_block(result[1]);
            }
        }, this);
    },

    toggle_matrix_fold: function(element) {
        var parent   = element.getParent();
        var children = parent.getElement(this.options.childdiv);

        if(children) {
            if(parent.hasClass('open')) {
                parent.removeClass('open');
                children.dissolve();
            } else {
                parent.addClass('open');
                children.reveal();
            }
        }
    },

    fold_matrix: function (level) {
        var count = 0;
        var children = level.getElement(this.options.childdiv);

        if(children) {
            children.getElements(this.options.reciplist).each(function(item) {
                                                               if(item.hasClass('haschild')) {
                                                                   count += this.fold_matrix(item);
                                                               } else {
                                                                   var methods = item.getElement('div.recip-meths');
                                                                   if(methods) {
                                                                       var checked = methods.getElements('input[type="checkbox"]').filter(function(box) { return box.get('checked'); });
                                                                       count += checked.length;
                                                                   }
                                                               }
                                                           }, this);

            if(count == 0) {
                level.removeClass('open');
                children.dissolve();
            } else {
                level.addClass('open');
            }
        } else {
            var methods = level.getElement(this.options.methdiv);
            if(methods) {
                var checked = methods.getElements('input[type="checkbox"]').filter(function(box) { return box.get('checked'); });
                count += checked.length;
            }
        }

        return count;
    },


    show_hide_block: function(method) {
        // Does this method have any settings anyway?
        if($(method+'-settings')) {

            // Has this method been set for any recipients?
            var count = $$('input[type=checkbox].'+method).filter(function(box) { return box.get('checked'); }).length;

            if(count) {
                $(method+'-settings').reveal();
            } else {
                $(method+'-settings').dissolve();
            }

            this.fireEvent('toggle', method, count);
        }
    },


    update_method_block: function(box) {
        var method_patt = /^matrix (\w+)$/;
        var classes = box.get('class');

        var result = method_patt.exec(classes);
        if(result) {
            this.show_hide_block(result[1]);
        }
    }
});