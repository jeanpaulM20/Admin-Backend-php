<?php
$this->breadcrumbs=array(
	'Content Fotos',
	$model->getModelDisplay(),
	'Update',
);

?>

<h1>Update Content Foto <?php echo $model->id; ?></h1>

<?php echo $this->renderPartial('_form', array('model'=>$model)); ?>