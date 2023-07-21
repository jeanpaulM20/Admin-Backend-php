<?php
$this->breadcrumbs=array(
	'Content'=>array('admin'),
	'Create',
);

?>

<h1>Create Content</h1>

<?php echo $this->renderPartial('_form', array('model'=>$model)); ?>