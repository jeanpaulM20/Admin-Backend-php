<div class="form">

	<?php
	$form = $this->beginWidget('CActiveForm', array(
		'id'					 => 'exerciseset-form',
		'enableAjaxValidation'	 => false,
		'action'				 => $model->isNewRecord ? $this->createUrl('exerciseset/create') : $this->createUrl('exerciseset/update', array('id'			 => $model->id)),
		'htmlOptions'	 => array('enctype' => 'multipart/form-data'),
			));
	?>

	<p class="note">Fields with <span class="required">*</span> are required.</p>

		<?php echo $form->errorSummary($model); ?>

	<div class="row">
		<?php echo $form->labelEx($model, 'name'); ?>
<?php echo $form->textField($model, 'name', array('size' => 60)); ?>
		<?php echo $form->error($model, 'name'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'archive'); ?>
	<?php echo $form->checkBox($model,'archive'); ?>
	<?php echo $form->error($model,'archive'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'published'); ?>
	<?php echo $form->checkBox($model,'published'); ?>
	<?php echo $form->error($model,'published'); ?></div>
	<div class="row">
		<?php echo $form->labelEx($model, 'exercises'); ?>
		<?php echo CHtml::activeDropDownList($model, 'exercises', Exercise::getDropdownList(), array('multiple'	 => true, 'class'		 => 'chzn-select', 'style'		 => 'width:380px;')) ?>
		<?php echo $form->error($model, 'exercises'); ?>
	</div><div class="row">
		<?php echo $form->labelEx($model, 'trainings'); ?>
<?php echo CHtml::activeDropDownList($model, 'trainings', Training::getDropdownList(), array('multiple'	 => true, 'class'		 => 'chzn-select', 'style'		 => 'width:380px;')) ?>
<?php echo $form->error($model, 'trainings'); ?>
	</div>

	<div class="row buttons">
		<?php echo CHtml::submitButton($model->isNewRecord ? 'Create' : 'Save'); ?>
		<?php
		echo CHtml::htmlButton('Cancel', array(
			'onclick' => 'window.location="' . $this->createUrl('exerciseset/admin') . '";'
		));
		?>
	</div>

<?php $this->endWidget(); ?>
<?php $this->widget('ext.EChosen.EChosen'); ?>
</div><!-- form -->