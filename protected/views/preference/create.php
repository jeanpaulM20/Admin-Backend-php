<?php
$this->breadcrumbs=array(
	'Preference'=>array('admin'),
	'Create',
);

?>

<h1>Create Preference</h1>

<?php echo $this->renderPartial('_form', array('model'=>$model)); ?>