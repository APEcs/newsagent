CKEDITOR.editorConfig = function( config )
{
    config.height  = '12em';
    config.toolbarStartupExpanded = true;
    config.toolbar = 'NewsagentBasic';
    config.resize_dir = 'vertical';

    config.toolbar_NewsagentBasic = [
	    { name: 'operations', items : [ 'Source','-','Cut','Copy','Paste','-','Undo','Redo' ] },
	    { name: 'basicstyles', items : [ 'Bold','Italic','Underline','Strike','Subscript','Superscript','-','RemoveFormat' ] },
	    { name: 'paragraph', items : [ 'NumberedList','BulletedList','-','Outdent','Indent','-','Blockquote','CreateDiv',
	                                   '-','JustifyLeft','JustifyCenter','JustifyRight','JustifyBlock' ] },
	    { name: 'links', items : [ 'Link','Unlink','Anchor' ] },
	    { name: 'insert', items : [ 'HorizontalRule', 'SpecialChar' ] },
	    { name: 'styles', items : [ 'Styles','Format','Font','FontSize' ] },
	    { name: 'colors', items : [ 'TextColor','BGColor' ] }
    ];
};