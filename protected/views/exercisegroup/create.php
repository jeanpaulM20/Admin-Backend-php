<?php
$this->breadcrumbs=array(
	'Exercise Group'=>array('admin'),
	'Create',
);

?>

<h1>Create Exercise Group</h1>

<?php echo $this->renderPartial('_form', array('model'=>$model)); ?>