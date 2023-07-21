<?php
$this->breadcrumbs=array(
	'Trainingplan'=>array('admin'),
	$model->getModelDisplay(),
	'Update',
);

?>

<h1>Update Trainingplan <?php echo $model->id; ?></h1>

<?php echo $this->renderPartial('_form', array('model'=>$model)); ?>