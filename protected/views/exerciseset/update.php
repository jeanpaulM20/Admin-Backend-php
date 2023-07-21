<?php
$this->breadcrumbs=array(
	'ExerciseSet'=>array('admin'),
	$model->getModelDisplay(),
	'Update',
);

?>

<h1>Update ExerciseSet <?php echo $model->id; ?></h1>

<?php echo $this->renderPartial('_form', array('model'=>$model)); ?>