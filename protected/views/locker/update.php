<?php
$this->breadcrumbs=array(
	'Locker'=>array('admin'),
	$model->getModelDisplay(),
	'Update',
);

?>

<h1>Update Locker <?php echo $model->getModelDisplay(); ?></h1>

<?php echo $this->renderPartial('_form', array('model'=>$model)); ?>