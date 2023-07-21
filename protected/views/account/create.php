<?php
$this->breadcrumbs=array(
	'Account'=>array('admin'),
	'Create',
);

?>

<h1>Create Account</h1>

<?php echo $this->renderPartial('_form', array('model'=>$model)); ?>