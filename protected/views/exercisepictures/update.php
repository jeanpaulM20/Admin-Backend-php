<?php
$this->breadcrumbs=array(
	'Exercise Pictures'=>array('admin'),
	$model->getModelDisplay(),
	'Update',
);

?>

<h1>Update Exercise Pictures <?php echo $model->id; ?></h1>

<?php echo $this->renderPartial('_form', array('model'=>$model)); ?>