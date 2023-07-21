<?php
$this->breadcrumbs=array(
	'Abbonements'=>array('admin'),
	$model->getModelDisplay(),
	'Update',
);

?>

<h1>Update Abbonement <?php echo $model->getModelDisplay(); ?></h1>

<?php echo $this->renderPartial('_form', array('model'=>$model)); ?>