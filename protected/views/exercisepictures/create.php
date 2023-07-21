<?php
$this->breadcrumbs=array(
	'Exercise Pictures'=>array('admin'),
	'Create',
);

?>

<h1>Create Exercise Pictures</h1>

<?php echo $this->renderPartial('_form', array('model'=>$model)); ?>