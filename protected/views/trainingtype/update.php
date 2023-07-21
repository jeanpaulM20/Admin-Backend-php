<?php
$this->breadcrumbs=array(
	'Training Types'=>array('admin'),
	$model->getModelDisplay(),
	'Update',
);

?>

<h1>Update Training Type <?php echo $model->id; ?></h1>

<?php echo $this->renderPartial('_form', array('model'=>$model)); ?>