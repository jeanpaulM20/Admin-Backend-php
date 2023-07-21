<?php
$this->breadcrumbs=array(
	'Trainer'=>array('admin'),
	'Create',
);

?>

<h1>Create Trainer</h1>

<?php echo $this->renderPartial('_form', array('model'=>$model)); ?>