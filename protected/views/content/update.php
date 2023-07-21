<?php
$this->breadcrumbs=array(
	'Content'=>array('admin'),
	$model->getModelDisplay(),
	'Update',
);

?>

<h1>Update Content <?php echo $model->id; ?></h1>

<?php echo $this->renderPartial('_form', array('model'=>$model)); ?>