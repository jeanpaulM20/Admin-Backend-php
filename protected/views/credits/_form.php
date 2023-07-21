<div class="form">

<?php $form=$this->beginWidget('CActiveForm', array(
	'id'=>'client_credits-form',
	'enableAjaxValidation'=>false,
	'action' => $model->client_id ? $this->createUrl('credits/allocate', array('client_id' => $model->client_id)) :  $this->createUrl('credits/allocate'),
	'htmlOptions' => array('enctype' => 'multipart/form-data'),
)); ?>

	<p class="note">Fields with <span class="required">*</span> are required.</p>
	<?php echo $form->errorSummary($model); ?>
	
	<?php if (!$model->client_id): ?>
	<div class="row">
		<?php echo $form->labelEx($model,'client_id'); ?>
		<?php echo $form->dropDownList($model,'client_id', Client::getDropdownList()); ?>
		<?php echo $form->error($model,'client_id'); ?>
	</div>
	<?php endif; ?>
	
	<div class="row">
		<?php echo $form->labelEx($model,'abbonement_id'); ?>
		<?php echo $form->dropDownList($model,'abbonement_id', Abbonement::getDropdownList()); ?>
		<?php echo $form->error($model,'abbonement_id'); ?>
	</div>
	
	<div class="row">
	<?php echo $form->labelEx($model,'startdate'); ?>
	<?php $this->widget('zii.widgets.jui.CJuiDatePicker', array(
		'attribute'=>'startdate',
		'model' => $model,
		'options'=>array(
			'showAnim'=>'fold',
			'dateFormat' => 'yy-mm-dd'
		),
	)); ?>
	<?php echo $form->error($model,'startdate'); ?></div>
	
	<div class="row">
	<?php echo $form->labelEx($model,'professional'); ?>
	<?php echo $form->textField($model,'professional',array('size'=>60)); ?>
	<?php echo $form->error($model,'professional'); ?></div>
	
	<div class="row">
	<?php echo $form->labelEx($model,'training_target_1'); ?>
	<?php echo $form->textField($model,'training_target_1',array('size'=>60)); ?>
	<?php echo $form->error($model,'training_target_1'); ?></div>
	
	<div class="row">
	<?php echo $form->labelEx($model,'training_target_2'); ?>
	<?php echo $form->textField($model,'training_target_2',array('size'=>60)); ?>
	<?php echo $form->error($model,'training_target_2'); ?></div>
	
	<div class="row">
	<?php echo $form->labelEx($model,'acquisition'); ?>
	<?php echo $form->textField($model,'acquisition',array('size'=>60)); ?>
	<?php echo $form->error($model,'acquisition'); ?></div>
	
	<div class="row">
		<?php echo $form->labelEx($model,'sold_by_id'); ?>
		<?php echo $form->dropDownList($model,'sold_by_id',  Trainer::getDropdownList()); ?>
		<?php echo $form->error($model,'sold_by_id'); ?>
	</div>
	
	<div class="row buttons">
		<?php echo CHtml::submitButton('Allocate'); ?>
	</div>

<?php $this->endWidget(); ?>
</div><!-- form -->