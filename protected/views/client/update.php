<?php
$this->breadcrumbs=array(
	'Client'=>array('admin'),
	$model->getModelDisplay(),
	'Update',
);

?>

<h1>Update Client <?php echo $model->id; ?></h1>

<?php echo $this->renderPartial('_form', array('model'=>$model)); ?>