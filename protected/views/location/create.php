<?php
$this->breadcrumbs=array(
	'Location'=>array('admin'),
	'Create',
);

?>

<h1>Create Location</h1>

<?php echo $this->renderPartial('_form', array('model'=>$model)); ?>