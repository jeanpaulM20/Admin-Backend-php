<?php
$this->breadcrumbs=array(
	'Exercise Subgroup'=>array('admin'),
	$model->getModelDisplay(),
	'Update',
);

?>

<h1>Update Exercise Subgroup<?php echo $model->id; ?></h1>

<?php echo $this->renderPartial('_form', array('model'=>$model)); ?>