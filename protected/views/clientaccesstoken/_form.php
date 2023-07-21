<div class="form">

<?php $form=$this->beginWidget('CActiveForm', array(
	'id'=>'client_access_token-form',
	'enableAjaxValidation'=>false,
	'action' => $model->isNewRecord ? $this->createUrl('clientaccesstoken/create') : $this->createUrl('clientaccesstoken/update', array('id' => $model->id)),
	'htmlOptions' => array('enctype' => 'multipart/form-data'),
)); ?>

	<p class="note">Fields with <span class="required">*</span> are required.</p>

	<?php echo $form->errorSummary($model); ?>
	
	<div class="row">
	<?php echo $form->labelEx($model,'token'); ?>
	<?php echo $form->textField($model,'token',array('size'=>60)); ?>
	<?php echo $form->error($model,'token'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'date'); ?>
	<?php $this->widget('application.extensions.timepicker.EJuiDateTimePicker',array(
		'model'=>$model,
		'attribute'=>'date',
		'options'=>array(
			'dateFormat' => 'yy-mm-dd',
			'timeFormat' => 'hh:mm',
		),
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
		<?php
			echo CHtml::htmlButton('Cancel', array(
				'onclick' => 'window.location="'.$this->createUrl('clientaccesstoken/admin') . '";'
			));
		?>
	</div>

<?php $this->endWidget(); ?>
</div><!-- form -->