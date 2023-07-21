<?php
function fYesNo($value) {
	return $value ? 'Yes' : 'No';
}
$this->breadcrumbs = array(
	'Client' => array('admin'),
	$model->getModelDisplay(),
	'Update',
);
?>

<h1><?php echo $model->getModelDisplay(); ?></h1>
<?php if ($model->foto): ?>
<img src="<?php echo $model->foto ?>" /><br/><br/>
<?php endif; ?>
Go to: 
	<a href="#account">Account</a> 
	| <a href="#preferences">Preferences</a>
	| <a href="<?php echo $this->createUrl('client/anamnese', array('id' => $model->id)); ?>">Anamnese</a>
	| <a href="#credits">Credits</a>
	| <a href="#credits">Next trainings</a>
	| <a href="#reviews">Reviews</a>
<br/><br/>
<?php
$this->widget('zii.widgets.CDetailView', array(
	'data' => $model,
	'attributes' => array(
		array(
			'label' => $model->getAttributeLabel('gender'),
			'value' => $model->getGender(),
		),
		'birthday',
		'e_mail',
		'zip',
		'domicile',
		'phone',
		'mobile',
		'max_heart_rate',
		'min_heart_rate',
		array(
			'label' => $model->getAttributeLabel('active'),
			'value' => fYesNo($model->active),
		),
		array(
			'label' => $model->getAttributeLabel('qrcode_static'),
			'value' => fYesNo($model->qrcode_static),
		),
		array(
			'label' => $model->getAttributeLabel('door_access'),
			'value' => fYesNo($model->door_access),
		),
	),
));
?>
<br/>
<a href="<?php echo $this->createUrl('client/update', array('id' => $model->id)); ?>">Edit client</a>
<br/><br/>
<div class="span-10" id="account">
<h3>Account</h3>
<?php
$this->widget('zii.widgets.CDetailView', array(
	'data' => $model->account,
	'attributes' => array(
		'date_of_joining',
		array(
			'label'	 => $model->getAttributeLabel('status'),
			'value'	 => $model->account->getStatus(),
		),
		'device',
		'running_zone',
		'interval_distance',
		'interval_repeats',
		'interval_zone',
	)
)); ?>
<br/>
<a href="<?php echo $this->createUrl('account/update', array('id' => $model->account->id)); ?>">Edit account</a>
</div>
<div class="span-10" id="preferences">
<h3>Preferences</h3>
<?php
$this->widget('zii.widgets.CDetailView', array(
	'data' => $model->preference,
	'attributes' => array(
		array(
			'label'	 => $model->preference->getAttributeLabel('preferred_trainer_search'),
			'value'	 => $model->preference->preferred_trainer ? $model->preference->preferred_trainer->getModelDisplay() : '',
		),
		array(
			'label'	 => $model->preference->getAttributeLabel('preferred_language_search'),
			'value'	 => $model->preference->preferred_language->getModelDisplay(),
		),
		array(
			'label'	 => $model->preference->getAttributeLabel('preferred_location_search'),
			'value'	 => $model->preference->preferred_location->getModelDisplay(),
		),
		array(
			'label'	 => $model->preference->getAttributeLabel('auto_send_appointement'),
			'value' => fYesNo($model->preference->auto_send_appointement),
		),
	)
)); ?>
<br/>
<a href="<?php echo $this->createUrl('preference/update', array('id' => $model->preference->id)); ?>">Edit preferences</a>
</div>
<br class="clear"/>
<br/>
<div id="credits">
	<h3>Credits</h3>
	<?php $this->widget('zii.widgets.grid.CGridView', array(
	'id'=>'credits-grid',
	'dataProvider'=>new CArrayDataProvider($model->credits),
	'rowCssClassExpression' => '"id_" . $data->getPrimaryKey() . " " . ($row %2 ? "even" : "odd")',
	'columns'=>array(
	 	array(
			'name' => ClientCredits::model()->getAttributeLabel('abbonement_search'),
			'value' => '$data->training_type->name_en ."<br/> " . $data->abbonement->title',
			'type' => 'html'
		),
		array(
			'name' => ClientCredits::model()->getAttributeLabel('price'),
			'value' => '$data->price'
		),
		array(
			'name' => ClientCredits::model()->getAttributeLabel('paid'),
			'value' => '$data->paid'
		),
		array(
			'name' => ClientCredits::model()->getAttributeLabel('attended'),
			'value' => '$data->attended'
		),
		array(
			'name' => ClientCredits::model()->getAttributeLabel('startdate'),
			'value' => '$data->startdate',
		),
	 	array(
			'name' => ClientCredits::model()->getAttributeLabel('expires'),
			'value' => '$data->expires',
		),
		array(
			'name' => ClientCredits::model()->getAttributeLabel('sell_date'),
			'value' => '$data->sell_date',
		),
		array(
			'name' => ClientCredits::model()->getAttributeLabel('soldby_search'),
			'value' => '$data->sold_by ? $data->sold_by->getModelDisplay() : ""',
		),
		array(
			'name' => ClientCredits::model()->getAttributeLabel('professional'),
			'value' => '$data->professional',
		),
		array(
			'name' => ClientCredits::model()->getAttributeLabel('training_target_1'),
			'value' => '$data->training_target_1',
		),
		array(
			'name' => ClientCredits::model()->getAttributeLabel('training_target_2'),
			'value' => '$data->training_target_2',
		),
		array(
			'name' => ClientCredits::model()->getAttributeLabel('acquisition'),
			'value' => '$data->acquisition',
		),
	),
)); ?>
</div>
<br class="clear"/>
<br/>
<div id="next_trainings">
	<h3>Next trainings</h3>
	<?php
$this->widget('zii.widgets.grid.CGridView', array(
	'id' => 'training-grid',
	'dataProvider' => new CArrayDataProvider($model->next_trainings),
	'rowCssClassExpression' => '"id_" . $data->getPrimaryKey() . " " . ($row %2 ? "even" : "odd")',
	'columns' => array(
		array(
			'name' => ClientCredits::model()->getAttributeLabel('date'),
			'value' => '$data->date',
		),
		array(
			'name' => ClientCredits::model()->getAttributeLabel('starttime'),
			'value' => '$data->starttime',
		),
		array(
			'name' => ClientCredits::model()->getAttributeLabel('duration'),
			'value' => '$data->duration',
		),
		array(
			'name' => ClientCredits::model()->getAttributeLabel('type_id'),
			'value' => '$data->type->name_en',
		),
		array(
			'name' => ClientCredits::model()->getAttributeLabel('text'),
			'value' => '$data->text',
		),
		array(
			'name' => ClientCredits::model()->getAttributeLabel('status'),
			'value' => '$data->getStatus()',
		),
		array(
			'name' => ClientCredits::model()->getAttributeLabel('location_search'),
			'value' => '$data->location->name',
		),
		array(
			'name' => ClientCredits::model()->getAttributeLabel('trainer_search'),
			'value' => '$data->trainer ? $data->trainer->getModelDisplay() : ""',
		),
	),
));
?>
</div>
<div id="reviews">
	<h3>Reviews</h3>
	<?php $this->widget('zii.widgets.grid.CGridView', array(
	'id'=>'review-grid',
	'dataProvider'=>new CArrayDataProvider($model->reviews),
	'rowCssClassExpression' => '"id_" . $data->getPrimaryKey() . " " . ($row %2 ? "even" : "odd")',
	'columns'=>array(
		array(
			'name' => Review::model()->getAttributeLabel('duration'),
			'value' => '$data->duration',
		),
		array(
			'name' => Review::model()->getAttributeLabel('heart_rate'),
			'value' => '$data->heart_rate',
		),
		array(
			'name' => Review::model()->getAttributeLabel('training_type'),
			'value' => '$data->getTrainingType()'
		),
		array(
			'name' => Review::model()->getAttributeLabel('type'),
			'value' => '$data->getType()'
		),
		array(
			'name' => Review::model()->getAttributeLabel('goal'),
			'value' => '$data->goal . " " . $data->goal_metric'
		),
		array(
			'name' => Review::model()->getAttributeLabel('bonus_goal'),
			'value' => '$data->bonus_goal . " " .$data->bonus_goal_metric'
		),
		array(
			'name' => Review::model()->getAttributeLabel('result'),
			'value' => '$data->result'
		),
		array(
			'name' => Review::model()->getAttributeLabel('training_search'),
			'value'=>'($data->training ? $data->training->date  . " " . $data->training->starttime  . " " . $data->training->getEndTime(): "")',
		),
		array(
			'name' => Review::model()->getAttributeLabel('distance'),
			'value' => '$data->distance'
		),
		array(
			'name' => Review::model()->getAttributeLabel('speed'),
			'value' => '$data->speed'
		),
	),
)); ?>
</div>