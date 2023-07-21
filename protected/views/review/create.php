<?php
$this->breadcrumbs=array(
	'Review'=>array('admin'),
	'Create',
);

?>

<h1>Create Review</h1>

<?php echo $this->renderPartial('_form', array('model'=>$model)); ?>