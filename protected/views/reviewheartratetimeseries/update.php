<?php
$this->breadcrumbs=array(
	'Review Heart Rate Timeseries'=>array('admin'),
	$model->getModelDisplay(),
	'Update',
);

?>

<h1>Update Review Heart Rate Timeseries <?php echo $model->id; ?></h1>

<?php echo $this->renderPartial('_form', array('model'=>$model)); ?>