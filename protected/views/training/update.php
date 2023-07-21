<?php
$this->breadcrumbs=array(
	'Training'=>array('admin'),
	$model->getModelDisplay(),
	'Update',
);

?>

<h1>Update Training <?php echo $model->id; ?></h1>

<?php echo $this->renderPartial('_form', array('model'=>$model)); ?>