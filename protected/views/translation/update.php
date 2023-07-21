<?php
$this->breadcrumbs=array(
	'Translation'=>array('admin'),
	$model->getModelDisplay(),
	'Update',
);

?>

<h1>Update Translation <?php echo $model->id; ?></h1>

<?php echo $this->renderPartial('_form', array('model'=>$model)); ?>