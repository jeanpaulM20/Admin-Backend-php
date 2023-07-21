<?php
$this->breadcrumbs=array(
	'Client Sessions',
	$model->getModelDisplay(),
	'Update',
);

?>

<h1>Update Client session<?php echo $model->getModelDisplay(); ?></h1>

<?php echo $this->renderPartial('_form', array('model'=>$model)); ?>