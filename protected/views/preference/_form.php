<div class="form">

	<?php
	$form = $this->beginWidget('CActiveForm', array(
		'id'					 => 'preference-form',
		'enableAjaxValidation'	 => false,
		'action'				 => $model->isNewRecord ? $this->createUrl('preference/create') : $this->createUrl('preference/update', array('id'			 => $model->id)),
		'htmlOptions'	 => array('enctype' => 'multipart/form-data'),
			));
	?>

	<p class="note">Fields with <span class="required">*</span> are required.</p>

	<?php echo $form->errorSummary($model); ?>

	<div class="row">
		<?php echo $form->labelEx($model, 'preferred_trainer_rel'); ?>
		<?php echo $form->dropDownList($model, 'preferred_trainer_rel', Trainer::getDropdownList(true)); ?>
		<?php echo $form->error($model, 'preferred_trainer_rel'); ?>
	</div>
	<div class="row">
		<?php echo $form->labelEx($model, 'preferred_language_rel'); ?>
		<?php echo $form->dropDownList($model, 'preferred_language_rel', Language::getDropdownList(true)); ?>
		<?php echo $form->error($model, 'preferred_language_rel'); ?>
	</div>
	<div class="row">
		<?php echo $form->labelEx($model, 'preferred_location_rel'); ?>
		<?php echo $form->dropDownList($model, 'preferred_location_rel', Location::getDropdownList(true)); ?>
		<?php echo $form->error($model, 'preferred_location_rel'); ?>
	</div>
	<div class="row">
		<?php echo $form->labelEx($model, 'auto_send_appointement'); ?>
		<?php echo $form->checkBox($model, 'auto_send_appointement'); ?>
		<?php echo $form->error($model, 'auto_send_appointement'); ?>
	</div>
	<div class="row">
		<?php echo $form->labelEx($model, 'client_id'); ?>
		<?php echo $form->dropDownList($model, 'client_id', Client::getDropdownList()); ?>
		<?php echo $form->error($model, 'client_id'); ?>
	</div>



	<div class="row buttons">
		<?php echo CHtml::submitButton($model->isNewRecord ? 'Create' : 'Save'); ?>
		<?php
		echo CHtml::htmlButton('Cancel', array(
			'onclick' => 'window.location="' . $this->createUrl('preference/admin') . '";'
		));
		?>
	</div>

	<?php $this->endWidget(); ?>
</div><!-- form -->