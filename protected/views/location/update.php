<?php
$this->breadcrumbs=array(
	'Location'=>array('admin'),
	$model->getModelDisplay(),
	'Update',
);

?>

<h1>Update Location <?php echo $model->id; ?></h1>

<?php echo $this->renderPartial('_form', array('model'=>$model)); ?>