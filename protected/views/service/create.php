<?php
$this->breadcrumbs=array(
	'Services'=>array('index'),
	'Create',
);

?>

<h1>Create Service</h1>

<?php echo $this->renderPartial('_form', array('model'=>$model)); ?>