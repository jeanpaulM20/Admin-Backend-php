<div class="form">

<?php $form=$this->beginWidget('CActiveForm', array(
	'id'=>'review_heart_rate_timeseries-form',
	'enableAjaxValidation'=>false,
	'action' => $model->isNewRecord ? $this->createUrl('reviewheartratetimeseries/create') : $this->createUrl('reviewheartratetimeseries/update', array('id' => $model->id)),
	'htmlOptions' => array('enctype' => 'multipart/form-data'),
)); ?>

	<p class="note">Fields with <span class="required">*</span> are required.</p>

	<?php echo $form->errorSummary($model); ?>
	
	<div class="row">
	<?php echo $form->labelEx($model,'timestamp'); ?>
	<?php $this->widget('application.extensions.timepicker.EJuiDateTimePicker',array(
		'model'=>$model,
		'attribute'=>'timestamp',
		'options'=>array(
			'timePickerOnly' => true,
			'timeFormat' => 'hh:mm:ss',
		),
	)); ?>
	<?php echo $form->error($model,'timestamp'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'value'); ?>
	<?php echo $form->textField($model,'value',array('size'=>60)); ?>
	<?php echo $form->error($model,'value'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'sort'); ?>
	<?php echo $form->textField($model,'sort',array('size'=>60)); ?>
	<?php echo $form->error($model,'sort'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'review_id'); ?>
	<?php echo $form->dropDownList($model,'review_id', Review::getDropdownList()); ?>
	<?php echo $form->error($model,'review_id'); ?></div>
		
	

	<div class="row buttons">
		<?php echo CHtml::submitButton($model->isNewRecord ? 'Create' : 'Save'); ?>
		<?php
			echo CHtml::htmlButton('Cancel', array(
				'onclick' => 'history.back();'
			));
		?>
	</div>

<?php $this->endWidget(); ?>
</div><!-- form -->