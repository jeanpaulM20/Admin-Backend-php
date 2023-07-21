<?php
$this->breadcrumbs=array(
	'Exercise'=>array('admin'),
	'Create',
);

?>

<h1>Create Exercise</h1>

<?php echo $this->renderPartial('_form', array('model'=>$model)); ?>