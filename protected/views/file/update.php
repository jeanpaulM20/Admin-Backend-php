<?php
$this->breadcrumbs=array(
	'File'=>array('admin'),
	$model->getModelDisplay(),
	'Update',
);

?>

<h1>Update File <?php echo $model->id; ?></h1>

<?php echo $this->renderPartial('_form', array('model'=>$model)); ?>