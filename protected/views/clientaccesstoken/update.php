<?php
$this->breadcrumbs=array(
	'Client Access token'=>array('admin'),
	$model->getModelDisplay(),
	'Update',
);

?>

<h1>Update Client Access token <?php echo $model->id; ?></h1>

<?php echo $this->renderPartial('_form', array('model'=>$model)); ?>