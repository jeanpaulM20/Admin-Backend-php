<?php
$this->breadcrumbs=array(
	'Locker'=>array('admin'),
	'Create',
);

?>

<h1>Create Locker</h1>

<?php echo $this->renderPartial('_form', array('model'=>$model)); ?>