<div class="form">

<?php $form=$this->beginWidget('CActiveForm', array(
	'id'=>'content_foto-form',
	'enableAjaxValidation'=>false,
	'action' => $model->isNewRecord ? $this->createUrl('contentfoto/create') : $this->createUrl('contentfoto/update', array('id' => $model->id)),
	'htmlOptions' => array('enctype' => 'multipart/form-data'),
)); ?>

	<p class="note">Fields with <span class="required">*</span> are required.</p>

	<?php echo $form->errorSummary($model); ?>
	
	<div class="row">
	<?php echo $form->labelEx($model,'file'); ?>
	<?php $this->widget('application.extensions.elfinder.FilePicker',array(
		'model'=>$model,
		'attribute'=>'file',
	)); ?>	<?php echo $form->error($model,'file'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'sort'); ?>
	<?php echo $form->textField($model,'sort',array('size'=>60)); ?>
	<?php echo $form->error($model,'sort'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'content_id'); ?>
	<?php echo $form->dropDownList($model,'content_id', Content::getDropdownList()); ?>
	<?php echo $form->error($model,'content_id'); ?></div>
		
	

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