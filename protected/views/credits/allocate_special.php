<?php
$this->breadcrumbs=array(
	'Clients'=>array('client/admin'),
	'Credits'=>array('admin', array('client_id' => $model->client_id)),
	'Allocate',
);

?>

<?php if ($model->client): ?>
<h1>Allocate Credits for <?php echo $model->client->getModelDisplay(); ?></h1>
<?php else: ?>
<h1>Allocate Credits</h1>
<?php endif; ?>

<?php echo $this->renderPartial('_form_special', array('model'=>$model)); ?>