<?php
$this->breadcrumbs=array(
	'Language'=>array('admin'),
	$model->getModelDisplay(),
	'Update',
);

?>

<h1>Update Language <?php echo $model->id; ?></h1>

<?php echo $this->renderPartial('_form', array('model'=>$model)); ?>