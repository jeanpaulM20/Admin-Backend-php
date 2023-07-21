<?php
$this->breadcrumbs=array(
	'Goal'=>array('admin'),
	$model->getModelDisplay(),
	'Update',
);

?>

<h1>Update Goal <?php echo $model->id; ?></h1>

<?php echo $this->renderPartial('_form', array('model'=>$model)); ?>