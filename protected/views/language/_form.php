<div class="form">

<?php $form=$this->beginWidget('CActiveForm', array(
	'id'=>'language-form',
	'enableAjaxValidation'=>false,
	'action' => $model->isNewRecord ? $this->createUrl('language/create') : $this->createUrl('language/update', array('id' => $model->id)),
	'htmlOptions' => array('enctype' => 'multipart/form-data'),
)); ?>

	<p class="note">Fields with <span class="required">*</span> are required.</p>

	<?php echo $form->errorSummary($model); ?>
	
	<div class="row">
	<?php echo $form->labelEx($model,'language'); ?>
	<?php echo $form->dropDownList($model,'language', $model->getLanguageValues()); ?>
	<?php echo $form->error($model,'language'); ?></div>
		
	

	<div class="row buttons">
		<?php echo CHtml::submitButton($model->isNewRecord ? 'Create' : 'Save'); ?>
		<?php
			echo CHtml::htmlButton('Cancel', array(
				'onclick' => 'window.location="'.$this->createUrl('language/admin') . '";'
			));
		?>
	</div>

<?php $this->endWidget(); ?>
</div><!-- form -->