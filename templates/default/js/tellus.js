
function setup_queue_link(element)
{
    element.addEvent("click", function(event) {
        var id   = event.target.get('id');
        var name = id.substr(6);

        location.href = mlisturl + "/" + name;
    });
}


window.addEvent('domready', function() {
    // Enable queue selection
    $$('div.queuetitle').each(function(element) { setup_queue_link(element) });
});