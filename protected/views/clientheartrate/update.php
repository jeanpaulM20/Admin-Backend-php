<?php
$this->breadcrumbs=array(
	'Client max heart rate'=>array('admin'),
	$model->getModelDisplay(),
	'Update',
);

?>

<h1>Update Client max heart rate <?php echo $model->id; ?></h1>

<?php echo $this->renderPartial('_form', array('model'=>$model)); ?>