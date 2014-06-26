
var MessageControl = new Class(
{
    Implements: [Options, Events],

    options: {
        checkClass: 'input.selctrl-opt',
		offset: { x: 0, y: 0 }
    },

    initialize: function(element, options)
    {
        this.setOptions(options);

        this.action = 'open';

        // Grab the element, and extend it if needed
        this.element = document.id(element);
        this.element.store('messagectrl_object', this);

        this._create();
    },


    _create: function()
    {
        this.move = this.element.getFirst('li.msgctrl-move');
        if(!this.move) return;

        this.menu = this.move.getFirst('ul');
        if(!this.menu) return;

        this.menu.dispose();                   // remove from the dom
        this.menu.addClass('msgctrl-menu');    // ensture the menu has the right class
        this.menu.setStyle('display', 'none'); // make sure the menu is hidden

        // Move the menu into position below the control box
        this.positionMenu();
        this.menu.inject(this.element, 'after'); // and put it back in place

        // Enable menu toggle
        this.element.addEvents({ 'click': function() {
                                     if(this.menu.hasClass("open")) {
                                         this.toggleMenu('close');
                                     } else {
                                         this.toggleMenu('open');
                                     }
                                 }.bind(this),
                                 'mouseenter': function() { this.action = 'open'; }.bind(this),
                                 'mouseleave': function() { this.action = 'close'; }.bind(this),
                                 'keydown': function(event) {
                                     if(event.key == 'space' || event.key == 'down' || event.key == 'up') {
                                         this.action = 'close';
                                         this.toggleMenu('open');
                                     }
                                 }.bind(this)
                               });

        // Update the visibility when any checkboxes are changed
        $$(this.options.checkClass).each(function(element) {
            element.addEvent('change', function() { this.updateVis(); }.bind(this));
        }, this);

        this.updateVis();
    },

    updateVis: function() {
        var checked = $$(this.options.checkClass).filter(function(box) { return box.get('checked'); });

        if(checked.length && this.element.getStyle('visibility') == 'hidden') {
            this.element.fade('in');
        } else if(!checked.length && this.element.getStyle('visibility') == 'visible') {
     //       toggleMenu('close');
            this.element.fade('out');
        }
    },

    toggleMenu: function(mode)
    {
        if(mode == "close") {
            this.menu.removeClass("open");
            this.menu.setStyle('display', 'none');

            this.fireEvent('listOpen', this.element);
        } else {
            this.positionMenu();
            this.menu.addClass("open");
            this.menu.setStyle('display', 'block');

            this.fireEvent('listClose', this.element);
        }
    },

    positionMenu: function()
    {
        var offset = this.options.offset;
		var position = this.element.getCoordinates();
		this.menu.setStyles({'top': position.top + position.height + offset.y,
			                 'left': position.left + offset.x });
    }
});
