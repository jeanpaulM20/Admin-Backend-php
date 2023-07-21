<div class="form">

<?php $form=$this->beginWidget('CActiveForm', array(
	'id'=>'client_sessions-form',
	'enableAjaxValidation'=>false,
	'action' => $model->isNewRecord ? $this->createUrl('sessions/create', array('client_id' => $model->client_id)) : $this->createUrl('sessions/update', array('id' => $model->id, 'client_id' => $model->client_id)),
	'htmlOptions' => array('enctype' => 'multipart/form-data'),
)); ?>

	<p class="note">Fields with <span class="required">*</span> are required.</p>
	<?php echo $form->errorSummary($model); ?>
	
	<div class="row">
	<?php echo $form->labelEx($model,'trainiing_type_id'); ?>
	<?php echo $form->dropDownList($model,'trainiing_type_id', TrainingType::getDropdownList()); ?>
	<?php echo $form->error($model,'trainiing_type_id'); ?></div>
	
	<div class="row">
	<?php echo $form->labelEx($model,'paid'); ?>
	<?php echo $form->textField($model,'paid',array('size'=>60)); ?>
	<?php echo $form->error($model,'paid'); ?></div>
	
	<div class="row">
	<?php echo $form->labelEx($model,'attended'); ?>
	<?php echo $form->textField($model,'attended',array('size'=>60)); ?>
	<?php echo $form->error($model,'attended'); ?></div>
	
	<div class="row">
	<?php echo $form->labelEx($model,'client_id'); ?>
	<?php echo $form->dropDownList($model,'client_id', Client::getDropdownList()); ?>
	<?php echo $form->error($model,'client_id'); ?></div>
		
	

	<div class="row buttons">
		<?php echo CHtml::submitButton($model->isNewRecord ? 'Create' : 'Save'); ?>
	</div>

<?php $this->endWidget(); ?>
</div><!-- form -->