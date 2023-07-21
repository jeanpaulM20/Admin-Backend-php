<div class="form">

<?php $form=$this->beginWidget('CActiveForm', array(
	'id'=>'account-form',
	'enableAjaxValidation'=>false,
	'action' => $model->isNewRecord ? $this->createUrl('account/create') : $this->createUrl('account/update', array('id' => $model->id)),
	'htmlOptions' => array('enctype' => 'multipart/form-data'),
)); ?>

	<p class="note">Fields with <span class="required">*</span> are required.</p>

	<?php echo $form->errorSummary($model); ?>
	
	<div class="row">
	<?php echo $form->labelEx($model,'date_of_joining'); ?>
	<?php $this->widget('zii.widgets.jui.CJuiDatePicker', array(
		'attribute'=>'date_of_joining',
		'model' => $model,
		'options'=>array(
			'showAnim'=>'fold',
			'dateFormat' => 'yy-mm-dd'		),
	)); ?>
	<?php echo $form->error($model,'date_of_joining'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'device'); ?>
	<?php echo $form->textField($model,'device',array('size'=>60)); ?>
	<?php echo $form->error($model,'device'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'status'); ?>
	<?php echo $form->dropDownList($model,'status', $model->getStatusValues()); ?>
	<?php echo $form->error($model,'status'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'client_id'); ?>
	<?php echo $form->dropDownList($model,'client_id', Client::getDropdownList(true)); ?>
	<?php echo $form->error($model,'client_id'); ?></div>
		
	

	<div class="row buttons">
		<?php echo CHtml::submitButton($model->isNewRecord ? 'Create' : 'Save'); ?>
		<?php
			echo CHtml::htmlButton('Cancel', array(
				'onclick' => 'window.location="'.$this->createUrl('account/admin') . '";'
			));
		?>
	</div>

<?php $this->endWidget(); ?>
</div><!-- form -->