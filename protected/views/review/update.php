<?php
$this->breadcrumbs=array(
	'Review'=>array('admin'),
	$model->getModelDisplay(),
	'Update',
);

?>

<h1>Update Review <?php echo $model->id; ?></h1>

<?php echo $this->renderPartial('_form', array('model'=>$model)); ?>