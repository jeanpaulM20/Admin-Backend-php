<div class="form">

<?php $form=$this->beginWidget('CActiveForm', array(
	'id'=>'abbonement-form',
	'enableAjaxValidation'=>false,
	'action' => $model->isNewRecord ? $this->createUrl('abbonement/create') : $this->createUrl('abbonement/update', array('id' => $model->id)),
	'htmlOptions' => array('enctype' => 'multipart/form-data'),
)); ?>

	<p class="note">Fields with <span class="required">*</span> are required.</p>

	<?php echo $form->errorSummary($model); ?>
	
	<div class="row">
		<?php echo $form->labelEx($model,'training_type_id'); ?>
		<?php echo $form->dropDownList($model,'training_type_id', TrainingType::getDropdownList()); ?>
		<?php echo $form->error($model,'training_type_id'); ?>
	</div>
	
	<div class="row">
		<?php echo $form->labelEx($model,'title'); ?>
		<?php echo $form->textField($model,'title',array('size'=>60)); ?>
		<?php echo $form->error($model,'title'); ?>
	</div>
	
	<div class="row">
		<?php echo $form->labelEx($model,'duration'); ?>
		<?php echo $form->textField($model,'duration',array('size'=>60)); ?>
		<?php echo $form->error($model,'duration'); ?>
	</div>
	
	<div class="row">
		<?php echo $form->labelEx($model,'lessons'); ?>
		<?php echo $form->textField($model,'lessons',array('size'=>60)); ?>
		<?php echo $form->error($model,'lessons'); ?>
	</div>
	
	<div class="row">
		<?php echo $form->labelEx($model,'price'); ?>
		<?php echo $form->textField($model,'price',array('size'=>60)); ?>
		<?php echo $form->error($model,'price'); ?>
	</div>
	
	<div class="row buttons">
		<?php echo CHtml::submitButton($model->isNewRecord ? 'Create' : 'Save'); ?>
		<?php
			echo CHtml::htmlButton('Cancel', array(
				'onclick' => 'window.location="'.$this->createUrl('content/admin') . '";'
			));
		?>
	</div>

<?php $this->endWidget(); ?>
	<?php $this->widget( 'ext.EChosen.EChosen' ); ?>
</div><!-- form -->