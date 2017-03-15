CKEDITOR.editorConfig = function( config )
{
    config.extraPlugins = 'pastetext,newline';

    config.height  = '12em';
    config.toolbarStartupExpanded = true;
    config.toolbar = 'NewsagentBasic';
    config.resize_dir = 'vertical';
    config.disableNativeSpellChecker = false;

    config.toolbar_NewsagentBasic = [
	    { name: 'operations', items : [ 'Source','-','Cut','Copy','Paste','PasteText','-','Undo','Redo' ] },
	    { name: 'basicstyles', items : [ 'Bold','Italic','Underline','Strike','Subscript','Superscript','-','RemoveFormat' ] },
	    { name: 'paragraph', items : [ 'NumberedList', 'BulletedList', '-', 'Outdent', 'Indent', '-', 'Blockquote', 'CreateDiv', '-', 'JustifyLeft', 'JustifyCenter', 'JustifyRight', 'JustifyBlock' ] },
	    { name: 'links', items : [ 'Link','Unlink','Anchor' ] },
	    { name: 'insert', items : [ 'Table', 'Image', 'HorizontalRule', 'SpecialChar', 'Newline' ] },
	    { name: 'styles', items : [ 'Styles','Format','Font','FontSize' ] },
	    { name: 'colors', items : [ 'TextColor','BGColor' ] }
    ];

    config.keystrokes = [
        [ CKEDITOR.CTRL + 13, 'shiftEnter' ],    // Ctrl+Enter
        [ CKEDITOR.CTRL + 75, 'link' ],
    ];

    config.allowedContent = true
};