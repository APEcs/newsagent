var sortlist;

/** Add a click handler to the specified newsletter list element to switch
 *  the newsletter view to a different newsletter.
 *
 * @param element The element to attach the click event handler to.
 */
function setup_newsletter_link(element)
{
    element.addEvent("click", function(event) {
        var id   = event.target.get('id');
        var name = id.substr(5);

        location.href = nlisturl + "/" + name;
    });
}

window.addEvent('domready', function() {
    // Enable newsletter selection
    $$('div.newstitle').each(function(element) { setup_newsletter_link(element); });

    sortlist = new CustomSortable('#messagebrowser div.edit ul', {
		                              clone: true,
		                              revert: true,
		                              opacity: 0.5
	                              });

    sortlist.removeItems($$('#messagebrowser div.edit ul li.dummy'));
});