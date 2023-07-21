<div class="form">

<?php $form=$this->beginWidget('CActiveForm', array(
	'id'=>'client_heart_rate-form',
	'enableAjaxValidation'=>false,
	'action' => $model->isNewRecord ? $this->createUrl('clientheartrate/create') : $this->createUrl('clientheartrate/update', array('id' => $model->id)),
	'htmlOptions' => array('enctype' => 'multipart/form-data'),
)); ?>

	<p class="note">Fields with <span class="required">*</span> are required.</p>

	<?php echo $form->errorSummary($model); ?>
	
	<div class="row">
	<?php echo $form->labelEx($model,'max'); ?>
	<?php echo $form->textField($model,'max',array('size'=>60)); ?>
	<?php echo $form->error($model,'max'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'min'); ?>
	<?php echo $form->textField($model,'min',array('size'=>60)); ?>
	<?php echo $form->error($model,'min'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'date'); ?>
	<?php $this->widget('zii.widgets.jui.CJuiDatePicker', array(
		'attribute'=>'date',
		'model' => $model,
		'options'=>array(
			'showAnim'=>'fold',
			'dateFormat' => 'yy-mm-dd'		),
	)); ?>
	<?php echo $form->error($model,'date'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'client_id'); ?>
	<?php echo $form->dropDownList($model,'client_id', Client::getDropdownList()); ?>
	<?php echo $form->error($model,'client_id'); ?></div>
		
	

	<div class="row buttons">
		<?php echo CHtml::submitButton($model->isNewRecord ? 'Create' : 'Save'); ?>
	</div>

<?php $this->endWidget(); ?>
</div><!-- form -->