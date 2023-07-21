<?php
$this->breadcrumbs=array(
	'Exercise'=>array('admin'),
	$model->getModelDisplay(),
	'Update',
);

?>

<h1>Update Exercise <?php echo $model->id; ?></h1>

<?php echo $this->renderPartial('_form', array('model'=>$model)); ?>