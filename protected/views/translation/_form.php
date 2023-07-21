<div class="form">

<?php $form=$this->beginWidget('CActiveForm', array(
	'id'=>'translation-form',
	'enableAjaxValidation'=>false,
	'action' => $model->isNewRecord ? $this->createUrl('translation/create') : $this->createUrl('translation/update', array('id' => $model->id)),
	'htmlOptions' => array('enctype' => 'multipart/form-data'),
)); ?>

	<p class="note">Fields with <span class="required">*</span> are required.</p>

	<?php echo $form->errorSummary($model); ?>
	
	<div class="row">
	<?php echo $form->labelEx($model,'label'); ?>
	<?php echo $form->textField($model,'label',array('size'=>60)); ?>
	<?php echo $form->error($model,'label'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'value'); ?>
	<?php echo $form->textField($model,'value',array('size'=>60)); ?>
	<?php echo $form->error($model,'value'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'language_rel'); ?>
	<?php echo $form->dropDownList($model,'language_rel', Language::getDropdownList()); ?>
	<?php echo $form->error($model,'language_rel'); ?></div>
		
	

	<div class="row buttons">
		<?php echo CHtml::submitButton($model->isNewRecord ? 'Create' : 'Save'); ?>
		<?php
			echo CHtml::htmlButton('Cancel', array(
				'onclick' => 'window.location="'.$this->createUrl('translation/admin') . '";'
			));
		?>
	</div>

<?php $this->endWidget(); ?>
</div><!-- form -->