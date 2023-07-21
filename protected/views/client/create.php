<?php
$this->breadcrumbs=array(
	'Client'=>array('admin'),
	'Create',
);

?>

<h1>Create Client</h1>

<?php echo $this->renderPartial('_form', array('model'=>$model)); ?>