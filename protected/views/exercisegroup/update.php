<?php
$this->breadcrumbs=array(
	'Exercise Group'=>array('admin'),
	$model->getModelDisplay(),
	'Update',
);

?>

<h1>Update Exercise Group <?php echo $model->id; ?></h1>

<?php echo $this->renderPartial('_form', array('model'=>$model)); ?>