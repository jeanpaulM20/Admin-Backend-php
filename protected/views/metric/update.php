<?php
$this->breadcrumbs=array(
	'Metric'=>array('admin'),
	$model->getModelDisplay(),
	'Update',
);

?>

<h1>Update Metric <?php echo $model->id; ?></h1>

<?php echo $this->renderPartial('_form', array('model'=>$model)); ?>