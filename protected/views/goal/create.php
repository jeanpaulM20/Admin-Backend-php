<?php
$this->breadcrumbs=array(
	'Goal'=>array('admin'),
	'Create',
);

?>

<h1>Create Goal</h1>

<?php echo $this->renderPartial('_form', array('model'=>$model)); ?>