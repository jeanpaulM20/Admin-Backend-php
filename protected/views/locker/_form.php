<div class="form">

<?php $form=$this->beginWidget('CActiveForm', array(
	'id'=>'locker-form',
	'enableAjaxValidation'=>false,
	'action' => $model->isNewRecord ? $this->createUrl('locker/create') : $this->createUrl('locker/update', array('id' => $model->id)),
	'htmlOptions' => array('enctype' => 'multipart/form-data'),
)); ?>

	<p class="note">Fields with <span class="required">*</span> are required.</p>

	<?php echo $form->errorSummary($model); ?>
	
	<div class="row">
		<?php echo $form->labelEx($model,'locker_id'); ?>
		<?php echo $form->textField($model,'locker_id',array('size'=>60)); ?>
		<?php echo $form->error($model,'locker_id'); ?>
	</div>
	
	<div class="row">
		<?php echo $form->labelEx($model,'type'); ?>
		<?php echo $form->dropDownList($model,'type',$model->getGenderValues()); ?>
		<?php echo $form->error($model,'type'); ?>
	</div>
	
	<div class="row">
		<?php echo $form->labelEx($model,'status'); ?>
		<?php echo $form->dropDownList($model,'status',array('free' => 'free', 'open' => 'open', 'closed' => 'closed')); ?>
		<?php echo $form->error($model,'status'); ?>
	</div>
	
	<div class="row">
	<?php echo $form->labelEx($model,'client_id'); ?>
	<?php echo $form->dropDownList($model,'client_id', Client::getDropdownList(true)); ?>
	<?php echo $form->error($model,'client_id'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'training_id'); ?>
	<?php echo $form->dropDownList($model,'training_id', Training::getDropdownList(true)); ?>
	<?php echo $form->error($model,'training_id'); ?></div>
		
	<div class="row buttons">
		<?php echo CHtml::submitButton($model->isNewRecord ? 'Create' : 'Save'); ?>
		<?php
			echo CHtml::htmlButton('Cancel', array(
				'onclick' => 'window.location="'.$this->createUrl('locker/admin') . '";'
			));
		?>
	</div>

<?php $this->endWidget(); ?>
</div><!-- form -->