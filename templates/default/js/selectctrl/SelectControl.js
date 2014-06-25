
var SelectControl = new Class(
{
    Implements: [Options, Events],

    options: {
        checkClass: 'input.selctrl-opt'

    },

    initialise: function(element, options)
    {
        this.setOptions(options);

        // Grab the element, and extend it if needed
        this.element = document.id(element);
        this.element.store('selectctrl_object', this);

        this._create();
    },


    _create: function()
    {
        // fetch the ul which should form the menu
        this.menu = this.element.getFirst('ul');
        if(!this.menu) return;

        this.menu.dispose();                      // remove from the dom
        this.menu.addClass('selectctrl-menu');    // ensture the menu has the right class
        this.menu.setStyle('display', 'none');    // make sure the menu is hidden
        this.menu.inject.(this.element, 'after'); // and put it back in place



    }
});
