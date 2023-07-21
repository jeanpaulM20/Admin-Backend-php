<div class="form">

	<?php
	$form = $this->beginWidget('CActiveForm', array(
		'id'					 => 'goal-form',
		'enableAjaxValidation'	 => false,
		'action'				 => $model->isNewRecord ? $this->createUrl('trainingtype/create') : $this->createUrl('trainingtype/update', array('id'			 => $model->id)),
		'htmlOptions'	 => array('enctype' => 'multipart/form-data'),
			));
	?>

	<p class="note">Fields with <span class="required">*</span> are required.</p>

		<?php echo $form->errorSummary($model); ?>

	<div class="row">
		<?php echo $form->labelEx($model, 'name_en'); ?>
		<?php echo $form->textField($model, 'name_en', array('size' => 60)); ?>
		<?php echo $form->error($model, 'name_en'); ?></div>
	<div class="row">
		<?php echo $form->labelEx($model, 'name_de'); ?>
		<?php echo $form->textField($model, 'name_de', array('size' => 60)); ?>
		<?php echo $form->error($model, 'name_de'); ?></div>
	
	<div class="row">
		<?php echo $form->labelEx($model, 'abbr'); ?>
		<?php echo $form->textField($model, 'abbr', array('size' => 60)); ?>
		<?php echo $form->error($model, 'abbr'); ?></div>
	
	<div class="row">
		<?php echo $form->labelEx($model, 'service'); ?>
		<?php echo $form->checkBox($model, 'service'); ?>
		<?php echo $form->error($model, 'service'); ?></div>
	
	<div class="row">
		<?php echo $form->labelEx($model, 'duration'); ?>
		<?php echo $form->textField($model, 'duration', array('size' => 60)); ?>
		<?php echo $form->error($model, 'duration'); ?></div>
	
	<div class="row">
		<?php echo $form->labelEx($model, 'participants'); ?>
		<?php echo $form->textField($model, 'participants', array('size' => 60)); ?>
		<?php echo $form->error($model, 'participants'); ?></div>
	<div class="row">
		<?php echo $form->labelEx($model, 'sort'); ?>
		<?php echo $form->textField($model, 'sort', array('size' => 60)); ?>
		<?php echo $form->error($model, 'sort'); ?></div>
	
	<div class="row">
		<?php echo $form->labelEx($model, 'no_avaliability'); ?>
		<?php echo $form->checkBox($model, 'no_avaliability', array('size' => 60)); ?>
		<?php echo $form->error($model, 'no_avaliability'); ?></div>
	
	<div class="row">
		<?php echo $form->labelEx($model, 'no_locker'); ?>
		<?php echo $form->checkBox($model, 'no_locker', array('size' => 60)); ?>
		<?php echo $form->error($model, 'no_locker'); ?></div>
	
	<div class="row">
		<?php echo $form->labelEx($model, 'avaliability_from'); ?>
		<?php echo $form->dropDownList($model,'avaliability_from', TrainingType::getDropdownList(true)); ?>
		<?php echo $form->error($model, 'avaliability_from'); ?></div>
	<div class="row">
		<?php echo $form->labelEx($model, 'credits_from'); ?>
		<?php echo $form->dropDownList($model,'credits_from', TrainingType::getDropdownList(true)); ?>
		<?php echo $form->error($model, 'credits_from'); ?></div>
	

	<div class="row buttons">
		<?php echo CHtml::submitButton($model->isNewRecord ? 'Create' : 'Save'); ?>
		<?php
		echo CHtml::htmlButton('Cancel', array(
			'onclick' => 'window.location="' . $this->createUrl('trainingtype/admin') . '";'
		));
		?>
	</div>

<?php $this->endWidget(); ?>
</div><!-- form -->