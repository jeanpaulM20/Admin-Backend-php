<div class="form">

<?php $form=$this->beginWidget('CActiveForm', array(
	'id'=>'service-form',
	'enableAjaxValidation'=>false,
)); ?>

	<p class="note">Fields with <span class="required">*</span> are required.</p>

	<?php echo $form->errorSummary($model); ?>

	<div class="row">
		<?php echo $form->labelEx($model,'model'); ?>
		<?php echo $form->dropDownList($model,'model', Helper::getModelsArray()); ?>
		<?php echo $form->error($model,'model'); ?>
	</div>

	<div class="row">
		<?php echo $form->labelEx($model,'service_alias'); ?>
		<?php echo $form->textField($model,'service_alias',array('size'=>60,'maxlength'=>255)); ?>
		<?php echo $form->error($model,'service_alias'); ?>
	</div>
	
	<div class="row">
		<?php echo $form->labelEx($model,'title'); ?>
		<?php echo $form->textField($model,'title',array('size'=>60,'maxlength'=>255)); ?>
		<?php echo $form->error($model,'title'); ?>
	</div>
	
	<div class="row">
		<?php echo $form->labelEx($model,'description'); ?>
		<?php echo $form->textArea($model,'description',array('rows'=>6, 'cols'=>50)); ?>
		<?php echo $form->error($model,'description'); ?>
	</div>

	<div class="row">
		<?php echo $form->labelEx($model,'service_params'); ?>
		<?php echo $form->textArea($model,'service_params',array('rows'=>6, 'cols'=>50)); ?>
		<?php echo $form->error($model,'service_params'); ?>
	</div>

	<div class="row">
		<?php echo $form->labelEx($model,'select_fields'); ?>
		<?php echo $form->textArea($model,'select_fields',array('rows'=>6, 'cols'=>50)); ?>
		<?php echo $form->error($model,'select_fields'); ?>
	</div>

	<div class="row">
		<?php echo $form->labelEx($model,'condition'); ?>
		<?php echo $form->textArea($model,'condition',array('rows'=>6, 'cols'=>50)); ?>
		<?php echo $form->error($model,'condition'); ?>
	</div>

	<div class="row">
		<?php echo $form->labelEx($model,'order'); ?>
		<?php echo $form->textArea($model,'order',array('rows'=>6, 'cols'=>50)); ?>
		<?php echo $form->error($model,'order'); ?>
	</div>
	
	<div class="row">
		<?php echo $form->labelEx($model,'group'); ?>
		<?php echo $form->textField($model,'group'); ?>
		<?php echo $form->error($model,'group'); ?>
	</div>
	
	<div class="row">
		<?php echo $form->labelEx($model,'publish'); ?>
		<?php echo $form->checkbox($model,'publish'); ?>
		<?php echo $form->error($model,'publish'); ?>
	</div>
	
	<div class="row">
		<?php echo $form->labelEx($model,'sortOrder'); ?>
		<?php echo $form->textField($model,'sortOrder'); ?>
		<?php echo $form->error($model,'sortOrder'); ?>
	</div>

	<div class="row buttons">
		<?php echo CHtml::submitButton($model->isNewRecord ? 'Create' : 'Save'); ?>
	</div>

<?php $this->endWidget(); ?>

</div><!-- form -->