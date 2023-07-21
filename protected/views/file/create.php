<?php
$this->breadcrumbs=array(
	'File'=>array('admin'),
	'Create',
);

?>

<h1>Create File</h1>

<?php echo $this->renderPartial('_form', array('model'=>$model)); ?>