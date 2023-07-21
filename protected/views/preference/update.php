<?php
$this->breadcrumbs=array(
	'Preference'=>array('admin'),
	$model->getModelDisplay(),
	'Update',
);

?>

<h1>Update Preference <?php echo $model->id; ?></h1>

<?php echo $this->renderPartial('_form', array('model'=>$model)); ?>