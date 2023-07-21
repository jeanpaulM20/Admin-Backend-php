<?php
$this->breadcrumbs=array(
	'Metric'=>array('admin'),
	'Create',
);

?>

<h1>Create Metric</h1>

<?php echo $this->renderPartial('_form', array('model'=>$model)); ?>