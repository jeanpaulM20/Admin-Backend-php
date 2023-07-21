<?php
$this->breadcrumbs=array(
	'Trainer'=>array('admin'),
	$model->getModelDisplay(),
	'Update',
);

?>

<h1>Update Trainer <?php echo $model->id; ?></h1>

<?php echo $this->renderPartial('_form', array('model'=>$model)); ?>