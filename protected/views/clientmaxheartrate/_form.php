<div class="form">

<?php $form=$this->beginWidget('CActiveForm', array(
	'id'=>'client_max_heart_rate-form',
	'enableAjaxValidation'=>false,
	'action' => $model->isNewRecord ? $this->createUrl('clientmaxheartrate/create') : $this->createUrl('clientmaxheartrate/update', array('id' => $model->id)),
	'htmlOptions' => array('enctype' => 'multipart/form-data'),
)); ?>

	<p class="note">Fields with <span class="required">*</span> are required.</p>

	<?php echo $form->errorSummary($model); ?>
	
	<div class="row">
	<?php echo $form->labelEx($model,'max_heart_rate'); ?>
	<?php echo $form->textField($model,'max_heart_rate',array('size'=>60)); ?>
	<?php echo $form->error($model,'max_heart_rate'); ?></div>
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
	<?php echo $form->labelEx($model,'sort'); ?>
	<?php echo $form->textField($model,'sort',array('size'=>60)); ?>
	<?php echo $form->error($model,'sort'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'client_id'); ?>
	<?php echo $form->dropDownList($model,'client_id', Client::getDropdownList()); ?>
	<?php echo $form->error($model,'client_id'); ?></div>
		
	

	<div class="row buttons">
		<?php echo CHtml::submitButton($model->isNewRecord ? 'Create' : 'Save'); ?>
	</div>

<?php $this->endWidget(); ?>
</div><!-- form -->