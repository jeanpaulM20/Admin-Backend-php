<?php
$this->breadcrumbs=array(
	'Offer'=>array('admin'),
	'Create',
);

?>

<h1>Create Offer</h1>

<?php echo $this->renderPartial('_form', array('model'=>$model)); ?>