CKEDITOR.plugins.add( 'newline', {
    icons: 'newline',
    init: function( editor ) {
        editor.addCommand( 'insertNewline', {
            exec: function( editor ) {
                editor.execCommand( 'shiftEnter' );
            }
        });
        editor.ui.addButton( 'Newline', {
            label: 'Insert a literal newline',
            command: 'insertNewline',
            toolbar: 'insert'
        });
    }
});