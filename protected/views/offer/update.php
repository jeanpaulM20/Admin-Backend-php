<?php
$this->breadcrumbs=array(
	'Offer'=>array('admin'),
	$model->getModelDisplay(),
	'Update',
);

?>

<h1>Update Offer <?php echo $model->id; ?></h1>

<?php echo $this->renderPartial('_form', array('model'=>$model)); ?>