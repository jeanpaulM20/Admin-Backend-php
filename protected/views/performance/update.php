<?php
$this->breadcrumbs=array(
	'Performance Test'=>array('admin'),
	$model->getModelDisplay(),
	'Update',
);

?>

<h1>Update Performance Test <?php echo $model->id; ?></h1>

<?php echo $this->renderPartial('_form', array('model'=>$model)); ?>