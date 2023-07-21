<div class="form">

<?php $form=$this->beginWidget('CActiveForm', array(
	'id'=>'client_credits-form',
	'enableAjaxValidation'=>false,
	'action' => $this->createUrl('credits/update') . '/' . $model->id,
)); ?>

	<p class="note">Fields with <span class="required">*</span> are required.</p>
	<?php echo $form->errorSummary($model); ?>
	
	<div class="row">
		<?php echo $form->labelEx($model,'client_id'); ?>
		<?php echo $model->client->getModelDisplay() ?>
	</div>
	
	<?php if ($model->abbonement_id): ?>
		<div class="row">
			<?php echo $form->labelEx($model,'abbonement_id'); ?>
			<?php echo $model->abbonement->getModelDisplay() ?>
		</div>
	<?php else: ?>
		<div class="row">
			<?php echo $form->labelEx($model,'training_type_id'); ?>
			<?php echo $model->training_type->getModelDisplay() ?>
		</div>
		<div class="row">
			<?php echo $form->labelEx($model,'price'); ?>
			<?php echo $form->textField($model,'price',array('size'=>60)); ?>
			<?php echo $form->error($model,'price'); ?></div>
	<?php endif; ?>
	
	<div class="row">
	<?php echo $form->labelEx($model,'paid'); ?>
	<?php echo $form->textField($model,'paid',array('size'=>60)); ?>
	<?php echo $form->error($model,'paid'); ?></div>
	
	<div class="row">
	<?php echo $form->labelEx($model,'attended'); ?>
	<?php echo $form->textField($model,'attended',array('size'=>60)); ?>
	<?php echo $form->error($model,'attended'); ?></div>
	
	<?php if ($model->startdate): ?>
		<div class="row">
		<?php echo $form->labelEx($model,'startdate'); ?>
		<?php echo $model->startdate ?>
		</div>
	<?php endif; ?>
	
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
		<?php echo $model->sold_by->getModelDisplay() ?>
	</div>
	
	<div class="row buttons">
		<?php echo CHtml::submitButton('Save'); ?>
	</div>

<?php $this->endWidget(); ?>
</div><!-- form -->