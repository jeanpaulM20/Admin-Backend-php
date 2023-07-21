<?php
$this->breadcrumbs=array(
	'Training'=>array('admin'),
	'Create',
);

?>

<h1>Create Training</h1>

<?php echo $this->renderPartial('_form', array('model'=>$model)); ?>