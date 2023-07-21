<?php
$this->breadcrumbs=array(
	'Services'=>array('admin'),
	'Update',
);
?>

<h1>Update Service <?php echo $model->id; ?></h1>

<?php echo $this->renderPartial('_form', array('model'=>$model)); ?>